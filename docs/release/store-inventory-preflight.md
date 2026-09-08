# Isolated store inventory preflight

`mobile-store-inventory-preflight.yml` executes only the existing root
`preflight_internal` lane on exact current protected main, for the designated
owner, using the existing protected `mobile-rc` environment. It has no signing,
build, upload, Clarity flags, artifact publication or downstream job.
Token permissions are only contents:read and actions:read; the latter permits
the authoritative environment-policy read, not workflow or release writes.

This is **not strictly GET-only**: the pinned Fastlane Play reader creates an
uncommitted edit, reads each track, then aborts the edit. No edit commit, release
change or artifact upload is authorized. The standalone guard ensures abort on
read/parse failure, refuses an already-open edit, requires cleared edit state,
and tracks all four aborts before reporting complete Play cleanup. Per-request
edit-create retries and Supply wrapper retries are disabled. An uncertain create
response or forced process termination cannot prove cleanup: the run fails and
requires reconciliation, never a success receipt or blind retry.

The existing lane checks Play internal/alpha/beta/production version codes and
the existing paginated global iOS App Store build inventory. The newer GET-only
Play release-summary endpoint is not substituted: it excludes obsolete releases
and caps responses at20. Original release-number policy is unchanged.

Keys remain in environment/process memory, not files. The process suppresses raw
library stdout/stderr and bypasses LaneManager's report.xml/docs writers. No key
or provider error body is published. JSON contains only validated numeric maxima,
fixed phase names and booleans. Access booleans mean the configured credentials
could access the exact package/bundle, not independently verified account ownership.
On failure, maxima appear only for completed inventories; candidate_monotonic is
false only after policy rejection and null if unverified. The process exits
nonzero either way. A successful preflight does not reserve a
number or prove later upload eligibility.

Guard fixtures use synthetic clients, not production credentials. The source
contract pins the exact existing Fastfile and ASC reader bytes: a future lane
change requires review before this standalone workflow can consume credentials.

Sources: [pinned Fastlane reader](https://github.com/fastlane/fastlane/blob/56ee6ca6717d3d0a2b182f6a517211fe9d85f860/supply/lib/supply/reader.rb),
[pinned client](https://github.com/fastlane/fastlane/blob/56ee6ca6717d3d0a2b182f6a517211fe9d85f860/supply/lib/supply/client.rb),
[Google edit insert](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/insert),
[limited GET release summaries](https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases/list).
