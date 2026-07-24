// top_overlay.dart
//
// Drops a widget in from the top of the screen, holds it there, then fades it
// back out. This exists because the bottom of the screen is a bad place for
// transient messages on iOS: a SnackBar sits right on the home indicator, so
// swiping it away triggers the system home/back gesture instead of dismissing
// the message. Anything that would have been a SnackBar mid-workout comes
// through here instead.
//
// Only one overlay is visible at a time - showing a new one replaces the old.

import 'dart:async';
import 'package:flutter/material.dart';

class TopOverlay {
  static _TopOverlayHandle? _current;

  /// Shows [child] at the top of the screen for [visibleFor], then fades out.
  static void show(
    BuildContext context, {
    required Widget child,
    Duration visibleFor = const Duration(milliseconds: 2400),
  }) {
    dismiss();

    final overlay = Overlay.of(context);

    late final _TopOverlayHandle handle;
    final entry = OverlayEntry(
      builder: (ctx) => _TopOverlayShell(
        visibleFor: visibleFor,
        onFinished: () => handle.remove(),
        child: child,
      ),
    );

    handle = _TopOverlayHandle(entry);
    _current = handle;
    overlay.insert(entry);
  }

  /// Removes whatever is currently showing, if anything.
  static void dismiss() => _current?.remove();
}

/// Tracks one inserted entry so it is only ever removed once - removing an
/// OverlayEntry twice throws.
class _TopOverlayHandle {
  _TopOverlayHandle(this.entry);

  final OverlayEntry entry;
  bool _removed = false;

  void remove() {
    if (_removed) return;
    _removed = true;
    if (TopOverlay._current == this) TopOverlay._current = null;
    // The overlay itself can go away first (leaving the workout while the
    // banner is still up), and removing an unmounted entry throws.
    if (entry.mounted) entry.remove();
  }
}

// ─── Slide + fade wrapper ───────────────────────────────────────────────────

class _TopOverlayShell extends StatefulWidget {
  final Widget child;
  final Duration visibleFor;
  final VoidCallback onFinished;

  const _TopOverlayShell({
    required this.child,
    required this.visibleFor,
    required this.onFinished,
  });

  @override
  State<_TopOverlayShell> createState() => _TopOverlayShellState();
}

class _TopOverlayShellState extends State<_TopOverlayShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
    _holdTimer = Timer(widget.visibleFor, _fadeOut);
  }

  void _fadeOut() {
    _holdTimer?.cancel();
    if (!mounted) {
      widget.onFinished();
      return;
    }
    _ctrl.reverse().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          // Tapping anywhere on it dismisses early - no swipe needed, so the
          // iOS edge gestures never come into it.
          child: GestureDetector(
            onTap: _fadeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
