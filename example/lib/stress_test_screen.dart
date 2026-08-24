import 'dart:async';
import 'dart:math' as math;

import 'package:flip_layout/flip_layout.dart';
import 'package:flutter/material.dart';

import 'stress/frame_stats.dart';

/// A "harsh" performance harness for flip_layout that end users can run
/// themselves.
///
/// It drives a single [MotionGroup] with up to 300 keyed children (well past
/// the 150-child soft warning — deliberately, to find where reflow gets
/// expensive) and churns it: periodic reorders trigger a full FLIP slide of
/// every surviving child at once, optionally on velocity-preserving springs,
/// while [FrameStatsPanel] reports FPS / build / raster / jank.
class StressTestScreen extends StatefulWidget {
  const StressTestScreen({super.key});

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  final FrameStatsController _stats = FrameStatsController();
  final math.Random _rng = math.Random(42);

  double _count = 60;
  bool _autoShuffle = true;
  bool _useSpring = true;
  bool _addRemove = false;
  Timer? _churn;

  List<int> _order = List<int>.generate(60, (i) => i);
  int _nextId = 60;

  @override
  void initState() {
    super.initState();
    _stats.start();
    _startChurn();
  }

  @override
  void dispose() {
    _stats.stop();
    _churn?.cancel();
    super.dispose();
  }

  void _resize(int n) {
    if (n == _order.length) return;
    if (n < _order.length) {
      _order = _order.sublist(0, n);
    } else {
      _order = [..._order, for (var i = _order.length; i < n; i++) _nextId++];
    }
  }

  void _startChurn() {
    _churn?.cancel();
    if (!_autoShuffle) return;
    _churn = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() {
        if (_addRemove && _order.length > 6) {
          // Evict a few and admit a few → simultaneous enter + exit + reflow.
          _order.removeAt(_rng.nextInt(_order.length));
          _order.removeAt(_rng.nextInt(_order.length));
          _order
            ..add(_nextId++)
            ..add(_nextId++);
        }
        _order.shuffle(_rng);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _count.round();
    return Scaffold(
      appBar: AppBar(title: const Text('Stress test')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FrameStatsPanel(controller: _stats),
          ),
          _controls(context, n),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: MotionGroup(
                duration: const Duration(milliseconds: 320),
                spring: _useSpring
                    ? const MotionSpring(stiffness: 220, damping: 16)
                    : null,
                children: [
                  for (final id in _order) _Bubble(key: ValueKey(id), id: id),
                ],
                builder: (context, children) =>
                    Wrap(spacing: 6, runSpacing: 6, children: children),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _autoShuffle
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _order.shuffle(_rng)),
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
    );
  }

  Widget _controls(BuildContext context, int n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Elements'),
              Expanded(
                child: Slider(
                  value: _count,
                  min: 0,
                  max: 300,
                  divisions: 30,
                  label: '$n',
                  onChanged: (v) => setState(() {
                    _count = v;
                    _resize(v.round());
                  }),
                ),
              ),
              SizedBox(width: 44, child: Text('$n', textAlign: TextAlign.end)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Auto-shuffle'),
                  subtitle: const Text('reflow every 0.7s'),
                  value: _autoShuffle,
                  onChanged: (v) => setState(() {
                    _autoShuffle = v;
                    _startChurn();
                  }),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Spring'),
                  subtitle: const Text('vs eased curve'),
                  value: _useSpring,
                  onChanged: (v) => setState(() => _useSpring = v),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Add / remove churn'),
            subtitle: const Text('enter + exit + reflow together'),
            value: _addRemove,
            onChanged: (v) => setState(() => _addRemove = v),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final hue = (id * 47) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.62).toColor();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$id',
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}
