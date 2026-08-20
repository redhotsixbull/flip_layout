# flip_layout

Auto layout animation for Flutter. Wrap a widget in `LayoutMotion` and it smoothly slides to its new position whenever the parent's layout changes — reorders, filters, expansions.

Inspired by Framer Motion's `layout` prop. Implements the **FLIP** technique (First, Last, Invert, Play): measure old & new positions, apply an inverse transform, animate the transform to identity.

> **Status:** v0.0.1 — early alpha. API surfaces may change.

## Features (v0.0.1)

- `LayoutMotion({child, duration, curve, animateSize})` — auto-animates any widget when its own screen position changes
- `AnimatedLayout` — convenience wrapper that provides a `wrap(child)` helper for building lists whose children animate

## Not yet

- Shared element transitions across route changes (`layoutId`)
- Enter/exit animations (`AnimatePresence`)
- Spring physics driver
- Coordinated group animations (Framer's `<LayoutGroup>`)

## Quick example

Reorderable list:

```dart
List<int> items = [1, 2, 3, 4, 5];

Column(
  children: items.map((i) => LayoutMotion(
    key: ValueKey(i),
    duration: Duration(milliseconds: 250),
    child: Card(child: ListTile(title: Text('Item $i'))),
  )).toList(),
);

// Later:
setState(() => items.shuffle());
// → each card slides to its new position.
```

Filtered grid:

```dart
Wrap(
  children: allTags.where(matchesQuery).map((tag) => LayoutMotion(
    key: ValueKey(tag),
    child: Chip(label: Text(tag)),
  )).toList(),
);
```

## How it works

Every frame, `LayoutMotion` schedules a post-frame callback that measures its
`RenderBox`'s screen position. If the bounds differ from the previous frame,
it sets `_fromOffset = previous - current` and runs an `AnimationController`
from `0.0 → 1.0`, lerping the transform back to `Offset.zero`. The widget is
already sitting at its new location, but visually appears to travel from where
it used to be.

## License

MIT
