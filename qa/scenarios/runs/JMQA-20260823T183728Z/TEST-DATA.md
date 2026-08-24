# Synthetic test-data register

No credential, phone number, OTP, token, raw account/entity identifier, precise
location, chat content, face, or identity document is recorded here.

| Alias | Persona/use | Reserved lane | Mutation scope | Cleanup owner | State |
|---|---|---|---|---|---|
| A33-existing | Super Login Plus–seeded synthetic session; selected role and KYC fixture were not independently proven | A33 | R0 read-only navigation only | QA run coordinator | USED / NO MUTATION / INVALID FOR AUTH-ROLE-KYC SIGN-OFF |
| EMU-fresh | Fresh emulator state, if a cleared build is available | API-35 | R0 only until fixture approval | QA run coordinator | PENDING |

The same unchanged `A33-existing` session produced the visually Approved and
crafted Rejected KYC checkpoints. The session was created earlier through
debug-only Super Login Plus and survived an in-place release-flavor update, so
it cannot prove normal authentication, selected persona/role, or authoritative
KYC state. No product write occurred, but a clean package-data reset is required
before the next valid run and needs explicit approval. The delivery/chat
entities were pre-existing; their raw identifiers, location, and message
contents remain private and are not registered here.
