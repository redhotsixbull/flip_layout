# Contributing to flip_layout

Thanks for your interest. This is a young project — every issue and PR helps.

## Development setup

```bash
git clone https://github.com/redhotsixbull/flip_layout.git
cd flip_layout
flutter pub get
flutter analyze
flutter test
```

Run the example app (recommended — the animations are what this package is about):

```bash
cd example
flutter pub get
flutter run -d macos   # or ios / android / chrome
```

## Code style

- `dart format .` before committing.
- `flutter analyze` must be clean (zero info/warning/error).
- New public APIs need a dartdoc `///` comment on the class / member.
- Prefer relative imports inside `lib/src/`, package imports (`package:flip_layout/...`) in tests and examples.

## Tests

- **Widget tests** should verify:
  - Widget builds and renders its child.
  - Reorder / filter operations don't crash or leak state.
  - `LayoutMotion` is present under `AnimatedLayout.wrap`.
- **Visual behavior** — animations themselves are hard to test in unit tests.
  For those, add a demo to `example/lib/main.dart` and describe what should
  visually happen in the PR.
- Every bug fix ships with a regression test where possible.

## Key correctness rule

`LayoutMotion` relies on **stable `Key`s** on its children to preserve state
across rebuilds. If you're demonstrating a new pattern in the example or
docs, always pass a `ValueKey` (or similar) — omitting the key is the #1
cause of "why isn't my animation playing" bug reports.

## Commits

- Present-tense imperative subject: `add spring driver`, not `added`.
- Reference the issue if applicable: `add spring driver (fixes #4)`.
- Keep commits small and focused.

## PRs

- One logical change per PR.
- Fill in the description: what changed, why, and how to test *visually* if
  the change is animation-related.
- Green CI is required.
- Breaking API changes need a `CHANGELOG.md` entry and, on merge, a minor
  version bump (pre-1.0). After 1.0 they need a major bump.

## Roadmap alignment

Before starting a large feature, please open a discussion issue or check
[ROADMAP.md](./ROADMAP.md) to see if it's already planned or explicitly
out of scope.
