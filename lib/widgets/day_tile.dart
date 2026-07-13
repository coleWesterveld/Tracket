// A single day in the program page

import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';
import 'package:firstapp/app_tutorial/tutorial_manager.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details

import 'package:firstapp/widgets/list_exercises.dart';
import 'package:firstapp/widgets/popup_day_editor.dart';
import 'package:showcaseview/showcaseview.dart';

class DayTile extends StatefulWidget {
  const DayTile({
    super.key,
    required this.context,
    required this.index,
    required this.theme,
    required this.onExerciseAdded,
  });

  final BuildContext context;
  final int index;
  final ThemeData theme;
  final Function (int) onExerciseAdded;

  @override
  State<DayTile> createState() => _DayTileState();
}

class _DayTileState extends State<DayTile> {

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<TutorialManager>();
    final settings = context.watch<SettingsModel>();
    final theme = Theme.of(context);
    //final uiState = context.watch<UiStateProvider>();
    ////debugPrint("${context.read<SettingsModel>().isFirstTime}");
    //final shouldExpand = uiState.expandProgramIndex == widget.index;


    return Container(  
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.theme.colorScheme.outline,
          width: 0.5
        ),

        boxShadow: [
          BoxShadow(
            color: widget.theme.colorScheme.shadow,
            offset: const Offset(2, 2),
            blurRadius: 4.0,
          ),
        ],
        

        color: widget.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
      ),
          
      // Defining the inside of the actual box, display information
      child:  Center(
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            listTileTheme: const ListTileThemeData(
              // Removes extra padding
              horizontalTitleGap: 0,
              contentPadding: EdgeInsets.only(left: 4, right: 16), 
            ),
          ),
                  
          // Expandable to see exercises and sets for that day
          child: ExpansionTile(
            initiallyExpanded: context.read<Profile>().expansionStates[widget.index],
            
            controller: (widget.index == 0 && settings.isFirstTime) ? manager.exerciseDemoExpandController : null,
            

            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)
            ),
            
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)
            ),

            iconColor: widget.theme.colorScheme.primary,
            collapsedIconColor: widget.theme.colorScheme.primary,
            onExpansionChanged: (val){
              context.read<Profile>().expansionStates[widget.index] = val;
              if (!val){
                WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
              }
            },
  
            // Top row always displays day title, and edit button
            // Sized boxes and padding is just a bunch of formatting stuff
            // tbh it could probably be made more concise

            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row( 
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    //width: 50,
                    child: Text(
                      "${widget.index + 1}",
                                            
                      style: TextStyle(
                        height: 0.6,
                        color: widget.theme.colorScheme.onSurface,
                        fontSize: 35,
                        fontWeight: FontWeight.w900,
                      ),
                      ),
                  ),
              
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration:  BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(context.watch<Profile>().split[widget.index].dayColor),
                      ),
                    
                    ),
                  ),
                ]
              ),
            ),
            
            title: 
              SizedBox(
                //color: Colors.red,
                height: context.watch<Profile>().split[widget.index].gear.isNotEmpty ? 43 : 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // I know I could get an equivalent effect with subtitle, but then trailing icon is uncentered
                    // if i make ther trailing icon as the "trailing" then I lose the expansion indicator
                    // so i am doing this
                    if (context.watch<Profile>().split[widget.index].gear.isNotEmpty)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          
                          children: [
                            Text(
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToLastDescent: false,
                                applyHeightToFirstAscent: false,
                              ),
                              overflow: TextOverflow.ellipsis,
                              context.watch<Profile>().split[widget.index].dayTitle,
                              
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        
                            
                            Text(
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToLastDescent: false,
                                applyHeightToFirstAscent: false,
                              ),
                              overflow: TextOverflow.ellipsis,
                              context.watch<Profile>().split[widget.index].gear,
                              
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (context.watch<Profile>().split[widget.index].gear.isEmpty)
                      Expanded(

                        child: Text(
                          textHeightBehavior: const TextHeightBehavior(
                                applyHeightToLastDescent: false,
                                applyHeightToFirstAscent: false,
                              ),
                          overflow: TextOverflow.ellipsis,
                          context.watch<Profile>().split[widget.index].dayTitle,
                          
                          style: TextStyle(
                            color: widget.theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                    // Update title button
                    IconButton(
                      
                      onPressed: () {         
                        showDialog(
                          anchorPoint: const Offset(100, 100),
                          context: context,
                    
                          builder: (BuildContext context) {
                            return StatefulBuilder(
                              builder: (context, StateSetter setState) {
                                return PopUpDayEditor(
                                  theme: widget.theme,
                                  index: widget.index,
                                  titleTEC: TextEditingController(
                                    text: context.watch<Profile>().split[widget.index].dayTitle
                                  ),
                                  equipmentTEC: TextEditingController(
                                    text: context.watch<Profile>().split[widget.index].gear
                                  ),
                    
                                );
                              },
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      color: widget.theme.colorScheme.secondary,
                      
                    ),
                  ],
                ),
              ),

            
                          
            // Reorderable list of exercises for that day which come up upon tap to expanding
            children: [
              Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(12.0),
                    bottomLeft: Radius.circular(12.0)
                  ),
                ),

                child: (widget.index == 0) 
                ? Showcase(
                  disableDefaultTargetGestures: true,
                  key: AppTutorialKeys.addExerciseToProgram, 
                  tooltipBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                  descTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  targetBorderRadius: BorderRadius.circular(12),

                  tooltipActions: [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.skip,
                      onTap: () => manager.skipTutorial(),
                      backgroundColor: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.onSurface
                      ),
                      textStyle: TextStyle(
                        color: theme.colorScheme.onSurface
                      )

                      
                    ),
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      onTap: () => manager.advanceStep(),
                      border: Border.all(
                        color: theme.colorScheme.onSurface
                      ),
                      backgroundColor: theme.colorScheme.surface,
                      textStyle: TextStyle(
                        color: theme.colorScheme.onSurface
                      )
                    )
                  ],
                  description: "Manage exercises for each day. Tap a set to edit it.", 
                  child: ListExercises(

                    context: context, 
                    index: widget.index,
                    theme: widget.theme,

                    onExerciseAdded: (exerciseIndex) async {
                      // continue tunneling back the exerciseindex
                      widget.onExerciseAdded(exerciseIndex);
                    },

                  )
                )
                : ListExercises(

                  context: context, 
                  index: widget.index,
                  theme: widget.theme,

                  onExerciseAdded: (exerciseIndex) async {
                    widget.onExerciseAdded(exerciseIndex);
                  },

                )
              ),
            ]
          ),
        ),
      ),
    );
  }
}
