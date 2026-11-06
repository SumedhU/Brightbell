import 'package:flutter/material.dart';

/// Shows the child at [index], fading and sliding between children when it
/// changes.
///
/// Children in [keepAlive] keep their state while hidden. The others are only
/// built while visible, so they start fresh on each visit.
class AnimatedTabs extends StatefulWidget {
  static const Duration duration = Duration(milliseconds: 300);

  final int index;
  final Set<int> keepAlive;
  final List<Widget> children;

  const AnimatedTabs({
    super.key,
    required this.index,
    required this.children,
    this.keepAlive = const {},
  });

  @override
  State<AnimatedTabs> createState() => _AnimatedTabsState();
}

class _AnimatedTabsState extends State<AnimatedTabs> {
  // How far a tab drifts, as a fraction of its width.
  static const double _slideDistance = 0.04;

  // The old tab clears before the new one appears, so the two never overlap
  // at half opacity.
  static const Curve _fadeOutCurve = Interval(0, 0.35, curve: Curves.easeOut);
  static const Curve _fadeInCurve = Interval(0.35, 1, curve: Curves.easeOut);

  late final Set<int> _builtTabs = {...widget.keepAlive, widget.index};

  @override
  void didUpdateWidget(AnimatedTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _builtTabs.add(widget.index);
  }

  void _onFadeEnd(int tab) {
    if (widget.keepAlive.contains(tab)) return;
    // With animations disabled the fade ends during build, too early to
    // call setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tab != widget.index) {
        setState(() => _builtTabs.remove(tab));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AnimatedTabs.duration;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var tab = 0; tab < widget.children.length; tab++)
          IgnorePointer(
            ignoring: tab != widget.index,
            // These wrappers stay mounted even for unbuilt tabs: an implicit
            // animation only runs when its target changes after mounting.
            child: AnimatedSlide(
              // Tabs wait on the side they sit on relative to the current one.
              offset: Offset((tab - widget.index).sign * _slideDistance, 0),
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: tab == widget.index ? 1 : 0,
                duration: duration,
                curve: tab == widget.index ? _fadeInCurve : _fadeOutCurve,
                onEnd: () => _onFadeEnd(tab),
                child: _builtTabs.contains(tab)
                    ? widget.children[tab]
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}
