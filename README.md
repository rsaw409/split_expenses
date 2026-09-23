# Split Expense

Flutter client for **Split Expense** — split group expenses, track who owes whom, and settle up.
Published on Google Play as [`developer.rohitsaw.split`](https://play.google.com/store/apps/details?id=developer.rohitsaw.split).

> The backend is a **separate service and is not in this repo.** The app ships pointing at a hosted
> instance (`lib/src/services/server.dart`), so a fresh clone runs against real data without any
> setup; that file also has a commented-out `localhost` line for local backend work.

## Getting started

```bash
flutter pub get
flutter run -d <device>      # Android is the platform to use — see below
```

Built with Flutter **3.44.9** (the version CI pins); Dart SDK `>=3.4.4 <4.0.0`.

## Platform support

| Platform | State |
|---|---|
| **Android** | Supported, and the only platform verified end to end. |
| iOS | Untested — no known blocker, just never exercised. |
| Web | **Broken.** Firebase has no web config, so `DefaultFirebaseOptions.currentPlatform` throws on the `chrome`/`web-server` devices. |
| macOS | **Broken.** `macos/Runner.xcodeproj`'s `MACOSX_DEPLOYMENT_TARGET` (10.14, in all three build configs) predates what current Xcode/CocoaPods require (12.0+); bump it project-wide to fix. |
| Linux / Windows | Scaffolding only, never tried. |

## How it works

State lives in `ChangeNotifier` controllers wired up once through a `MultiProvider` in
`lib/main.dart`; views read them with `context.watch` / `Selector` rather than constructor
plumbing. Networking is plain `http` calls in `lib/src/services/` — no codegen, no client wrapper.

```
lib/src/
  components/        shared widgets (loading/error/empty states, expense tile, drawer)
  models/            immutable Equatable models with hand-written fromMap/toMap
  notify_controllers/ChangeNotifier state (groups, expenses, balances, reachability)
  services/          HTTP calls, local cache, API errors
  theme/             Material 3 theme built from a seed colour, spacing/radius scale
  utils/             currency formatting, expense filters, idempotency keys
  views/             screens
```

`CLAUDE.md` carries the detailed architecture notes, including the invariants worth preserving
before changing the caching or write paths.

### Works offline

Expenses and balances are cached per group in `SharedPreferences`. A cold start paints from that
cache immediately and refetches in the background, so losing connectivity degrades to last-known
data with a banner rather than an error screen. Reads — including the per-user expense, payment and
"benefits from" breakdowns — are served from the cache and filtered locally, so they need no
network at all.

Writes still require the backend and are blocked (with an explanation) when it can't be reached;
there is no offline write queue. Every write carries an `idempotency_key`, so retrying one that
timed out cannot double-charge anyone.

Reachability is judged by probing **this app's own backend**, not a third party, so the app doesn't
declare itself offline on networks that happen to block someone else's domain.

## Tests

```bash
flutter test                 # all
flutter test test/expense_filters_test.dart
```

Coverage is focused on the logic where a mistake costs real money or silently corrupts state: the
cache-first load state machine, the per-user expense filters (checked against the live backend's own
numbers), idempotency-key lifecycles, and member derivation. `test/unit_test.dart` and
`test/widget_test.dart` are still the untouched Flutter templates.

## CI/CD

`.github/workflows/android-release.yml` runs `flutter analyze` and `flutter test` on every push and
PR to `main`, builds a signed app bundle, and on pushes to `main` releases to the Play Store
production track.

Only the version **name** in `pubspec.yaml` is bumped by hand — CI overwrites the build number with
the workflow's run number, so the `+N` you commit is irrelevant.
