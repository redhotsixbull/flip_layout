# Architecture

## The FLIP technique in one paragraph

You want a widget to appear to slide smoothly when its layout changes. But
Flutter's layout is imperative and one-shot: the framework computes the new
position and paints it there. To animate the transition, you need to:

1. **F**irst — remember where the widget was before the layout change.
2. **L**ast — measure where the widget is *after* the layout change.
3. **I**nvert — apply a `Transform.translate` equal to `previous - current`.
   The widget is now sitting at its new position but visually appears at the old one.
4. **P**lay — animate that translation to `Offset.zero` over time.

The trick is entirely visual — the layout position is already correct from
frame one. This makes FLIP scale to complex layouts (Wrap, Grid, custom
layouts) that would be a nightmare to animate imperatively.

## Data flow

```
┌────────────────────────────────────────┐
│  LayoutMotion.build                    │
│    - render child (already at "Last") │
│    - schedule post-frame measurement   │
│    - AnimatedBuilder wraps in           │
│      Transform.translate(fromOffset)   │
└──────────────┬─────────────────────────┘
               │ SchedulerBinding.addPostFrameCallback
               ▼
┌────────────────────────────────────────┐
│  _scheduleMeasurement                  │
│    current = boxKey.RenderBox bounds   │
│    if (previous != null && diff)       │
│      fromOffset = previous - current   │
│      controller.forward(from: 0)       │
│    previous = current                   │
└────────────────────────────────────────┘
```

## Why post-frame, not `didUpdateWidget`

`didUpdateWidget` runs when the widget config changes, but not when the
*layout* changes due to ancestor changes (e.g., a sibling being added).
Post-frame callbacks fire after every frame regardless of why the layout
changed, so we catch all reflow events.

The cost is one measurement per frame per `LayoutMotion` instance. For
large lists this could add up, but a `RenderBox.localToGlobal + size` read
is cheap (no layout re-run). If profiling shows it matters, we can move to
a `RenderObject` subclass that hooks into paint directly (planned for v0.2).

## Why `Transform.translate`, not `Positioned`

Two reasons:
1. **Non-Stack parents**: `LayoutMotion` should work inside a `Column`, `Wrap`,
   `Grid`, or any custom layout — `Positioned` requires a `Stack`.
2. **No layout impact**: `Transform.translate` shifts painting only, not
   layout. The parent's layout stays computed at the child's real position,
   so surrounding widgets don't move mid-animation.

## `AnimatedLayout` convenience wrapper

Instead of manually wrapping every child in `LayoutMotion`, you get a
`wrap(child)` helper:

```dart
AnimatedLayout(
  builder: (context, wrap) => Column(
    children: items.map((i) => wrap(Card(key: ValueKey(i), ...))).toList(),
  ),
);
```

Under the hood `wrap` returns `LayoutMotion(key: child.key, child: child)`.
The **stable key on each child is essential** — Flutter uses it to preserve
element identity across rebuilds. Without it, `LayoutMotion`'s state
(`_previousBounds`) resets on every rebuild and animation doesn't play.

## `animateSize` — the caveat

Setting `animateSize: true` scales the child via `Transform` when the size
changes. This produces the size animation but *distorts* the child's
rendering (text stretches, images blur). We keep it off by default because
`AnimatedContainer` / `AnimatedCrossFade` are usually better for actual
size changes. FLIP is at its best for **position** animation.

## Beyond `LayoutMotion` (0.1.0)

- **`MotionGroup`** — enter/exit (an `AnimatePresence` equivalent) + layout.
  Rather than needing an `Element` subclass, it keeps a per-child state ("slot")
  with an `AnimationController`: entering children run forward; a removed child
  is kept mounted and run in reverse, then removed on `dismissed`; survivors are
  wrapped in `LayoutMotion` so they FLIP into place. Exit transitions are
  paint-only, so the layout reflows in one discrete step (no jitter).
- **`MotionSharedScope` / `MotionSharedId`** — within-page shared elements. A
  per-scope controller tracks each id's holders and global rect; on a genuine
  hand-off (a *different*, newer element takes the id) it flies an overlay copy
  from the old rect to the new one and hides the non-active holder. The active
  holder is chosen by **birth order**, not registration order, so lazy slivers
  (which build during layout) don't confuse it. The overlay carries the
  destination child by default; `crossFade: true` dissolves source→destination,
  and `flightShuttleBuilder` replaces the in-flight widget entirely (both ends
  are passed in) — see below.

### The birth-order heuristic and its limits

When more than one `MotionSharedId` claims the same id at once (source tile +
detail card, both mounted), the controller must decide which one is the "active"
(front) holder — the one that owns the id, stays visible, and is the flight's
destination. It picks the holder with the **highest birth sequence** (the most
recently created `State`), because:

- **Registration order is unreliable.** A lazy `GridView`/sliver builds its
  tiles *during layout*, which happens *after* an overlaid detail has already
  built in the same frame. "Last registered this frame" would wrongly pick a
  re-scrolled tile over the detail. Birth order (assigned once, when the `State`
  is first created) is stable against per-frame re-registration.

This is a **heuristic**, and it can mispick in exotic cases:

- **Three-plus simultaneous holders** — with A, B and C all live, "newest wins"
  makes C active even if the *intended* front element is B. The single-source →
  single-destination hand-off (the common grid→detail case) is unambiguous; keep
  to two live holders per id when you can.
- **Same-frame births with equal sequence** — two holders created in the very
  same microtask get consecutive sequences, so the tie breaks by build order,
  which is usually but not always what you want.
- **Reparented (not rebuilt) holders** — a holder moved via a `GlobalKey`
  without its `State` being recreated keeps its *original* birth sequence, so a
  freshly-built sibling can out-rank it.

If you hit an ambiguous case, prefer conditionally mounting exactly one holder
per id, or drive the hand-off with an explicit route (`Hero`). The unit tests
pin the common cases (single hand-off, recycle-after-absence, three-holder
birth-order pick); the exotic multi-holder flights are only visually verified.
- **`SpringCurve`** — a `SpringSimulation` sampled onto `t ∈ [0,1]`, so springy
  motion works through the existing curve path (no controller rework).

## Two spring paths: `SpringCurve` vs `MotionSpring` (0.2.0)

There are now two ways to get spring motion, and they sit at different layers:

- **`SpringCurve` is a `Curve`.** It pre-samples a `SpringSimulation` and
  normalises the settle time onto `t ∈ [0, 1]`. It plugs into the *existing*
  fixed-duration controller wherever a curve is accepted. Cheap and simple, but
  because it's just a reshaped `t`, an interruption restarts the ease from rest —
  there is no momentum. Good for one-shot springy slides.
- **`MotionSpring` is live physics.** `LayoutMotion` runs the FLIP inverse offset
  on **two unbounded `AnimationController`s** (one per axis), each driven by
  `controller.animateWith(SpringSimulation(...))`. There is no fixed duration —
  it runs until the physics settle. On a re-target we read the controller's
  current `value` (offset) and `velocity` and seed the *new* `SpringSimulation`
  with them, so momentum is carried across the interruption. The two controllers
  are created lazily the first time a spring runs (the common curve path pays
  nothing), and `onEnd` fires when *both* axes settle. A key subtlety: the
  controllers must exist *before* the `AnimatedBuilder` builds, or a spring
  started later in a post-frame callback would tick without repainting — so they
  are created in `build()` as soon as a spring is in effect, not on first use in
  the measurement callback.

Only **position** springs; a `animateSize` scale still rides the curve
controller (size distortion is a visual-only effect either way).

## `MotionGroup` lifecycle + exit stagger (0.2.0)

Each per-child slot already owns an `AnimationController`. `onEnter(key)` fires
from that controller's status listener when it reaches `completed` for a *real*
enter (a `notifyEnter` flag guards against firing when a child is placed
instantly via `value = 1`, which also emits a `completed` status).
`onExitComplete(key)` fires when it reaches `dismissed` while exiting, just
before the slot is removed. `exitStagger` delays each successive leaver's
`reverse()` via a `Future.delayed` (delay-zero leavers reverse synchronously so
the first one doesn't lag a frame); a leaver stays fully visible until its turn,
and a revive (re-add mid-exit) cancels the pending reverse.

## Still not done

- **Cross-*route* shared elements** — today's shared elements are within-page;
  route-to-route hand-off is Flutter `Hero`'s job.
- **Virtualisation** — `MotionGroup` manages all children at once (a debug
  warning fires past `debugChildCountWarningThreshold`); a windowed
  `SliverMotionGroup` is future work.
- **Non-distorting `animateSize`** — still `Transform.scale` (stretches); a
  clip/align-based option is future work.
