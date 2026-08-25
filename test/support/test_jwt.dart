/// Structurally valid, non-secret test JWT with an expiry in 2100.
///
/// Session tests intentionally use an arbitrary signature because the mobile
/// app validates structure/expiry while the server remains the signature
/// authority on authenticated API reads.
const validTestJwt =
    'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.'
    'eyJzdWIiOiJ0ZXN0LXVzZXIiLCJleHAiOjQxMDI0NDQ4MDB9.'
    'test-signature';
