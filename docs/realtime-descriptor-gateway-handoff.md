# Chat realtime descriptor gateway handoff

Mobile production realtime consumes the gateway-owned descriptor and fails
closed unless every actor, channel, and credential binding is present.

The approved `jeeb-gateway` contract at `5f3da8b2` returns
`conversationId`, bearer-derived `viewerId`, canonical
`topic = jeeb:chat:{conversationId}`, `roleInConvo`, Guardian connect `token`,
and membership `ticket` from
`GET /v1/realtime/jeeb:chat:{conversationId}`.

Mobile contract enforcement:

- `viewerId` must equal the active bearer-bound mobile user.
- `conversationId` and `topic` must match the requested conversation exactly;
  the legacy `jeeb_conversation:*` topic is rejected.
- `roleInConvo` must be `client`, `jeeber_offerer`, or `jeeber_winner`.
- `token` and `ticket` must both be non-empty before any socket is created.
- `token` is sent only as the Phoenix socket connect query parameter expected
  by `LiveCommSocket.connect/3`.
- `ticket` is sent only in the `phx_join` payload; the two credentials are
  never swapped or duplicated.

The socket host remains the mobile-owned compile-time
`JEEB_REALTIME_SOCKET_URL` under the existing WSS allowlist policy. Invalid or
incomplete descriptors degrade to the existing REST/push behavior without
opening a socket. Mobile never logs either credential.
