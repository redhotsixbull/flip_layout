# API reference

## `LayoutMotion`

Wraps any widget. When the widget's position on screen changes due to
layout changes in its ancestors, it smoothly slides from the previous
position to the current one.

```dart
LayoutMotion({
  Key? key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeOutCubic,
  bool animateSize = false,
})
```

- `key` — should be a stable `Key` (e.g. `ValueKey(id)`) so Flutter preserves
  the underlying `Element` across rebuilds. Without a stable key, the
  `_previousBounds` state resets and no animation plays.
- `duration` — how long the slide animation runs.
- `curve` — easing applied to the interpolation from `previousOffset` to `Offset.zero`.
- `animateSize` — if `true`, also interpolate `Transform.scale` when the
  child's size changes. Distorts child rendering while animating — leave off
  unless you specifically want the scale effect.

Behavior:
- On every frame after build, measures its child's global bounds.
- If bounds differ from the previous frame, sets `fromOffset = previous - current`
  and drives an `AnimationController` from `0.0 → 1.0`, lerping the translation
  back to `Offset.zero`.
- Uses `Transform.translate` (paint-only) so it doesn't disturb the parent's layout.

---

## `AnimatedLayout`

Convenience wrapper. Instead of wrapping each child yourself, use a builder
that receives a `wrap` helper.

```dart
AnimatedLayout({
  Key? key,
  required Widget Function(BuildContext, Widget Function(Widget child) wrap) builder,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeOutCubic,
})
```

Example:

```dart
AnimatedLayout(
  duration: Duration(milliseconds: 250),
  builder: (context, wrap) => Wrap(
    spacing: 8,
    children: visibleTags.map((t) => wrap(
      Chip(key: ValueKey(t), label: Text(t)),
    )).toList(),
  ),
);
```

`wrap(child)` returns `LayoutMotion(key: child.key, duration: ..., curve: ..., child: child)`.
**The child must have a stable Key** — `wrap` reads `child.key` and passes
it through.

---

## Recipes

### Reorderable list

```dart
Column(
  children: items.map((i) => LayoutMotion(
    key: ValueKey('item-$i'),
    child: Card(child: ListTile(title: Text('$i'))),
  )).toList(),
);

setState(() => items.shuffle());   // → each card slides to its new position
```

### Filtered grid

```dart
Wrap(
  children: allTags.where(matches).map((t) => LayoutMotion(
    key: ValueKey('tag-$t'),
    child: Chip(label: Text(t)),
  )).toList(),
);
```

### Expandable card

```dart
LayoutMotion(
  key: ValueKey('card-$i'),
  child: AnimatedContainer(
    duration: Duration(milliseconds: 300),
    height: isOpen ? 200 : 60,
    child: ...,
  ),
);
```

Here the `AnimatedContainer` handles the size interpolation on the card
itself. `LayoutMotion` handles the position slide of the *other* cards that
have to make room.

---

## When NOT to use `LayoutMotion`

- **Absolute-positioned widgets in a Stack** — use `AnimatedPositioned` instead.
- **Just fading in/out** — use `AnimatedOpacity` or `AnimatedSwitcher`.
- **Route transitions** — use Flutter's `Hero` widget.
- **Reordering a `ReorderableListView`** — it has its own drag-reorder
  animation. Wrapping items in `LayoutMotion` would fight it.
