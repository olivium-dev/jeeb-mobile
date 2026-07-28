# b02 — chat-header redesign: device evidence

Captured on an Android emulator, **Pixel-class geometry 1080×2400 px @ 420 dpi =
411×914 dp** (identical to the geometry the widget tests assert), driven through
the Dev Tool → Screen Catalog → `ChatDetailScreen` → *"Accepted — 1:1 thread +
pinned summary"*. That catalog state renders the **real** `ChatDetailScreen`
with a fixture `OrderChatSummary`, so both headers are on screen together — the
exact configuration the owner rejected.

## Binary provenance

The "after" shots were taken on a build whose APK was re-read **on the device**
and matched the host artifact byte-for-byte:

```
host     sha256 = 23d64c80d512a0b531f6bf0d1ead22b0c611fea7fd349ce6b3f6b67ec2b3d528
on-device sha256 = 23d64c80d512a0b531f6bf0d1ead22b0c611fea7fd349ce6b3f6b67ec2b3d528
```

(`versionName`/`versionCode` cannot distinguish builds — see
`docs/batches/b02-20260726/TESTING-INSTRUMENTS.md` I-11/I-15.) The "before"
shots were taken on the build already installed on that emulator; the branch's
code had never been compiled at that point, so any installed build is a valid
"before".

## Files

| File | State |
|---|---|
| `BEFORE-01-keyboard-closed.png` | pre-change, keyboard closed |
| `BEFORE-02-keyboard-open.png` | **pre-change, keyboard open** — the reported screen |
| `AFTER-01-keyboard-closed-collapsed.png` | post-change, keyboard closed, header collapsed (default) |
| `AFTER-02-keyboard-open-collapsed.png` | **post-change, keyboard open** |
| `AFTER-03-keyboard-open-expanded.png` | post-change, keyboard open, header expanded by the user |

A keyboard-closed shot alone hides the problem, which is why the pair that
matters is `BEFORE-02` vs `AFTER-02`.

## Measured heights (device pixels ÷ 2.625 = dp)

| Element | Before | After (collapsed) | Δ |
|---|---|---|---|
| Pinned order summary | 491 px = **187 dp** | 145 px = **55 dp** | −132 dp |
| Offer-accepted banner | 159 px = **61 dp** | 170 px = **65 dp** | +4 dp |
| **Both headers** | **248 dp** | **120 dp** | **−52 %** |
| Message list, keyboard OPEN | 496 px = **189 dp** | 832 px = **317 dp** | **+68 %** |

The 120 dp figure is the same number `chat_header_overflow_test.dart` prints for
the same 411×914 dp / 300 dp-keyboard geometry, so the widget test and the
device agree.

## What the pair shows

* **Before:** two full-bleed saturated slabs — the tone-40 brand orange over the
  brand navy — occupying 248 dp, with the message list squeezed to 189 dp
  (one and a half bubbles) and "Pay cash on delivery" faded into the orange.
* **After:** one 48 dp row of neutral tonal surface carrying reference · status ·
  amount plus a disclosure chevron, and a compact low-chroma success banner. One
  accent (the status chip), no competing chroma, and the thread keeps 317 dp.
* **Expanded:** the disclosure reveals the party line, the view-summary link,
  the requirement, the ETA/tier chips and the cash reminder. Note that with the
  keyboard open the expanded chrome reaches its 40 %-of-viewport bound, so the
  bounded slot scrolls and the banner moves below the fold — the message list is
  never starved, which is the whole point of the bound.
