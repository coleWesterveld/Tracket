import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'package:firstapp/providers_and_settings/snapshot_active_workout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Pages
import 'package:firstapp/workout_page/workout_selection_page.dart';       // Workout Selector
import 'package:firstapp/schedule_page/schedule_page.dart';               // Schedule Page
import 'package:firstapp/program_page/program_page.dart';                 // Program Creator
import 'package:firstapp/analytics_page/analytics_page.dart';             // Analytics Page

// Utilities
import 'package:firstapp/database/database_helper.dart';                  // Database Methods
import 'package:firstapp/widgets/workout_stopwatch.dart';                 // Active Workout Clock
import 'package:firstapp/providers_and_settings/program_provider.dart';   // Program Management
import 'package:firstapp/providers_and_settings/settings_provider.dart';  // Settings
import 'package:firstapp/theme/app_theme.dart';                           // Theme
import 'package:firstapp/notifications/notification_service.dart';        // Notifications
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:showcaseview/showcaseview.dart';        // Splash Screen

import 'package:firstapp/app_tutorial/tutorial_manager.dart'; // Import manager
import 'package:firstapp/app_tutorial/tutorial_welcome_page.dart'; // Import welcome page
// Import workout page state for key
// Import showcase
import 'package:firstapp/app_tutorial/tutorial_settings_page.dart';
import 'package:firstapp/widgets/programs_drawer.dart';
import 'package:firstapp/providers_and_settings/settings_page.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'widgets/calendar_bottom_sheet.dart';


// a lil bit of fun when the user finishes a workout
// maybe in the future I can briung up a modal sheet with workout stats when a workout is done or

// TODO: fix error when user initiaites app walkthrough when viewing an exercises history 
// TODO: add disposes for all focusnodes and TECs and other
/* colour choices:
my goal is to make tappable things blue
editable things orange 
simplify the design, get rid of unnessecary colours so that attention is drawn to whats important
*/



// thing to be aware: exercise class has id and Exercise id, do not confuse them! (this causes most of my bugs)
// this should maybe be fixed and is a bit unclear since a db restructure
// since exercise class itself references an exercise instance, which has an ID to which specific exercise it is an instance of
// id identifies the instance uniquely, exerciseID references the exercise in the big table of all the exercises.
// try with different phone sizes - its mostly reactive I think but I havent done enough testing

// ENTRYPOINT OF APP HERE
void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // assert(() {
  //   //debugPrintGlobalKeyedWidgetLifecycle = true;
  //   return true;
  // }());


  runApp(const GymApp());

}

class GymApp extends StatefulWidget {
  const GymApp({super.key});
  @override
  State<GymApp> createState() => _MainPage();
}

class _MainPage extends State<GymApp>{

  @override
  void initState() {
    super.initState();

    // just wait for 1.5 seconds to let stuff get set up
    // this isnt really scientific or even nessecary, stuff would load asynchronously if this didnt happen
    // I just feel like its nicer to see the logo then see everything ready rather than seeing everything 
    // pop in over about a second -- looks more proper and a 1 time 1 sec wait is not bad. 
    Future.delayed(const Duration(seconds: 1), () {
      FlutterNativeSplash.remove();
    });
  }

  // @override
  // void dispose() {
  //   // If you want to ensure a save if _MainPage itself is disposed while a workout is active.
  //   // However, didChangeAppLifecycleState should cover most app closing scenarios.
  //   // final activeWorkoutP = Provider.of<ActiveWorkoutProvider>(context, listen: false);
  //   // if (activeWorkoutP.sessionID != null) {
  //   //   activeWorkoutP.saveActiveWorkoutState();
  //   // }
  //   super.dispose();
  // }

  final dbHelper = DatabaseHelper.instance;
  final GlobalKey<MainScaffoldState> mainScaffoldKey = LabeledGlobalKey<MainScaffoldState>('mainScaffoldKey');
  final GlobalKey<MainScaffoldState> tutorialMainScaffoldKey = LabeledGlobalKey<MainScaffoldState>('tutorialMainScaffoldKey');
  final GlobalKey<WorkoutSelectionPageState> workoutPageKey = LabeledGlobalKey<WorkoutSelectionPageState>('workoutPageKey');
  final GlobalKey<ProgramPageState> programPageKey = LabeledGlobalKey<ProgramPageState>('programPageKey');
  // Distinct keys for tutorial flow to avoid duplication during route transitions
  final GlobalKey<WorkoutSelectionPageState> tutorialWorkoutPageKey = LabeledGlobalKey<WorkoutSelectionPageState>('tutorialWorkoutPageKey');
  final GlobalKey<ProgramPageState> tutorialProgramPageKey = LabeledGlobalKey<ProgramPageState>('tutorialProgramPageKey');

  @override
  Widget build(BuildContext context) {

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final settings = SettingsModel();
            settings.init(); 
            return settings;
          }
        ),


        ChangeNotifierProvider(
          create: (context) => Profile(
            dbHelper: dbHelper,
          ),
        ),

        ChangeNotifierProvider(
          create: (_) => TutorialManager(),
        ),

        ChangeNotifierProxyProvider<Profile, ActiveWorkoutProvider>(


          create: (context) => ActiveWorkoutProvider(
            dbHelper: dbHelper,
            programProvider: Provider.of<Profile>(context, listen: false),
            workoutNotesTEC: [],
            workoutRepsTEC: [],
            workoutRpeTEC: [],
            workoutWeightTEC: [],
            workoutExpansionControllers: [],
            showHistory: [],
            expansionStates: []
          ),

          update: (context, programProvider, previousActiveWorkoutProvider) {
            if (previousActiveWorkoutProvider?.activeDayIndex != null){
              final programChanged = previousActiveWorkoutProvider!.activeProgramId != null &&
                  previousActiveWorkoutProvider.activeProgramId != programProvider.currentProgram.programID;

              if (programChanged) {
                // Program switched while workout was active — clear the workout
                ////debugPrint("Active workout cleared: program switched");
                previousActiveWorkoutProvider
                ..programProvider = programProvider
                ..setActiveDayAndStartNew(null);
              } else if (previousActiveWorkoutProvider.activeDayIndex! < programProvider.split.length &&
                  previousActiveWorkoutProvider.activeDayIndex! < programProvider.exercises.length &&
                  previousActiveWorkoutProvider.activeDayIndex! < programProvider.sets.length) {
                previousActiveWorkoutProvider
                ..programProvider = programProvider
                ..syncControllersForDay(previousActiveWorkoutProvider.activeDayIndex!);
              } else {
                // Active workout day index is no longer valid
                ////debugPrint("Active workout cleared: day index out of bounds for new program");
                previousActiveWorkoutProvider
                ..programProvider = programProvider
                ..setActiveDayAndStartNew(null);
              }
            }

            return previousActiveWorkoutProvider ?? ActiveWorkoutProvider(
                dbHelper: dbHelper, programProvider: programProvider);
          }
          ),

        ChangeNotifierProvider(create: (_) => UiStateProvider()),


        // ChangeNotifierProvider(
        //   create: (_) => TutorialManager(
        //     mainScaffoldKey: 
        //   )
        // ), // If wrapping higher up
      ],
      child: Consumer<SettingsModel>(
        builder: (context, settings, child) {
          if (!context.watch<Profile>().isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (
            !context.read<UiStateProvider>().hasSetNotifs
            && !settings.isFirstTime
            && context.watch<Profile>().isInitialized
            && context.read<SettingsModel>().notificationsEnabled
          ) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final notiService = NotiService();
              notiService.scheduleWorkoutNotifications(
                profile: context.read<Profile>(),
                settings: context.read<SettingsModel>(),
              );
              context.read<UiStateProvider>().hasSetNotifs = true;
            });
          }

          Widget initialHome;
          if (settings.isFirstTime) {
            initialHome = TutorialWelcomePage(
              mainScaffoldKey: tutorialMainScaffoldKey,
              workoutPageKey: tutorialWorkoutPageKey,
              programPageKey: tutorialProgramPageKey,
            );
          } else {
            // If not first time, wrap MainScaffold in ShowCaseWidget
            // only if you want to allow replaying the tutorial later.
            // Otherwise, just show MainScaffoldWrapper directly.
             initialHome = MainScaffoldWrapper(
              mainScaffoldKey: mainScaffoldKey,
              workoutPageKey: workoutPageKey,
              programPageKey: programPageKey,
             ); // Use the wrapper directly
            // initialHome = ShowCaseWidget(
            //    builder: Builder(builder: (context) => MainScaffoldWrapper()),
            // );
          }

          return MaterialApp(
            //showSemanticsDebugger: true,
            title: 'TempTitle',
            debugShowCheckedModeBanner: false,
            themeMode: _getThemeMode(settings.themeMode),
            darkTheme: AppTheme.darkTheme,
            theme: AppTheme.lightTheme,
            home: initialHome
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String themeMode) {
    switch (themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

class MainScaffold extends StatefulWidget {
  //Function updater;
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final GlobalKey<WorkoutSelectionPageState> workoutPageKey; // Accept the key
  final GlobalKey<ProgramPageState> programPageKey; // Accept the key

  final BuildContext showcaseContext; // Receive the showcase context
  // String? debugtext;

  MainScaffold({
    super.key, 
    required this.workoutPageKey, 
    required this.showcaseContext,
    required this.programPageKey,

  });

  @override
  MainScaffoldState createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold>  with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void didChangeDependencies() {
    
    super.didChangeDependencies();

    _checkAndOpenDrawer();

    // the following logic allows user to redo walkthrough from settings
    final uiState = context.watch<UiStateProvider>(); // Use watch or read as appropriate
    if (uiState.replayTutorialRequested) {
      // Use addPostFrameCallback to ensure the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Ensure the widget is still in the tree
          try {
            // Get the TutorialManager
            final manager = context.read<TutorialManager>();
            // Start the tutorial sequence using the showcaseContext passed to MainScaffold
            manager.startTutorialSequence(widget.showcaseContext);
            // Reset the flag in UiStateProvider
            context.read<UiStateProvider>().consumeTutorialReplayRequest();
          } catch (e) {
            print("Error restarting tutorial: $e");
            // Optionally reset the flag even if there's an error
            context.read<UiStateProvider>().consumeTutorialReplayRequest();
          }
        }
      });
    }

  }

      // App Lifecycle Listener (to save state when app is paused/detached)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Ensure context is valid if this widget can be rebuilt, or use a stored context.
    // For Provider.of with listen:false, it's generally safe if providers are above this in the tree.
    final activeWorkoutP = Provider.of<ActiveWorkoutProvider>(context, listen: false);

    // Only save if there's an active session ID in the provider
    // Note: we dont have enough time to save on detached, so I removed it for now
    // MAYBE if this is more efficient it could work, but it would have to be super fast. 
    if (activeWorkoutP.sessionID != null) {
      if (state == AppLifecycleState.paused /*|| state == AppLifecycleState.detached*/) {
        activeWorkoutP.saveActiveWorkoutState();
      }
      // Note: The stopwatch accuracy when simply backgrounding (not closing)
      // is handled by Dart's Stopwatch itself. The save/restore logic
      // primarily handles full app closure and restart.
      // If app is just resumed from pause, ensure UI timer is active if workout isn't paused.
      else if (state == AppLifecycleState.resumed) {
          if (!activeWorkoutP.isPaused && (activeWorkoutP.timer == null || !activeWorkoutP.timer!.isActive)) {
              activeWorkoutP.startTimers(); // Ensure UI timer is running if workout is active
          }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // REMOVE OBSERVER
    super.dispose();
  }

  void _checkAndOpenDrawer() {
  final uiState = context.read<UiStateProvider>(); // Use read if not watching in build

  if (uiState.currentPageIndex == 2 && uiState.openProgramDrawerRequested) {
    // Consume the request so it doesn't happen again on rebuild
    uiState.consumeProgramDrawerRequest();

    // Important: Ensure this runs *after* the build phase is complete
    // if called during build or initState/didChangeDependencies.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if the state is still mounted
          ////debugPrint("🏠 Opening drawer from MainScaffoldState due to request");
          _scaffoldKey.currentState?.openDrawer();
      }
    });
  }
}

  //for testing notifications
  // String notifications = "";

  void openProgramDrawer() {
      ////debugPrint("🏠 openProgramDrawer() called");

    // Use the context from the State object which is a descendant of the Scaffold
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This context is now guaranteed to be below MultiProvider from _MainPage
      if (mounted) {
        final settings = Provider.of<SettingsModel>(context, listen: false);
        // Inject keys into TutorialManager for current subtree
        final tutorialManager = Provider.of<TutorialManager>(context, listen: false);
        tutorialManager.setKeys(
          mainScaffoldKey: null, // not needed currently
          workoutPageKey: widget.workoutPageKey,
          programPageKey: widget.programPageKey,
        );
        if (settings.isFirstTime) {
          Provider.of<TutorialManager>(context, listen: false)
              .startTutorialSequence(widget.showcaseContext); // Use the passed context
        } else {
          // Not first time, attempt to resume workout
          ////debugPrint("attempting resume");
          _initiateResumeAttempt();
        }
      }
    });
  }

  Future<void> _initiateResumeAttempt() async {
    // This context is MainScaffoldState's context.
    final activeWorkoutP = Provider.of<ActiveWorkoutProvider>(context, listen: false);
    final profileP = Provider.of<Profile>(context, listen: false);

    // Wait for Profile provider to be fully initialized
    if (!profileP.isInitialized) {
      ////debugPrint("MainScaffold: Profile not yet initialized. Awaiting initialization...");
      try {
        await profileP.initializationDone;
        ////debugPrint("MainScaffold: Profile initialization complete. Proceeding with resume check.");
      } catch (e) {
        ////debugPrint("MainScaffold: Profile initialization failed during await: $e. Aborting resume.");
        return;
      }
    }

    ActiveWorkoutSnapshot? snapshot = await activeWorkoutP.loadActiveWorkoutState();
    ////debugPrint("we got a snapshot: $snapshot");
    // widget.debugtext = snapshot?.toJson().toString() ?? "this was null";


    if (snapshot != null) {
      ////debugPrint("MainScaffold: Snapshot found for session ${snapshot.sessionID}. Attempting to auto-resume.");

      // Ensure Profile is set to the correct day context if necessary.
      // For now, assuming ActiveWorkoutProvider uses Profile's currently loaded data.
      // If you saved activeProgramID in snapshot, you'd tell Profile here:
      // await profileP.setActiveProgram(snapshot.activeProgramID);
      // Then, ensure Profile's internal "current day index" matches snapshot.activeDayIndex
      // await profileP.setCurrentDayForResume(snapshot.activeDayIndex);

      bool structuresPrepared = activeWorkoutP.prepareStructuresForRestoredDay(snapshot.activeDayIndex);
      if (!structuresPrepared) {
          ////debugPrint("MainScaffold: Failed to prepare AWP structures for day ${snapshot.activeDayIndex}. Clearing snapshot.");
          await activeWorkoutP.clearActiveWorkoutState();
          return;
      }
      
      bool restored = await activeWorkoutP.restoreFromSnapshot(snapshot);

      if (restored && mounted) {
        ////debugPrint("MainScaffold: Workout session resumed. UI should react.");
        // NO explicit navigation here from MainScaffold.
        // The UI (e.g., WorkoutSelectionPage or the initial page in your NavigationBar)
        // should watch ActiveWorkoutProvider.sessionID. If it becomes non-null
        // due to a resume, that page should trigger navigation to the Workout screen.
        // This keeps MainScaffold decoupled from direct Workout page navigation.
        // Example: WorkoutSelectionPage's initState or build method checks and navigates.
      } else if (!restored) {
        ////debugPrint("MainScaffold: Failed to restore snapshot. Clearing snapshot.");
        await activeWorkoutP.clearActiveWorkoutState();
      }
    } else {
      ////debugPrint("MainScaffold: No snapshot found to resume.");
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final uiState = context.watch<UiStateProvider>();
    final manager = context.watch<TutorialManager>();
    ////debugPrint("${manager.tutorialActive}");


    final ThemeData theme = Theme.of(context);
    // final notiService = NotiService();

    // Ignore interaction during tutorial
    return IgnorePointer(
      ignoring: manager.tutorialActive,
      child: Scaffold(
        
        key: _scaffoldKey,
        appBar: _buildAppBar(context),
        // floatingActionButton: TextButton(
        //   onPressed: () async {
        //     NotiService().//debugPrintScheduledNotifications();
        //   }, 
        //   child: const Text("see notifs")
        // ),
      
        drawer: ProgramsDrawer(
          currentProgramId: context.read<Profile>().currentProgram.programID,
          onProgramSelected: (selectedProgram) {
            context.read<Profile>().updateProgram(selectedProgram);
          },
          //debugText: widget.debugtext ?? "no debug -- null",
      
          theme: theme,
        ),
      
      
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: Selector<ActiveWorkoutProvider, bool>(
          // Only rebuild the nav bar border when a workout starts/ends, NOT on
          // the 1 Hz stopwatch tick (RC#2). Previously a context.watch here
          // rebuilt the ENTIRE root Scaffold (all IndexedStack pages) every second.
          selector: (_, awp) => awp.activeDay == null,
          child: NavigationBar(
            onDestinationSelected: (int index) {
              // reset bottombar and variables in this niche case
              if (uiState.currentPageIndex == 3 && uiState.isDisplayingChart) {
                uiState.onAppBarBackButtonPress!();
              }

              uiState.currentPageIndex = index;
            },
            shadowColor: theme.colorScheme.shadow,
            indicatorColor: theme.colorScheme.primary,
            indicatorShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(12),
              ),
            ),


            selectedIndex: uiState.currentPageIndex,
            //different pages that can be navigated to
            destinations: const <Widget>[
              NavigationDestination(
                selectedIcon: Icon(Icons.fitness_center),
                icon: Icon(Icons.fitness_center_outlined),
                label: 'Workout',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.calendar_month),
                icon: Icon(Icons.calendar_month_outlined),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.now_widgets_outlined),
                selectedIcon: Icon(Icons.now_widgets),
                label: 'Program',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
            ],
          ),
          builder: (context, noActiveWorkout, child) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  top: (noActiveWorkout && uiState.currentPageIndex != 2)
                    ? BorderSide(
                      color: theme.colorScheme.outline,
                      width: 0.5,
                    )
                    : BorderSide.none,
                ),
              ),
              child: child,
            );
          },
        ),
        //what opens for each page
        body: Selector<ActiveWorkoutProvider, bool>(
          // Rebuild the body margin only when a workout starts/ends, NOT on the
          // 1 Hz tick (RC#2) — otherwise the whole IndexedStack (all 4 pages)
          // rebuilt every second. The IndexedStack is passed as `child` so it is
          // reused untouched across margin changes.
          selector: (_, awp) => awp.activeDay != null,
          builder: (context, hasActiveWorkout, child) {
            return Container(
              margin: EdgeInsets.only(
                bottom: (uiState.currentPageIndex != 2 && hasActiveWorkout) ? 80 : 0
              ),
              child: child,
            );
          },
          child: IndexedStack(
            index: uiState.currentPageIndex,
            children: [
              WorkoutSelectionPage(theme: theme, key: widget.workoutPageKey),
              const SchedulePage(),
              ProgramPage(programkey: widget.programPageKey),
              AnalyticsPage(theme: theme),
            ],
          ),
        ),
        
      
        // Positioned(
        //   bottom: 100,
        //   child: Container(height: 500,
        //   color: Colors.red,
        //         child: Text(
        //           notifications,
        //           softWrap: true,
        //           maxLines: 100
                 
        //           )
        //       ),
        // ),
        //   ],
        //),
        
      
      
        bottomSheet: _buildBottomSheet(),
      //      bottomSheet: (context.watch<ActiveWorkoutProvider>().activeDay != null) ? WorkoutControlBar(theme: theme) : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final uiState = context.watch<UiStateProvider>();
    final manager = context.watch<TutorialManager>();
    final theme = Theme.of(context);

    // Default
    String title = "Workout";

    if (uiState.customAppBarTitle != null){
      title = uiState.customAppBarTitle!;
    } else if (uiState.isAddingGoal){
      title = "Select Exercise For Goal";
    } else if (uiState.currentPageIndex == 1){
      title = "Schedule";
    } else if (uiState.currentPageIndex == 2){
      title = context.watch<Profile>().currentProgram.programTitle;
    } else if (uiState.currentPageIndex == 3){
      title = "Analytics";
    }

    Widget? leading = uiState.showAppBarBackButton ? 
    IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: uiState.onAppBarBackButtonPress!,
    )
    : Showcase(
      disableDefaultTargetGestures: true,
      key: AppTutorialKeys.editPrograms,
      description: "Create and manage programs from here.",
      tooltipBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      descTextStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
      ),

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
      child: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
      ),
    );
    
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outline,
          width: 0.5
        ),
      ),
    ),
        child: AppBar(
            centerTitle: true,
            title: Text(
              title
            ),
            
        
            // Open Drawer to see/select/edit programs if on program page
            leading: leading,
        
          actions: [
            // Takes to settings page
            Showcase(
              disableDefaultTargetGestures: true,
              description: "If you want to change any settings in the future or redo this walkthrough, you can find them here.",
              //disableDefaultTargetGestures: true,
              key: AppTutorialKeys.settingsButton,
              tooltipBackgroundColor: theme.colorScheme.surfaceContainerHighest,
              descTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
              ),
        
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
        
              child: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomSheet(){
    final uiState = context.watch<UiStateProvider>();
    ThemeData theme = Theme.of(context);

    // The bottom sheet should be a done button if the user is using a numeric keyboard
    // then, if on program page we should display calendar
    // then, if active workout then we display workoutstopwatch
    // otherwise display nothing 

    if (uiState.isChoosingExercise || uiState.isDisplayingChart) return null;

    return Selector<ActiveWorkoutProvider, bool>(
      // Only depends on whether a workout is active, not the 1 Hz tick (RC#2).
      // WorkoutControlBar drives its own clock via its internal Consumer.
      selector: (_, awp) => awp.activeDay != null,
      builder: (context, hasActiveWorkout, child) {
        if (uiState.currentPageIndex == 2){
          return CalendarBottomSheet(
            today: DateTime.now(),
            theme: theme
          );
        } else if (hasActiveWorkout){
          return WorkoutControlBar(theme: theme);
        } else{
          return const SizedBox.shrink();
        }
      }
    );
  }
}
