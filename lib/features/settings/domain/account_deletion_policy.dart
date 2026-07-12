/// Account-deletion / scheduled-purge policy constants (E20, JEBV4-215).
///
/// Jeeb account deletion is a **soft status-flip + scheduled purge** (Q-079,
/// GR-2): confirming "Delete account" flips the profile status to `deleted`
/// (deactivating the account immediately) and enqueues it for a **permanent
/// purge** run by the gateway's scheduled purge worker after a grace window.
/// Signing in again before the purge fires reverses the flip and keeps the
/// account — this is why the purge is *scheduled*, not immediate.
///
/// [kAccountPurgeGraceDays] is the grace window surfaced to the user in the
/// deletion copy. It **MIRRORS the gateway purge-worker SLA** and must stay in
/// lock-step with it: the number the user is told here must equal the number
/// of days the purge worker actually waits before hard-deleting the record.
///
/// 30 days is the App-Store / Play-Store account-deletion grace default and is
/// the value assumed by the gateway spec attached to JEBV4-215. It is flagged
/// **owner-confirm**: once the gateway exposes the concrete scheduled-purge date
/// (e.g. on the deletion response or `getMe`), the client should render that
/// server-driven date and this constant can be dropped.
const int kAccountPurgeGraceDays = 30;
