# `/location` routes to a "coming soon" placeholder — and the Screen Catalog hides it

Found while removing the `Screen` exclusion from the coverage tool: two classes
named `LocationPickerScreen` exist.

| file | lines | what it is |
|---|---|---|
| `lib/features/location/presentation/location_picker_screen.dart` | **461** | a full implementation |
| `lib/features/location/presentation/screens/location_picker_screen.dart` | **36** | a placeholder |

`app_router.dart:76` imports the **36-line placeholder**, and `app_router.dart:970`
serves it at the `/location` route (`name: 'location-picker'`):

```dart
GoRoute(
  path: '/location',
  name: 'location-picker',
  builder: (context, state) => const LocationPickerScreen(),
),
```

What that placeholder renders:

```
Location Picker coming soon
This screen is not yet available.
```

Its own header says so: *"Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5).
Real implementation arrives in the per-feature follow-up ticket. Do NOT add
behavior here."*

## Why nobody noticed

The 461-line implementation is imported by **exactly one file in the repo** —
`lib/devtool/catalog/entries/batch_06_entries.dart`, the Screen Catalog.

So the designer-facing catalog renders a fully working Location Picker, while the
app itself routes to "coming soon". The catalog was the only consumer of the real
screen, and it is the surface people were reviewing. It gave false confidence
about a screen that does not ship.

This is also the sharpest argument for co-locating previews: a preview attached to
the *file the router actually imports* could not have drifted this way — opening
`screens/location_picker_screen.dart` would have shown the placeholder, which is
the truth.

## Not fixed here

Deciding whether `/location` should serve the real implementation is a product
call, not a preview one. Two things to check first: whether the follow-up ticket
T-MOB-FIX-001 mentions ever landed, and whether the 461-line version is current
against today's gateway contracts (it has had no consumer but the catalog, so it
has not been exercised by any real flow).
