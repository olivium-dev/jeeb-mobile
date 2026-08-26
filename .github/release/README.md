# Android internal candidate custody

The trusted Android internal-candidate workflow retains one file named
`candidate.cms`. Its authenticated CMS profile is AES-256-GCM with one
RSA-4096 OAEP/SHA-256 recipient.

The production recipient certificate must be committed by protected pull
request at `.github/release/android-internal-candidate-recipient.pem`. It must
contain only a valid RSA certificate with an exact 4096-bit key. The
matching unencrypted PKCS#8 private PEM is base64-encoded into the
`ANDROID_CANDIDATE_DECRYPT_KEY_B64` secret of the protected
`mobile-internal-distribution` environment. The private key must never be
committed, uploaded as an Actions artifact, or added to `mobile-rc`.

Until both halves are provisioned through their independent review paths, the
candidate and distribution workflows fail closed. There is no fallback key or
plaintext artifact path.
