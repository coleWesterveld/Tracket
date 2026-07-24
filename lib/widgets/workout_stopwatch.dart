import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/widgets/shake_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../workout_page/workout_page.dart';
import '../providers_and_settings/settings_provider.dart';




class WorkoutControlBar extends StatelessWidget {
  final bool positionAtTop;

  // final Color backgroundColor;
  // final Color primaryColor;

  final ThemeData theme;

  const WorkoutControlBar({
    super.key,
    this.positionAtTop = false,
    // this.backgroundColor = const Color(0xFF1e2025),
    //this.primaryColor = const Color(0XFF1A78EB),
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveWorkoutProvider>(
      builder: (context, activeWorkout, child) {
        // Safety check: if activeDay is null, don't render the control bar
        if (activeWorkout.activeDay == null || activeWorkout.sessionID == null) {
          return const SizedBox.shrink();
        }
        
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: positionAtTop 
                  ? BorderSide.none 
                  : BorderSide(color: theme.colorScheme.outline, width: 0.5),
              bottom: positionAtTop 
                  ? BorderSide(color: theme.colorScheme.outline, width: 0.5)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Timers Column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Workout: ${_formatDuration(activeWorkout.workoutTime)}",
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Rest: ${_formatDuration(activeWorkout.restTime, isrest:true)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Control Buttons
              Row(
                children: [
                  // Pause/Play Button
                  IconButton(
                    icon: Icon(
                      activeWorkout.isPaused ? Icons.play_arrow : Icons.pause,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    onPressed: activeWorkout.togglePause,
                  ),
                  const SizedBox(width: 8),
                  
                  // Resume Button (only shown in bottom bar)
                  if (!positionAtTop) ...[
                    ElevatedButton(
                      onPressed: () async {
                        if (context.read<ActiveWorkoutProvider>().isPaused) context.read<ActiveWorkoutProvider>().togglePause();
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Workout(theme: theme),
                          ),
                        );
                        
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      ),
                      child: const Text("Resume"),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Cancel / discard button — hard-deletes everything logged this
                  // session. Only offered from the workout page itself (top bar),
                  // so it can't be hit by accident from the mini bar (#13).
                  if (positionAtTop) ...[
                    TextButton(
                      onPressed: () async {
                        if (context.read<SettingsModel>().hapticsEnabled) {
                          HapticFeedback.heavyImpact();
                        }

                        final bool? discard = await _confirmDiscard(context);
                        if (discard != true || !context.mounted) return;

                        await context.read<ActiveWorkoutProvider>().cancelActiveWorkout();

                        // Back out to the workout selection page
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Finish Button
                  ShakeWidget(
                    shake: context.watch<ActiveWorkoutProvider>().shakeFinish,
                    child: OutlinedButton(
                      onPressed: () async {
                        if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                        activeWorkout.workoutStartTime = null;
                        activeWorkout.lastRestStartTime = null;
                        activeWorkout.timer?.cancel();
                        
                        if(positionAtTop) Navigator.pop(context, true);
                        
                        context.read<ActiveWorkoutProvider>().setActiveDayAndStartNew(null);
                      
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        "Finish",
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Confirms a hard discard. The copy deliberately points the user at "Finish"
  /// as the way to KEEP a half-done workout, since that logs what they did.
  Future<bool?> _confirmDiscard(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Discard this workout?"),
        content: const Text(
          "Everything you logged this session will be deleted and can't be "
          "recovered.\n\nIf you want to keep it, tap Finish instead. A half-done "
          "workout still logs.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              "Keep Workout",
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              "Discard",
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration, {bool? isrest}) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes;
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (isrest == true){
        minutes = twoDigits(duration.inMinutes.remainder(60));

    } else{
        minutes = twoDigits(duration.inMinutes.remainder(60));

    }
    
    // hmm cant decide if I like keeping it this way or not
    // I think its good?
    // it only displays hours when it needs to 
    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }
}
