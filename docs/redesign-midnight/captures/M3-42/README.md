# M3-42 — rating_prompt · NO CAPTURES (deletion row)

This row is the ratified ORPHAN **deletion** (02-STUDY-NOTES §ORPHAN; owner
confirm = §8 Q9), not a restyle. `RatingPromptScreen`, its 6 `@JeebPreview`
functions, its fixture file, its single catalog entry (7 states) and its
28-test preview suite were removed. The **route and its redirect survive** —
`/orders/:id/rate` is the live rating-push deep-link target — with a minimal
inline builder in place of the deleted screen. Nothing is left to mount and
nothing to capture.

## A known-red capture CLOSES with this row

`deep-link-targets__ratingpromptscreen__4-compact-320-568-200-text` was one of
the two remaining red catalog captures (M0-9 harness ruling: "rating-prompt
compact overflow (screen defect → its M3 row)"). Measured at HEAD before the
deletion, that capture was `ERROR` and the other six were `SUCCESS`; after the
deletion **no rating-prompt capture exists at all**, so the red is gone rather
than suppressed. The overflow was a real defect of a screen no user could
reach; deleting the screen is the ratified fix.

## Orphaned goldens, left in place

The 7 pass-1 capture PNGs the deleted catalog entry used to produce still sit
in `docs/redesign-2026-08/actual/` and are now **orphaned goldens** — no
catalog entry regenerates or compares them any more:

    deep-link-targets__ratingpromptscreen__0-placeholder.png
    deep-link-targets__ratingpromptscreen__1-phone-390-844-100-text.png
    deep-link-targets__ratingpromptscreen__2-compact-320-568-100-text.png
    deep-link-targets__ratingpromptscreen__3-phone-390-844-200-text.png
    deep-link-targets__ratingpromptscreen__4-compact-320-568-200-text.png
    deep-link-targets__ratingpromptscreen__5-notched-393-852-inset-59-34-200-text.png
    deep-link-targets__ratingpromptscreen__6-phone-390-844-deep-link-id-dlv-2026-08-02-000914-never-shown.png

Left in place deliberately, matching the M3-15..16 precedent: they belong to
the previous pass's evidence tree (`redesign-2026-08`, §8 Q10), which this row
does not own. Sweep them with the rest of that tree, not here.
