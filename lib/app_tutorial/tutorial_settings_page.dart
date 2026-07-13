import 'package:firstapp/program_page/program_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../providers_and_settings/settings_provider.dart';
import '../main.dart'; // To navigate to MainScaffold
import 'app_tutorial_keys.dart';
// Import the manager
import 'package:firstapp/workout_page/workout_selection_page.dart';
import 'package:firstapp/notifications/notification_service.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';

class TutorialSettingsPage extends StatelessWidget {
  
  final GlobalKey<MainScaffoldState> mainScaffoldKey;
  final GlobalKey<WorkoutSelectionPageState> workoutPageKey;
  final GlobalKey<ProgramPageState> programPageKey;
  
  const TutorialSettingsPage({
    super.key,
    required this.mainScaffoldKey,
    required this.programPageKey,
    required this.workoutPageKey,
  });


  @override
  Widget build(BuildContext context) {
    // Access SettingsModel if you want to show initial settings here
    final settings = Provider.of<SettingsModel>(context);
    ////debugPrint("settings: ${settings.themeMode}");
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings")
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  "Set up your initial preferences (optional):",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )
                ),
          
                subtitle: Text("You will be able to change these later in settings.")
              ),
              const SizedBox(height: 20),
              Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Theme'),
                trailing: DropdownButton<String>(
                  value: settings.themeMode,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settings.changeTheme(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'dark',
                      child: Text("Dark"),
                    ),
                    DropdownMenuItem(
                      value: 'system',
                      child: Text("System"),
                    ),
                    DropdownMenuItem(
                      value: 'light',
                      child: Text("Light"),
                    )
                  ]
                ),
              ),
          
              const Divider(
                thickness: 0.5,
              ),
              
          
              // Units (kg/lbs)
              ListTile(
                title: const Text('Measurement Units'),
                trailing: DropdownButton<bool>(
                  value: settings.useMetric,
                  onChanged: (bool? newValue) {
                    if (newValue != null && newValue != settings.useMetric) {
                      settings.toggleUnits();
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text("Pounds/Imperial (lb)"),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text("Kilograms/Metric (kg)"),
                    )
                  ]
                ),
              ),
          
              const Divider(
                thickness: 0.5,
              ),        
              // Dark Theme
              
          
              // // Sounds - Theres currently no sounds in the app
              // ListTile(
              //   title: const Text('Enable Sounds'),
              //   trailing: Switch.adaptive(
              //     value: settings.soundsEnabled,
              //     onChanged: (_) => settings.toggleSounds(),
              //   ),
              // ),
          
              // const Divider(
              //   thickness: 0.5,
              // ),
          
              // Haptics
              ListTile(
                title: const Text('Enable Haptic Feedback'),
                trailing: Switch.adaptive(
                  activeTrackColor: theme.colorScheme.primary,
                  value: settings.hapticsEnabled,
                  onChanged: (_) => settings.toggleHaptics(),
                ),
              ),
              const Divider(
                thickness: 0.5,
              ),
          
              ListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text("Get notified of upcoming workout and to bring equipment such as a belt or straps"),
                trailing: Switch.adaptive(
                  activeTrackColor: theme.colorScheme.primary,
                  value: settings.notificationsEnabled,
                  onChanged: (isEnabled) {
                    settings.toggleNotifications(context);
          
                    final notiService = NotiService();
                    if (isEnabled){
                      notiService.scheduleWorkoutNotifications(
                        profile: context.read<Profile>(),
                        settings: context.read<SettingsModel>(),
                      );
                    } else{
                      notiService.cancelAllNotifications();
                    }
                    
                  },
                ),
              ),
          
              if (settings.notificationsEnabled) 
                ListTile(
                  //minLeadingWidth: 12,
                  //leading: const SizedBox.shrink(),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    //mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Notify "),
                      const SizedBox(width: 12),
          
                      DropdownButton<int>(
                        value: settings.timeReminder,
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            settings.setTimeReminder(newValue, context);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 15,
                            child: Text("15 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text("30 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 45,
                            child: Text("45 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text("1 Hr"),
                          ),
                          DropdownMenuItem(
                            value: 75,
                            child: Text("1 Hr 15 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text("1 Hr 30 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 105,
                            child: Text("1 Hr 45 Mins"),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text("2 Hr"),
                          ),
                          DropdownMenuItem(
                            value: 180,
                            child: Text("3 Hr"),
                          ),
          
                        ]
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Before a Workout",
                      )
                    ]
                  ),
                ),
                const Divider(
                thickness: 0.5,
              ),
          
              // ListTile(
              //   title: const Text('Color Blind Mode'),
              //   subtitle: const Text('Adds shapes to color-coded elements'),
              //   trailing: Switch.adaptive(
              //     value: settings.colorBlindMode,
              //     onChanged: (_) => settings.toggleColorBlindMode(),
              //   ),
              // ),
              
            ],
          ),
                ),
                
              //const Spacer(), // Pushes button to the bottom
              const SizedBox(height: 20),
                
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                        key: AppTutorialKeys.tutorialStartButton,
                        onPressed: () {
                          // Navigate into tutorial as the ONLY route to avoid duplicate trees
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              settings: const RouteSettings(arguments: {'startTutorial': true}),
                              builder: (context) => MainScaffoldWrapper(
                                mainScaffoldKey: mainScaffoldKey,
                                workoutPageKey: workoutPageKey,
                                programPageKey: programPageKey,
                              ),
                            ),
                            (route) => false,
                          );
                              
                                        // REMOVED: Do NOT try to start the tutorial from this context
                                        // WidgetsBinding.instance.addPostFrameCallback((_) {
                                        //    Provider.of<TutorialManager>(context, listen: false) // << ERROR HAPPENS HERE
                                        //        .startTutorialSequence(context);
                                        //  });
                                      },
                                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                        side: BorderSide(
                          color: theme.colorScheme.primary,
                          width:2
                        )
                                        ),
                        child: const Text('Start App Tutorial'),
          
                                    ),
                      ),
                    ),
              const SizedBox(height: 20), // Spacing at the bottom
            ],
          ),
        ),
      ),
    );
    
  }
}

// Helper Wrapper to provide TutorialManager
class MainScaffoldWrapper extends StatelessWidget {
  final GlobalKey<MainScaffoldState> mainScaffoldKey;
  final GlobalKey<WorkoutSelectionPageState> workoutPageKey; // Key to access workout page state
  final GlobalKey<ProgramPageState> programPageKey; // Key to access workout page state

  const MainScaffoldWrapper({
    super.key,
    required this.mainScaffoldKey,
    required this.workoutPageKey, // Key to access workout page state
    required this.programPageKey, // Key to access workout page state
  });

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      //autoPlay: true,
      

      // pretty long - I expect people to press skip or next, but if they dont this will move them along
      //ZRautoPlayDelay: Duration(seconds: 10),

      disableBarrierInteraction: true,
      builder: (_) =>Builder( // Use Builder here to get a context descendant of ShowCaseWidget
        builder: (showcaseContext) { // Use this context for ShowCaseWidget.of()
           return MainScaffold(
             key: mainScaffoldKey,
             workoutPageKey: workoutPageKey,
             programPageKey: programPageKey,
             showcaseContext: showcaseContext, // Pass the showcase context
           );
        },
      ),
      //enableAutoPlayLock: true,
      
      onFinish: () {
         try {
           Provider.of<SettingsModel>(context, listen: false).completeTutorial();
           // Ensure only the main app tree remains
           WidgetsBinding.instance.addPostFrameCallback((_) {
             Navigator.of(context).popUntil((route) => route.isFirst);
           });
         } catch (e) {
           print("Error finalizing tutorial: $e");
         }
       },
    );
  }
}