import contextlib
import copy
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import device_validation_cleanup as cleanup


CLIENT = "11111111-1111-4111-8111-111111111111"
DRIVER = "22222222-2222-4222-8222-222222222222"
OTHER = "33333333-3333-4333-8333-333333333333"
REQUEST = "44444444-4444-4444-8444-444444444444"
OFFER = "55555555-5555-4555-8555-555555555555"
STRAY = "66666666-6666-4666-8666-666666666666"
TOKEN = "DO-NOT-LOG-THIS-ACCESS-TOKEN-"
# Gateway UpstreamPendingOffersStore.MapOwnStatus; the parent projection stays verbatim.
OWN_PROJECTION = {"submitted": "pending", "edited": "pending", "pending": "pending", "accepted": "accepted",
                  "rejected": "superseded", "superseded": "superseded", "expired": "superseded", "withdrawn": "withdrawn"}


class StubGateway:
    def __init__(self):
        self.requests = {REQUEST: {"id": REQUEST, "clientId": CLIENT, "status": "pending", "jeeberId": None}}
        self.offers = {OFFER: {"id": OFFER, "requestId": REQUEST, "jeeberId": DRIVER, "status": "submitted"}}
        self.calls = []
        self.mints = []
        self.roles = {CLIENT: ["customer"], DRIVER: ["customer", "driver"]}
        self.open_mode = True
        self.uncancellable = False
        self.unwithdrawable = False
        self.wrong_identity = False
        self.delete_status = 200

    def __call__(self, method, path, body, token):
        self.calls.append((method, path))
        if path == "/auth/tokens":
            if not self.open_mode:
                return 401, {}
            if set(body) - {"userId", "roles"}:
                raise AssertionError("mint body carries only userId and the run's role set")
            requested = body.get("roles")
            if not requested:
                return 404, {}
            if requested != self.roles[body["userId"]]:
                raise AssertionError("cleanup must send the plan's role set, never escalated claims")
            self.mints.append((body["userId"], tuple(requested)))
            return 200, {"accessToken": TOKEN + body["userId"], "refreshToken": "NEVER-PERSIST-REFRESH"}
        actor = token.removeprefix(TOKEN)
        if path == "/v1/users/me":
            return 200, {"id": OTHER if self.wrong_identity else actor}
        if path == "/v1/requests?role=client":
            return 200, copy.deepcopy([item for item in self.requests.values() if item["clientId"] == actor])
        if path == "/v1/jeebers/me/offers":
            own = copy.deepcopy([item for item in self.offers.values() if item["jeeberId"] == actor])
            for item in own:
                item["status"] = OWN_PROJECTION.get(item["status"], "withdrawn")
            return 200, {"items": own}
        if path.startswith("/v1/offers/") and method == "DELETE":
            item = self.offers[path.split("/")[-1]]
            if actor != item["jeeberId"]:
                return 403, {}
            if not self.unwithdrawable:
                item["status"] = "withdrawn"
            return 409 if self.unwithdrawable else 204, None
        if path.startswith("/v1/requests/"):
            request_id = path.split("/")[3]
            if request_id not in self.requests:
                return 404, {}
            item = self.requests[request_id]
            if actor != item["clientId"]:
                return 403, {}
            if path.endswith("/offers"):
                return 200, copy.deepcopy([offer for offer in self.offers.values() if offer["requestId"] == request_id])
            if method == "DELETE":
                if any(offer["status"] in cleanup.PENDING_OFFERS for offer in self.offers.values()):
                    raise AssertionError("offer must be withdrawn first")
                if not self.uncancellable:
                    item["status"] = "cancelled"
                return self.delete_status, copy.deepcopy(item)
            return 200, copy.deepcopy(item)
        raise AssertionError("unexpected stub endpoint " + path)


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.ledger = cleanup.Ledger(self.temporary.name, cleanup.DEFAULT_GATEWAY)
        self.ledger.record("request", REQUEST, CLIENT, "test-created")
        self.ledger.record("offer", OFFER, DRIVER, request_id=REQUEST)
        self.stub, self.messages = StubGateway(), []

    def tearDown(self):
        self.temporary.cleanup()

    def engine(self, actors=(CLIENT, DRIVER)):
        gateway = cleanup.Gateway(cleanup.DEFAULT_GATEWAY, self.ledger, actors, transport=self.stub)
        return cleanup.Cleanup(self.ledger, gateway, self.messages.append)

    def deletes(self):
        return [path for method, path in self.stub.calls if method == "DELETE"]

    def test_offer_is_withdrawn_before_request_and_both_rechecked(self):
        self.engine().sweep()
        self.assertEqual(self.deletes(), ["/v1/offers/" + OFFER, "/v1/requests/" + REQUEST])
        self.assertEqual(self.stub.offers[OFFER]["status"], "withdrawn")
        self.assertEqual(self.stub.requests[REQUEST]["status"], "cancelled")
        self.assertEqual(sum(path == "/auth/tokens" for _, path in self.stub.calls), 2)

    def test_already_terminal_is_clean_and_not_cancelled_again(self):
        self.stub.requests[REQUEST]["status"] = "cancelled"
        self.stub.offers[OFFER]["status"] = "withdrawn"
        self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_live_gateway_vocabulary_pairing_sweeps_end_to_end(self):
        engine = self.engine()
        parent = engine.offers_for(engine.requests[REQUEST])
        own = engine.owned_offer(engine.offers[OFFER])
        self.assertEqual((parent[0]["status"], own["status"]), ("submitted", "pending"))
        self.engine().sweep()
        self.assertEqual(self.deletes(), ["/v1/offers/" + OFFER, "/v1/requests/" + REQUEST])

    def test_disagreeing_offer_projections_refuse_before_any_mutation(self):
        for parent_state, own_state in [("withdrawn", "pending"), ("submitted", "superseded"), ("submitted", None), (None, "pending")]:
            with self.subTest(parent=parent_state, own=own_state):
                self.stub = original = StubGateway()
                def inconsistent(method, path, body, token):
                    status, document = original(method, path, body, token)
                    if path == "/v1/jeebers/me/offers":
                        if own_state is None:
                            document["items"] = [item for item in document["items"] if item["id"] != OFFER]
                        else:
                            document["items"][0]["status"] = own_state
                    elif path == "/v1/requests/" + REQUEST + "/offers":
                        if parent_state is None:
                            document = [row for row in document if row["id"] != OFFER]
                        else:
                            document[0]["status"] = parent_state
                    return status, document
                engine = self.engine()
                engine.gateway.transport = inconsistent
                with self.assertRaisesRegex(cleanup.Refused, "projection"):
                    engine.sweep()
                self.assertEqual(self.deletes(), [])

    def test_own_offer_becoming_pending_after_cancel_prevents_success(self):
        self.stub.offers[OFFER]["status"] = "withdrawn"
        original = self.stub
        def inconsistent(method, path, body, token):
            result = original(method, path, body, token)
            if method == "DELETE" and path == "/v1/requests/" + REQUEST:
                original.offers[OFFER]["status"] = "submitted"
            return result
        engine = self.engine()
        engine.gateway.transport = inconsistent
        with self.assertRaisesRegex(cleanup.Refused, "pending"):
            engine.sweep()
        self.assertFalse(any("Sweep verified" in message for message in self.messages))

    def test_pending_after_success_delete_is_not_clean(self):
        self.stub.uncancellable = True
        with self.assertRaisesRegex(cleanup.Refused, REQUEST):
            self.engine().sweep()

    def test_409_is_not_blindly_treated_as_clean(self):
        self.stub.uncancellable, self.stub.delete_status = True, 409
        with self.assertRaises(cleanup.Refused):
            self.engine().sweep()

    def test_offer_409_still_pending_blocks_request_cancel(self):
        self.stub.unwithdrawable = True
        with self.assertRaises(cleanup.Refused):
            self.engine().sweep()
        self.assertEqual(self.deletes(), ["/v1/offers/" + OFFER])

    def test_openmode_off_hands_to_owner_without_deletes(self):
        self.stub.open_mode = False
        with self.assertRaisesRegex(cleanup.OwnerRequired, "hand to owner"):
            self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_minted_identity_mismatch_prevents_every_delete(self):
        self.stub.wrong_identity = True
        with self.assertRaisesRegex(cleanup.Refused, "identity"):
            self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_foreign_actor_not_explicitly_authorized_cannot_mint(self):
        with self.assertRaises(cleanup.Refused):
            self.engine((CLIENT,)).sweep()
        self.assertEqual(self.stub.calls, [])

    def test_foreign_request_owner_stops_before_offer_withdrawal(self):
        self.stub.requests[REQUEST]["clientId"] = OTHER
        with self.assertRaises(cleanup.Refused):
            self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_unledgered_pending_offer_is_not_withdrawn(self):
        self.stub.offers[STRAY] = {"id": STRAY, "requestId": REQUEST, "jeeberId": DRIVER, "status": "pending"}
        with self.assertRaisesRegex(cleanup.Refused, "Unledgered"):
            self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_accepted_or_assigned_request_hands_to_owner(self):
        for status, jeeber in [("accepted", DRIVER), ("pending", DRIVER), ("unknown", None)]:
            self.stub.requests[REQUEST].update(status=status, jeeberId=jeeber)
            with self.assertRaises(cleanup.OwnerRequired):
                self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_accepted_offer_hands_to_owner(self):
        self.stub.offers[OFFER]["status"] = "accepted"
        with self.assertRaises(cleanup.OwnerRequired):
            self.engine().sweep()
        self.assertEqual(self.deletes(), [])

    def test_request_assigned_between_checks_stops_before_delete(self):
        original = self.stub
        def racing(method, path, body, token):
            result = original(method, path, body, token)
            if method == "DELETE" and path.startswith("/v1/offers/"):
                original.requests[REQUEST]["jeeberId"] = DRIVER
            return result
        engine = self.engine()
        engine.gateway.transport = racing
        with self.assertRaises(cleanup.OwnerRequired):
            engine.sweep()
        self.assertEqual(self.deletes(), ["/v1/offers/" + OFFER])

    def test_audit_reports_unledgered_rows_without_mutating(self):
        self.stub.requests[STRAY] = {"id": STRAY, "clientId": CLIENT, "status": "pending", "jeeberId": None}
        with self.assertRaises(cleanup.Refused):
            self.engine().audit([CLIENT, DRIVER])
        self.assertIn(STRAY, "\n".join(self.messages))
        self.assertEqual(self.deletes(), [])
        self.ledger.record("request", STRAY, CLIENT)
        self.engine().audit([CLIENT, DRIVER])

    def test_missing_parent_request_provenance_refused(self):
        self.ledger.record("offer", STRAY, DRIVER, request_id=OTHER)
        with self.assertRaisesRegex(cleanup.Refused, "parent request"):
            self.engine()
        self.assertEqual(self.stub.calls, [])

    def test_conflicting_ledger_owner_refused(self):
        self.ledger.record("request", REQUEST, OTHER)
        with self.assertRaises(cleanup.Refused):
            self.engine()

    def test_ledger_gateway_mismatch_and_legacy_missing_provenance_refused(self):
        for gateway in ["https://jeeb.fds-1.com", None]:
            entry = {"ts": "old", "kind": "request", "id": REQUEST, "ownerUserId": CLIENT, "gateway": gateway}
            self.ledger.path.write_text(json.dumps(entry) + "\n")
            with self.assertRaises(cleanup.Refused):
                self.ledger.load()

    def test_tokens_and_refresh_never_appear_in_output_or_ledger(self):
        self.engine().sweep()
        saved = self.ledger.path.read_text() + "\n".join(self.messages)
        self.assertNotIn(TOKEN, saved)
        self.assertNotIn("NEVER-PERSIST-REFRESH", saved)
        self.assertEqual(self.ledger.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(sum(item["kind"] == "session" for item in self.ledger.load()), 2)

    def test_partial_or_unknown_list_is_not_an_audit_pass(self):
        for document in [{}, {"items": [], "totalCount": 1}, {"items": [], "nextCursor": "more"}, {"items": [None]}]:
            with self.assertRaises(cleanup.Refused):
                cleanup.rows(document)

    def test_production_foreign_and_arbitrary_override_are_refused_before_http(self):
        for gateway in ["https://jeeb.fds-1.com/gateway", "https://example.test/gateway", "http://msi.olivium.space/gateway", "https://msi.olivium.space.evil/gateway", "https://user@msi.olivium.space/gateway", "https://msi.olivium.space/gateway/../admin"]:
            with self.assertRaises(cleanup.Refused):
                cleanup.Gateway(gateway, self.ledger, [CLIENT], self.stub)
        self.assertEqual(self.stub.calls, [])

    def test_default_commands_are_offline_and_not_cleanliness_proof(self):
        for command in [["sweep"], ["audit", CLIENT]]:
            with patch.dict(os.environ, {"JEEB_DEVICE_EVIDENCE_DIR": self.temporary.name}), patch.object(cleanup.Gateway, "_http") as http, contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(cleanup.main(command), 0)
                http.assert_not_called()
                self.assertIn("DRY RUN ONLY", output.getvalue())

    def test_cli_owner_required_exit_two_and_sweep_failure_exit_one(self):
        for mode, expected in [("off", 2), ("pending", 1)]:
            self.stub.open_mode = mode != "off"
            self.stub.uncancellable = mode == "pending"
            with patch.dict(os.environ, {"JEEB_DEVICE_EVIDENCE_DIR": self.temporary.name}), patch.object(cleanup.Gateway, "_http", side_effect=self.stub), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as error:
                self.assertEqual(cleanup.main(["sweep", "--execute", "--actor", CLIENT, "--actor", DRIVER]), expected)
                self.assertNotIn(TOKEN, error.getvalue())

    def test_record_rejects_credentials_and_non_uuid_paths(self):
        for entity_id, note in [("../../path", ""), (REQUEST, "Bearer secret"), (REQUEST, "accessToken=secret")]:
            with self.assertRaises(cleanup.Refused):
                self.ledger.record("request", entity_id, CLIENT, note)

    def test_http_transport_pins_origin_and_preserves_auth_only_in_memory(self):
        gateway = cleanup.Gateway(cleanup.DEFAULT_GATEWAY, self.ledger, [CLIENT])
        with patch.object(cleanup.http.client, "HTTPSConnection") as connection:
            response = connection.return_value.getresponse.return_value
            response.status, response.read.return_value = 200, b'{"id":"safe"}'
            self.assertEqual(gateway._http("GET", "/v1/users/me", None, TOKEN), (200, {"id": "safe"}))
            connection.assert_called_once_with("msi.olivium.space", timeout=20)
            sent = connection.return_value.request.call_args
            self.assertEqual(sent.args[:2], ("GET", "/gateway/v1/users/me"))
            self.assertEqual(sent.args[3]["Authorization"], "Bearer " + TOKEN)
            connection.return_value.close.assert_called_once()

    def test_http_redirect_and_malformed_response_fail_closed(self):
        gateway = cleanup.Gateway(cleanup.DEFAULT_GATEWAY, self.ledger, [CLIENT])
        for status, body in [(302, b""), (200, b"<html>bad</html>")]:
            with patch.object(cleanup.http.client, "HTTPSConnection") as connection:
                response = connection.return_value.getresponse.return_value
                response.status, response.read.return_value = status, body
                with self.assertRaises(cleanup.Refused):
                    gateway._http("GET", "/v1/users/me", None, TOKEN)
                self.assertEqual(connection.return_value.request.call_count, 1)

    def test_uncertain_mint_still_records_attempt_without_secret(self):
        gateway = cleanup.Gateway(cleanup.DEFAULT_GATEWAY, self.ledger, [CLIENT], transport=lambda *args: (200, {}))
        with self.assertRaises(cleanup.Refused):
            gateway.token(CLIENT)
        self.assertIn("issuance-attempt", self.ledger.path.read_text())

    def test_audit_unknown_offer_status_is_not_silently_clean(self):
        original = self.stub
        def unknown(method, path, body, token):
            status, document = original(method, path, body, token)
            if path == "/v1/jeebers/me/offers" and document["items"]:
                document["items"][0]["status"] = "surprise"
            return status, document
        engine = self.engine()
        engine.gateway.transport = unknown
        with self.assertRaisesRegex(cleanup.Refused, "unknown state"):
            engine.audit([CLIENT, DRIVER])

    def test_mint_sends_the_plan_role_set_per_actor_and_records_it(self):
        self.engine().sweep()
        self.assertEqual(dict(self.stub.mints), {DRIVER: ("customer", "driver"), CLIENT: ("customer",)})
        notes = {item["id"]: item["note"] for item in self.ledger.load() if item["kind"] == "session"}
        self.assertIn("roles=customer+driver;", notes[DRIVER])
        self.assertIn("roles=customer;", notes[CLIENT])

    def test_mint_without_roles_is_404_and_stops_before_any_delete(self):
        original = self.stub
        def stripped(method, path, body, token):
            return original(method, path, {"userId": body["userId"]} if path == "/auth/tokens" else body, token)
        engine = self.engine()
        engine.gateway.transport = stripped
        with self.assertRaisesRegex(cleanup.Refused, "contract"):
            engine.sweep()
        self.assertEqual(self.deletes(), [])

    def test_superseded_offer_is_terminal_for_audit_and_sweep(self):
        self.stub.offers[OFFER]["status"] = "superseded"
        self.stub.offers[STRAY] = {"id": STRAY, "requestId": REQUEST, "jeeberId": DRIVER, "status": "superseded"}
        self.engine().audit([CLIENT, DRIVER])
        self.engine().sweep()
        self.assertEqual(self.deletes(), ["/v1/requests/" + REQUEST])
        self.assertEqual(self.stub.offers[OFFER]["status"], "superseded")
        self.assertEqual(self.stub.offers[STRAY]["status"], "superseded")

    def test_edited_offer_is_withdrawn_before_the_request_is_cancelled(self):
        self.stub.offers[OFFER]["status"] = "edited"
        self.engine().sweep()
        self.assertEqual(self.deletes(), ["/v1/offers/" + OFFER, "/v1/requests/" + REQUEST])
        self.assertEqual(self.stub.offers[OFFER]["status"], "withdrawn")

    def test_audit_known_id_with_wrong_parent_is_not_silently_clean(self):
        self.stub.offers[OFFER]["requestId"] = OTHER
        with self.assertRaisesRegex(cleanup.Refused, "binding"):
            self.engine().audit([CLIENT, DRIVER])


if __name__ == "__main__":
    unittest.main(verbosity=2)
