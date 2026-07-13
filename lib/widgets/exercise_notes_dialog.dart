// Shared editor for an exercise's PERSISTENT notes (machine settings, form cues...).
//
// These notes live on the exercise INSTANCE (Exercise.notes) and are saved to the
// DB by Profile.updateExerciseNotes, so they persist across sessions and relaunches.
//
// This used to be a private dialog inside workout_page.dart, reachable only from
// the in-workout history panel. It's shared now so the program page can open the
// same editor while building a program (#11).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firstapp/providers_and_settings/program_provider.dart';

Future<void> showExerciseNotesDialog(
  BuildContext context, {
  required ThemeData theme,
  required int primaryIndex,
  required int index,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) {
      final profile = dialogContext.read<Profile>();
      final exercise = profile.exercises[primaryIndex][index];
      final persistentNotesTEC = TextEditingController(text: exercise.notes);

      return AlertDialog(
        title: Text(
          "Enter notes for ${exercise.exerciseTitle} for this program",
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: persistentNotesTEC,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              selectAllOnFocus: true,
              decoration: const InputDecoration(
                labelText: "Persistent Notes",
                border: OutlineInputBorder(),
                hintText: "Machine settings, form cues, reminders...",
              ),
              autofocus: true,
              onSubmitted: (value) {
                profile.updateExerciseNotes(primaryIndex, index, value);
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 45,
            width: 72,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ButtonStyle(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    side: BorderSide(
                      width: 2,
                      color: theme.colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                overlayColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(WidgetState.pressed)) {
                      return theme.colorScheme.primary;
                    }
                    return null;
                  },
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ),

          SizedBox(
            width: 72,
            height: 45,
            child: TextButton(
              onPressed: () {
                profile.updateExerciseNotes(
                  primaryIndex,
                  index,
                  persistentNotesTEC.text,
                );
                Navigator.pop(dialogContext);
              },
              style: ButtonStyle(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                backgroundColor: WidgetStateProperty.all(
                  theme.colorScheme.primary,
                ),
                overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return theme.colorScheme.primary;
                  }
                  return null;
                }),
              ),
              child: Text(
                "Save",
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      );
    },
  );
}
