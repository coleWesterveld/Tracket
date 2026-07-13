// Displays A list of sets for an exercise under the program page

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';                                  // Haptics

import 'package:flutter_slidable/flutter_slidable.dart';                 // Swipe To Delete
import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details
import 'package:firstapp/providers_and_settings/settings_provider.dart'; // Access to Settings

import 'package:firstapp/widgets/display_set.dart';

// TODO: add sets here too, centre text boxes, add notes option on dropdown
// TODO: fix bug when user navigates away from program page and presses undo

class ListSets extends StatefulWidget {
  const ListSets({
    super.key,
    required this.context,
    required this.index,
    required this.exerciseIndex,
    required this.theme,
  });

  final BuildContext context;
  final int index;
  final int exerciseIndex;
  final ThemeData theme;

  @override
  State<ListSets> createState() => _ListSetsState();
}

class _ListSetsState extends State<ListSets> {
  @override
  Widget build(BuildContext context) {

    return ReorderableListView.builder(

      //on reorder, update widget with new ordering
      onReorder: (oldIndex, newIndex){
        if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
        
        setState(() {
          context.read<Profile>().moveSet(oldIndex: oldIndex, newIndex: newIndex, dayIndex: widget.index, exerciseIndex: widget.exerciseIndex);
        });
      },

      physics: const NeverScrollableScrollPhysics(),
      itemCount: context.read<Profile>().sets[widget.index][widget.exerciseIndex].length,
      shrinkWrap: true,

      // Displaying list of sets for that exercise
      itemBuilder: (context, setIndex) {
        // Slide to delete
        return Slidable(
          closeOnScroll: true,
          direction: Axis.horizontal,

          key: ValueKey(context.watch<Profile>().sets[widget.index][widget.exerciseIndex][setIndex]),
          endActionPane: ActionPane(
            extentRatio: 0.3,
            motion: const ScrollMotion(), 
            children: [SlidableAction(
              
              backgroundColor: widget.theme.colorScheme.error,
              foregroundColor: widget.theme.colorScheme.onError,
              icon: Icons.delete,
              onPressed: (direction) {
                if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();

                // Delete and save for potential of undo
                final deletedSet = context.read<Profile>().sets[widget.index][widget.exerciseIndex][setIndex];
                setState(() {
                  context.read<Profile>().setsPop(index1: widget.index, index2: widget.exerciseIndex, index3: setIndex);
                });

                // Dipslay snackbar with undo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      style: TextStyle(
                        color: Colors.white
                      ),
                      'Set Deleted'
                      ),
                      action: SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.white,
                      onPressed: () {
                        try{

                        setState(() {
                          context.read<Profile>().setsInsert(
                            index1: widget.index, 
                            index2: widget.exerciseIndex,
                            index3: setIndex,
                            data: deletedSet, 
                          );
                        });
                        } catch(e){
                          //debugPrint('Undo failed: $e');
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to undo deletion :(')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
          ),
        ],
      ),
          // Actual information about the sets
          child: DisplaySet(
            index: widget.index, 
            exerciseIndex: widget.exerciseIndex, 
            setIndex: setIndex,
            theme: widget.theme,
          ),
        );
      },
    );
  }
}
