// app_message.dart
//
// One entry point for short transient messages, so mid-workout ones stay off
// the bottom of the screen.
//
// A SnackBar during a workout is genuinely annoying on iOS: it lands on the
// home indicator, and swiping it away triggers the system nav gesture instead
// of dismissing it. While a workout is active the message is shown as a tap-to-
// dismiss banner at the top instead; everywhere else it stays a normal SnackBar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/widgets/top_overlay.dart';

/// Shows [message] using whichever presentation suits the current screen.
void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
}) {
  if (_workoutIsActive(context)) {
    TopOverlay.show(
      context,
      visibleFor: duration,
      child: _MessageCard(message: message, isError: isError),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      backgroundColor: isError ? Colors.red : null,
    ),
  );
}

bool _workoutIsActive(BuildContext context) {
  // Not every screen that calls this sits under the provider (dialogs pushed
  // with a root navigator, for one), so a missing provider just means "no
  // workout" rather than a crash.
  try {
    return context.read<ActiveWorkoutProvider>().sessionID != null;
  } catch (_) {
    return false;
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background =
        isError ? theme.colorScheme.error : theme.colorScheme.inverseSurface;
    final Color foreground =
        isError ? theme.colorScheme.onError : theme.colorScheme.onInverseSurface;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14, color: foreground),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close, size: 16, color: foreground.withAlpha(180)),
          ],
        ),
      ),
    );
  }
}
