"""Ledger-bound device cleanup. Live reads and session issuance require --execute."""

import argparse
from datetime import datetime, timezone
import fcntl
import http.client
import json
import os
from pathlib import Path
import re
import sys
import uuid
from urllib.parse import urlsplit


DEFAULT_GATEWAY = "https://msi.olivium.space/gateway"
GATEWAYS = frozenset({DEFAULT_GATEWAY, "https://192.168.2.39/gateway"})
TERMINAL = frozenset({"cancelled", "expired", "delivered", "rated", "disputed"})
PRE_ACCEPT = frozenset({"pending", "scheduled", "matched"})
OTHER_REQUEST_STATES = frozenset({"accepted", "picked_up", "heading_off", "at_door", "cancellation_requested"})
PENDING_OFFERS = frozenset({"pending", "submitted", "edited"})
TERMINAL_OFFERS = frozenset({"withdrawn", "expired", "rejected", "superseded"})
REQUEST_OWNER_ROLES = ("customer",)
OFFER_OWNER_ROLES = ("customer", "driver")
MAX_RESPONSE = 8 * 1024 * 1024


class Refused(Exception):
    pass


class OwnerRequired(Refused):
    pass


def identifier(value):
    try:
        normalized = str(uuid.UUID(value))
    except (ValueError, TypeError, AttributeError) as error:
        raise Refused("IDs must be UUIDs, never tokens or arbitrary paths") from error
    if normalized != value.lower():
        raise Refused("IDs must use canonical UUID formatting")
    return normalized


def gateway_url(value):
    if value not in GATEWAYS:
        raise Refused("Gateway refused: only fixed MSI HTTPS origins are allowed; production and overrides are forbidden")
    return value


def rows(document):
    if isinstance(document, list):
        result = document
    elif isinstance(document, dict) and isinstance(document.get("items"), list):
        result = document["items"]
        if document.get("hasMore") or document.get("hasNextPage") or document.get("nextCursor") or document.get("nextPage"):
            raise Refused("Incomplete paginated list; hand to owner instead of claiming clean")
        total = document.get("totalCount", len(result))
        if type(total) is not int or total != len(result):
            raise Refused("List total is incomplete or inconsistent")
    else:
        raise Refused("Unexpected list shape; no cleanup proof")
    if not all(isinstance(item, dict) for item in result):
        raise Refused("Unexpected list item shape")
    return result


class Ledger:
    def __init__(self, directory, gateway):
        self.directory = Path(directory)
        self.gateway = gateway_url(gateway)
        if not self.directory.is_absolute() or not self.directory.is_dir():
            raise Refused("Evidence directory must be an existing absolute directory")
        self.path = self.directory / "CREATED.jsonl"

    def record(self, kind, entity_id, owner, note="", request_id=None):
        entity_id, owner = identifier(entity_id), identifier(owner)
        if kind not in {"request", "offer", "session", "note"}:
            raise Refused("Unknown ledger kind")
        if len(note) > 160 or re.search(r"[\r\n]|bearer|token\s*[:=]|eyJ[A-Za-z0-9_-]+\.", note, re.I):
            raise Refused("Note must be short and contain no credentials")
        if kind == "offer" and request_id is None:
            raise Refused("Offer records require --request")
        if kind == "session" and entity_id != owner:
            raise Refused("Session records contain the user ID only, never session credentials")
        item = {"ts": datetime.now(timezone.utc).isoformat(), "kind": kind, "id": entity_id,
                "ownerUserId": owner, "note": note, "gateway": self.gateway}
        if request_id is not None:
            item["requestId"] = identifier(request_id)
        descriptor = os.open(self.path, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "a", encoding="utf-8") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(json.dumps(item) + "\n")
            stream.flush()
            os.fsync(stream.fileno())

    def load(self):
        if not self.path.exists():
            raise Refused("Ledger missing; record created entities first")
        if self.path.is_symlink() or self.path.stat().st_size > 1024 * 1024:
            raise Refused("Unsafe or oversized ledger")
        result, seen = [], {}
        with self.path.open(encoding="utf-8") as stream:
            fcntl.flock(stream, fcntl.LOCK_SH)
            for line in stream:
                try:
                    item = json.loads(line)
                    kind = item["kind"]
                    if kind not in {"request", "offer", "session", "note"} or item["gateway"] != self.gateway:
                        raise Refused("Ledger kind/gateway mismatch")
                    item["id"], item["ownerUserId"] = identifier(item["id"]), identifier(item["ownerUserId"])
                    if kind == "offer":
                        item["requestId"] = identifier(item["requestId"])
                    if kind == "session" and item["id"] != item["ownerUserId"]:
                        raise Refused("Invalid session ledger record")
                except (ValueError, TypeError, KeyError) as error:
                    raise Refused("Malformed ledger; repair provenance manually, never infer ownership") from error
                key = (kind, item["id"])
                identity = (item["ownerUserId"], item.get("requestId"))
                if key in seen and seen[key] != identity:
                    raise Refused("Conflicting ledger ownership")
                if key not in seen:
                    result.append(item)
                seen[key] = identity
        return result


class Gateway:
    def __init__(self, url, ledger, actors, transport=None):
        self.url, self.ledger = gateway_url(url), ledger
        self.actors = {identifier(actor) for actor in actors}
        self.offer_owners = {item["ownerUserId"] for item in ledger.load() if item["kind"] == "offer"}
        self.tokens = {}
        self.transport = transport or self._http

    def _http(self, method, path, body, token):
        connection = http.client.HTTPSConnection(urlsplit(self.url).hostname, timeout=20)
        headers = {"Accept": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        payload = None if body is None else json.dumps(body).encode()
        if payload:
            headers["Content-Type"] = "application/json"
        try:
            connection.request(method, "/gateway" + path, payload, headers)
            response = connection.getresponse()
            raw = response.read(MAX_RESPONSE + 1)
            if len(raw) > MAX_RESPONSE:
                raise Refused("Gateway response exceeded safe limit")
            status = response.status
            if 300 <= status < 400:
                raise Refused("Redirect refused; gateway origin cannot change")
            try:
                data = json.loads(raw) if raw else None
            except (ValueError, UnicodeError) as error:
                raise Refused("Gateway response was not valid JSON") from error
            return status, data
        finally:
            connection.close()

    def token(self, actor):
        actor = identifier(actor)
        if actor not in self.actors:
            raise Refused("Foreign actor is not explicitly authorized for this run")
        if actor not in self.tokens:
            roles = list(OFFER_OWNER_ROLES if actor in self.offer_owners else REQUEST_OWNER_ROLES)
            self.ledger.record("session", actor, actor,
                               "cleanup-session-issuance-attempt roles=" + "+".join(roles) +
                               "; outcome and expiry require residual-state review")
            status, document = self.transport("POST", "/auth/tokens", {"userId": actor, "roles": roles}, None)
            if status in {401, 403}:
                raise OwnerRequired("OpenMode off — hand to owner")
            if status != 200 or not isinstance(document, dict) or not isinstance(document.get("accessToken"), str) or not document["accessToken"]:
                raise Refused("Session issuance did not return the expected contract")
            token = document["accessToken"]
            status, identity = self.transport("GET", "/v1/users/me", None, token)
            if status != 200 or not isinstance(identity, dict) or identity.get("id", identity.get("userId")) != actor:
                raise Refused("Issued session identity does not match the authorized actor")
            self.tokens[actor] = token
        return self.tokens[actor]

    def call(self, actor, method, path, allowed=(200,)):
        status, document = self.transport(method, path, None, self.token(actor))
        if status in {401, 403}:
            raise OwnerRequired("Authorization changed — hand to owner")
        if status not in allowed:
            raise Refused(f"Gateway HTTP {status}; state not proven clean")
        return document


class Cleanup:
    def __init__(self, ledger, gateway, output=print):
        self.ledger, self.gateway, self.output = ledger, gateway, output
        items = ledger.load()
        self.requests = {item["id"]: item for item in items if item["kind"] == "request"}
        self.offers = {item["id"]: item for item in items if item["kind"] == "offer"}
        if any(item["ownerUserId"] not in gateway.actors for item in [*self.requests.values(), *self.offers.values()]):
            raise Refused("Every mutable ledger owner must be an explicitly authorized --actor")
        if any(item["requestId"] not in self.requests for item in self.offers.values()):
            raise Refused("Every offer requires its parent request provenance in this ledger")

    def request(self, item):
        document = self.gateway.call(item["ownerUserId"], "GET", "/v1/requests/" + item["id"])
        if not isinstance(document, dict) or document.get("id") != item["id"] or document.get("clientId") != item["ownerUserId"]:
            raise Refused("Request ID or owner differs from ledger; no mutation")
        status = document.get("status")
        if not isinstance(status, str):
            raise Refused("Request state is malformed")
        if status not in TERMINAL and (status not in PRE_ACCEPT or document.get("jeeberId") is not None):
            raise OwnerRequired("Request is accepted, assigned or unknown — hand to owner")
        return document

    def offers_for(self, item):
        found = rows(self.gateway.call(item["ownerUserId"], "GET", "/v1/requests/" + item["id"] + "/offers"))
        for offer in found:
            offer_id = identifier(offer.get("id"))
            if not isinstance(offer.get("status"), str):
                raise Refused("Offer state is malformed")
            if offer.get("requestId") != item["id"]:
                raise Refused("Offer parent differs from request")
            if offer.get("status") in PENDING_OFFERS:
                recorded = self.offers.get(offer_id)
                if recorded is None or recorded["ownerUserId"] != offer.get("jeeberId") or recorded["requestId"] != item["id"]:
                    raise Refused("Unledgered or foreign pending offer; no automatic withdrawal")
            elif offer.get("status") not in TERMINAL_OFFERS:
                raise OwnerRequired("Accepted or unknown offer state — hand to owner")
        return found

    def owned_offer(self, item):
        found = rows(self.gateway.call(item["ownerUserId"], "GET", "/v1/jeebers/me/offers"))
        for offer in found:
            if offer.get("jeeberId") != item["ownerUserId"]:
                raise Refused("Self-scoped offers returned foreign ownership")
        current = next((offer for offer in found if offer.get("id") == item["id"]), None)
        if current is not None and current.get("requestId") != item["requestId"]:
            raise Refused("Recorded offer belongs to a different request")
        if current is not None and (not isinstance(current.get("status"), str) or current["status"] not in PENDING_OFFERS | TERMINAL_OFFERS):
            raise OwnerRequired("Recorded offer was accepted or has unknown state — hand to owner")
        return current

    def sweep(self):
        for offer in self.offers.values():
            self.owned_offer(offer)
        for item in self.requests.values():
            self.request(item)
            observed = self.offers_for(item)
            for offer in self.offers.values():
                if offer["requestId"] == item["id"]:
                    current = self.owned_offer(offer)
                    parent = next((row for row in observed if row["id"] == offer["id"]), None)
                    if current and current["status"] in PENDING_OFFERS and parent is None:
                        raise Refused("Pending offer missing from parent projection; no mutation")
                    if parent and parent["status"] in PENDING_OFFERS and current is None:
                        raise Refused("Pending offer missing from own projection; no mutation")
                    # The two projections use different vocabularies (parent verbatim, own normalized),
                    # so only live-versus-terminal class may be compared.
                    if current and parent and (parent["status"] in PENDING_OFFERS) != (current["status"] in PENDING_OFFERS):
                        raise Refused("Offer liveness disagrees between parent and own projections; no mutation")
        for item in reversed(list(self.requests.values())):
            self.request(item)
            for offer in self.offers_for(item):
                if offer["status"] not in PENDING_OFFERS:
                    continue
                self.request(item)
                self.gateway.call(offer["jeeberId"], "DELETE", "/v1/offers/" + offer["id"], allowed=(204, 409))
                remaining = self.offers_for(item)
                current = next((row for row in remaining if row["id"] == offer["id"]), None)
                if current is not None and current["status"] not in TERMINAL_OFFERS:
                    raise Refused("Offer still pending after withdrawal " + offer["id"])
                current = self.owned_offer(self.offers[offer["id"]])
                if current is not None and current["status"] not in TERMINAL_OFFERS:
                    raise Refused("Own offer list is still pending after withdrawal " + offer["id"])
                self.output("CLEAN offer " + offer["id"])
            document = self.request(item)
            if any(offer["status"] in PENDING_OFFERS for offer in self.offers_for(item)):
                raise Refused("Pending offer remains; request cancellation refused")
            self.verify_owned_offers_terminal(item)
            if document["status"] not in TERMINAL:
                self.request(item)
                self.gateway.call(item["ownerUserId"], "DELETE", "/v1/requests/" + item["id"], allowed=(200, 409))
                document = self.request(item)
            if document["status"] not in TERMINAL:
                raise Refused("Request still non-terminal after cancellation " + item["id"])
            self.verify_owned_offers_terminal(item)
            self.output("CLEAN request " + item["id"] + " " + document["status"])
        for item in self.requests.values():
            if self.request(item)["status"] not in TERMINAL:
                raise Refused("Request is no longer terminal " + item["id"])
            if any(offer["status"] in PENDING_OFFERS for offer in self.offers_for(item)):
                raise Refused("Pending parent offer remains after sweep")
            self.verify_owned_offers_terminal(item)
        self.output("Sweep verified ledger-bound requests/offers only; immutable residue and sessions remain reportable.")

    def verify_owned_offers_terminal(self, request):
        for offer in self.offers.values():
            if offer["requestId"] != request["id"]:
                continue
            current = self.owned_offer(offer)
            if current is not None and current["status"] not in TERMINAL_OFFERS:
                raise Refused("Recorded own offer remains pending " + offer["id"])

    def audit(self, actors):
        dirty = False
        for actor in actors:
            for kind, path, owner_field, pending, ledger in [
                ("request", "/v1/requests?role=client", "clientId", None, self.requests),
                ("offer", "/v1/jeebers/me/offers", "jeeberId", PENDING_OFFERS, self.offers),
            ]:
                for item in rows(self.gateway.call(actor, "GET", path)):
                    entity_id = identifier(item.get("id"))
                    if item.get(owner_field) != actor:
                        raise Refused("Audit returned a foreign actor's row")
                    state = item.get("status")
                    known_states = TERMINAL | PRE_ACCEPT | OTHER_REQUEST_STATES if pending is None else PENDING_OFFERS | TERMINAL_OFFERS | {"accepted"}
                    if not isinstance(state, str) or state not in known_states:
                        raise Refused("Audit returned an unknown state")
                    recorded = ledger.get(entity_id)
                    if recorded is not None and (recorded["ownerUserId"] != actor or
                            (kind == "offer" and recorded["requestId"] != item.get("requestId"))):
                        raise Refused("Audit ledger binding differs from current ownership or parent")
                    active = state not in TERMINAL if pending is None else state in pending
                    if active and entity_id not in ledger:
                        self.output("UNLEDGERED " + kind + " " + entity_id + " owner " + actor)
                        dirty = True
        if dirty:
            raise Refused("Unledgered active state exists; report it, do not mutate it")
        self.output("Audit found no unledgered active requests/pending offers in complete returned lists.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["record", "sweep", "audit"])
    parser.add_argument("arguments", nargs="*")
    parser.add_argument("--request")
    parser.add_argument("--actor", action="append", default=[])
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args(argv)
    try:
        gateway = gateway_url(os.environ.get("JEEB_GATEWAY", DEFAULT_GATEWAY))
        directory = os.environ.get("JEEB_DEVICE_EVIDENCE_DIR")
        if not directory:
            raise Refused("JEEB_DEVICE_EVIDENCE_DIR is required")
        ledger = Ledger(directory, gateway)
        if args.command == "record":
            if len(args.arguments) not in {3, 4}:
                raise Refused("record KIND ID OWNER [NOTE] [--request UUID]")
            ledger.record(*args.arguments, request_id=args.request)
            print("Recorded non-secret creation provenance.")
            return 0
        items = ledger.load()
        actors = args.arguments if args.command == "audit" else args.actor
        actors = [identifier(actor) for actor in actors]
        if not args.execute:
            print(f"DRY RUN ONLY: {len(items)} ledger rows; no HTTP, session issuance, mutation or cleanliness proof.")
            print("Use --execute with explicit actors only during an authorized cleanup window.")
            return 0
        if not actors:
            raise Refused("Explicit --actor IDs (sweep) or positional actor IDs (audit) required")
        cleanup = Cleanup(ledger, Gateway(gateway, ledger, actors))
        if args.command == "sweep":
            cleanup.sweep()
        else:
            cleanup.audit(actors)
        return 0
    except OwnerRequired as error:
        print(str(error), file=sys.stderr)
        return 2
    except Refused as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, http.client.HTTPException):
        print("Cleanup stopped safely; transport/storage evidence unavailable. No raw payload or credentials logged.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
