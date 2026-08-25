# Chat realtime descriptor gateway handoff

Mobile production realtime is intentionally fail-closed until the gateway
descriptor binds the authenticated actor explicitly.

At inspected `jeeb-gateway` commit
`231736d661e3dffe5365ee4f1d37be3b0cdeef84`,
`GET /v1/realtime/{tenant}:chat:{conversationId}` returns
`conversationId`, `topic`, `roleInConvo`, and `ticket`. It does not return the
authenticated viewer ID, so mobile cannot prove the descriptor was minted for
its active session.

Required additive gateway contract:

- Add non-empty camel-case `viewerId` to `RealtimeChannelDescriptor`.
- Set it only from `UserIdentity.TryGetUserId`; never accept it from the route,
  query, or request body.
- Keep `conversationId`, `topic`, `roleInConvo`, and `ticket` unchanged.
- Contract-test that `viewerId` equals the bearer subject for `client`,
  `jeeber_offerer`, and `jeeber_winner` descriptors.
- Contract-test that callers cannot assert another viewer ID.

No socket host or second token is requested from the gateway. The reviewed
mobile release injects `JEEB_REALTIME_SOCKET_URL` at compile time and uses the
existing membership ticket. Until the additive `viewerId` field is deployed,
chat safely degrades to its existing REST/push behavior without opening a
socket.
