# flip_layout

[![pub package](https://img.shields.io/pub/v/flip_layout.svg)](https://pub.dev/packages/flip_layout)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Declarative layout & presence animations for Flutter** — change your state,
and collections animate themselves. Inspired by
[Framer Motion](https://www.framer.com/motion/)'s `layout` prop and
`AnimatePresence`.

Flutter's built-ins are either **size-only** (`AnimatedSize`, `ExpansionTile`)
or **imperative** (`AnimatedList`/`SliverAnimatedList` need a controller and
manual insert/remove calls, and only work in a `ListView`). `flip_layout` fills
the gap: a **declarative** collection animator that does **enter/exit + layout**
in **any** layout — `Wrap`, `GridView`, `Column`, your own — just by changing the
list you pass it.

> **Status:** `0.1.0` — early but usable. Core is covered by tests and runs on
> every platform (mobile, desktop, **web**).

## See it

| Filter a `Wrap` (enter/exit) | Reorder (FLIP + spring) | Add / remove (enter/exit) |
|---|---|---|
| ![filter](doc/images/filter.gif) | ![reorder](doc/images/reorder.gif) | ![add/remove](doc/images/addremove.gif) |

Typing a query removes the non-matching chips (they fade out) and the survivors
slide up to fill the gaps — in a `Wrap`, which no Flutter built-in animates.

```bash
cd example && flutter run          # mobile / desktop
cd example && flutter run -d chrome # web
```

## Install

```yaml
dependencies:
  flip_layout: ^0.1.0
```

## `MotionGroup` — the main event

Give it a keyed list of children and a `builder` that arranges them. It handles
the rest:

```dart
MotionGroup(
  // adding/removing/reordering these just works
  children: [
    for (final tag in visibleTags)
      Chip(key: ValueKey(tag), label: Text(tag)),
  ],
  builder: (context, children) => Wrap(spacing: 8, children: children),
)
```

- **Enter** — new children fade + scale in.
- **Exit** — removed children are kept mounted and animated out *before* being
  removed (an `AnimatePresence` equivalent — Flutter can't otherwise animate a
  widget that's already gone from the tree).
- **Layout** — survivors slide (FLIP) to their new positions.
- `stagger` — delay between children entering, for a staggered reveal.
- `transitionBuilder` / `exitTransitionBuilder` — customise the enter and (optionally
  separate) exit transitions. Default: fade + scale.
- `animateInitial` — whether the first batch animates in.

Every child **must** carry a unique `Key`.

## `MotionConfig` — set defaults once

Wrap a subtree to give every `MotionGroup`/`LayoutMotion` below it the same
`duration`/`curve`/`stagger`, and to honour reduced-motion:

```dart
MotionConfig(
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOutBack,
  // reduceMotion: null → follows the OS "reduce motion" setting automatically
  child: MyPage(),
)
```

Precedence for any value: the widget's own argument → the nearest `MotionConfig`
→ a built-in default. When motion is reduced (config or the platform
accessibility setting), animations are skipped and changes apply instantly.

## Shared-element "magic move" (`layoutId` for Flutter)

Flutter's `Hero` only animates **across routes**. `MotionSharedScope` +
`MotionSharedId` animate a shared element **within the same page** — grid → detail,
list → hero, tab → tab — no route change:

<p align="center">
  <img src="doc/images/shared.gif" width="260" alt="A grid tile flying to a detail view and back, within one page">
</p>

```dart
MotionSharedScope(
  child: selected == null
      ? GridView(children: [
          for (final item in items)
            GestureDetector(
              onTap: () => setState(() => selected = item),
              child: MotionSharedId(id: item.id, child: Thumb(item)),
            ),
        ])
      : Center(child: MotionSharedId(id: selected!.id, child: BigCard(selected!))),
)
```

Give two widgets the same `id` under one scope; when one replaces the other (or
just moves), a copy flies from the old rect to the new one. Shared children
should be **size-flexible** (no fixed width/height) so the flight interpolates
layout smoothly.

## Spring motion

Pass a `SpringCurve` anywhere a curve is accepted for a natural
overshoot-and-settle:

```dart
MotionGroup(
  duration: const Duration(milliseconds: 520),
  curve: SpringCurve(stiffness: 220, damping: 14),
  ...
)
```

Lower `damping` bounces more; higher `damping` settles without overshoot.

## `LayoutMotion` — position-only, for a single widget

If you just want one widget to slide when *its own* position changes (and don't
need enter/exit), wrap it directly:

```dart
LayoutMotion(
  key: ValueKey(id),
  child: Card(child: ListTile(title: Text('Item $id'))),
)
```

It measures its untransformed bounds each real layout change and animates from
the old position to the new one (the **FLIP** technique). Inside a `Scrollable`
it measures in scroll-content space, so plain scrolling doesn't trigger a
spurious slide.

## When *not* to use this

Reach for a Flutter built-in instead when it already fits — don't fight it:

- **Expand / collapse one widget's size** → `AnimatedSize` or `ExpansionTile`.
  (Animating a *continuously* resizing widget with FLIP causes jitter, because
  FLIP is for **discrete** position changes.)
- **Drag-to-reorder a list** → `ReorderableListView`.
- **A huge, lazily-built list** → `AnimatedList`/`SliverAnimatedList` (virtualised).

`flip_layout` shines for **declarative** enter/exit + reflow of **modest
collections in arbitrary layouts** (filtered chips, tag grids, dashboards,
kanban columns) — the cases the built-ins don't cover.

## Known limitations

- Shared-element transitions are **within-page** (`MotionSharedScope`); for
  cross-*route* transitions use Flutter's `Hero`. Shared children should be
  size-flexible, and the flight interpolates the whole child (no separate
  shuttle builder yet).
- `SpringCurve` gives a spring *look* (fixed-duration, normalised) — it is not
  velocity-preserving physics; interruptions are position-continuous but don't
  carry momentum.
- `LayoutMotion.animateSize` interpolates size with `Transform.scale`, which
  visually stretches children — treat it as a visual-only effect for uniform
  boxes.
- Best for modest collections; there's no virtualisation.

See [`doc/SPEC.md`](doc/SPEC.md) and [`doc/ROADMAP.md`](doc/ROADMAP.md).

## License

MIT
