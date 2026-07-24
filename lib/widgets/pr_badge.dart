// pr_badge.dart
//
// Overlay banner shown briefly when a logged set is a personal record.
// Usage:
//   PRBannerOverlay.show(context, exerciseName: 'Bench Press', weight: '225', unit: 'lbs');

import 'dart:async';
import 'package:flutter/material.dart';

class PRBannerOverlay {
  static OverlayEntry? _current;
  static Timer? _timer;

  /// Shows the PR banner for [durationMs] milliseconds, then fades it out.
  static void show(
    BuildContext context, {
    required String exerciseName,
    required String weight,
    required String unit,
    int durationMs = 2800,
  }) {
    // Dismiss any existing banner first
    _dismiss();

    final overlay = Overlay.of(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _PRBannerWidget(
        exerciseName: exerciseName,
        weight: weight,
        unit: unit,
        onDismiss: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(Duration(milliseconds: durationMs), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

// ─── Internal animated widget ───────────────────────────────────────────────

class _PRBannerWidget extends StatefulWidget {
  final String exerciseName;
  final String weight;
  final String unit;
  final VoidCallback onDismiss;

  const _PRBannerWidget({
    required this.exerciseName,
    required this.weight,
    required this.unit,
    required this.onDismiss,
  });

  @override
  State<_PRBannerWidget> createState() => _PRBannerWidgetState();
}

class _PRBannerWidgetState extends State<_PRBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF4A3000), const Color(0xFF7A5200)]
                      : [const Color(0xFFFFF3CD), const Color(0xFFFFE082)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFB300),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Trophy icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '🏆',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Record!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A5200),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.weight} ${widget.unit} on ${widget.exerciseName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A5200),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Dismiss button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF7A5200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
