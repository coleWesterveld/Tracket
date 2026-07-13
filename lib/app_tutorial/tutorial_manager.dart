import 'package:firstapp/program_page/program_page.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'app_tutorial_keys.dart';
import '../main.dart'; // Access MainScaffoldState
import '../workout_page/workout_selection_page.dart'; // Access WorkoutSelectionPageState
import 'package:provider/provider.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';



class TutorialManager extends ChangeNotifier {
  GlobalKey<MainScaffoldState>? mainScaffoldKey;
  GlobalKey<WorkoutSelectionPageState>? workoutPageKey; // Key to access workout page state
  GlobalKey<ProgramPageState>? programPageKey; // Key to access workout page state


  TutorialManager();

  void setKeys({
    GlobalKey<MainScaffoldState>? mainScaffoldKey,
    required GlobalKey<WorkoutSelectionPageState> workoutPageKey,
    required GlobalKey<ProgramPageState> programPageKey,
  }) {
    this.mainScaffoldKey = mainScaffoldKey;
    this.workoutPageKey = workoutPageKey;
    this.programPageKey = programPageKey;
  }

  // Define the sequence of keys
  final List<GlobalKey> _tutorialSequence = [
    AppTutorialKeys.settingsButton,
    AppTutorialKeys.editPrograms,
    // Use tutorial-specific key to avoid collisions with app tree
    AppTutorialKeys.addDayToProgramTutorial,
    AppTutorialKeys.addExerciseToProgram,
    AppTutorialKeys.editScheduleButton,
    AppTutorialKeys.startWorkout,
    AppTutorialKeys.recentWorkouts,
    AppTutorialKeys.addGoals
  ];

  final exerciseDemoExpandController = ExpansibleController();
  final workoutDemoController = ExpansibleController();

  int _currentStep = 0;

  late BuildContext _ctx;    // we’ll capture this so our buttons can call back in
  void startTutorialSequence(BuildContext showCaseContext) {
    _ctx = showCaseContext;
    _currentStep = 0;
    _setTutorialActive(true);
    _executeStep(showCaseContext);
  }


  // This will be used top disable user interaction with 
  // anything but the next and skip buttons during the tutorial
  bool _tutorialActive = false;

   // Keep track of retries for waiting
  int _waitRetries = 0;
  final int _maxWaitRetries = 15; // Max frames to wait for widget

  bool get tutorialActive => _tutorialActive;

  void _setTutorialActive(bool value) {
    _tutorialActive = value;
    notifyListeners();
  }



  void advanceStep() {
    _currentStep++;
    _executeStep(_ctx);
  }

  void skipTutorial() {
    // 1) Mark in SettingsModel that tutorial is complete
    Provider.of<SettingsModel>(_ctx, listen: false).completeTutorial();

    // 2) Dismiss the currently visible tooltip
    final scState = ShowCaseWidget.of(_ctx);
    
    scState.dismiss();     // hides the current showcase bubble immediately
    _setTutorialActive(false);
    showCompletionPrompt();

    // 3) Prevent any future steps from running
    _currentStep = _tutorialSequence.length;
  }


  // Gets called for every showcase - defines flow for a single widget to showcase
  Future<void> _executeStep(BuildContext showCaseContext) async {
    ////debugPrint("Executing Tutorial Step: $_currentStep");
    if (_currentStep >= _tutorialSequence.length) {
      ////debugPrint("dpone");
      _handleTutorialCompletion(showCaseContext);
      return;
    }

    final currentKey = _tutorialSequence[_currentStep];
    _waitRetries = 0; // Reset retry counter for the new step

    // 1. Prepare the UI (Navigation, Expansion, etc.) - Await actions within prepare
        bool didNavigate = await _prepareForStep(showCaseContext, currentKey);

    // 2. *** ADD DELAY if navigation happened ***

   
    // 2. Wait for the target widget to be built and then showcase it
    _waitForWidgetAndShowcase(showCaseContext, currentKey, didNavigate: didNavigate);
  }

  // Helper to wait for the widget associated with the key to be built
  void _waitForWidgetAndShowcase(BuildContext showCaseContext, GlobalKey currentKey, {bool didNavigate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async{
      // Check if the widget context is available and showcase context exists
      final targetContext = currentKey.currentContext;
      final showCaseState = ShowCaseWidget.of(showCaseContext);

      if (targetContext != null) {
        // Widget is ready! Showcase it.
        ////debugPrint("Widget for key $currentKey found. Starting showcase.");

        if (didNavigate) await Future.delayed(const Duration(milliseconds: 500)); // Added delay
        try {
          showCaseState.startShowCase([currentKey]);
        } catch (e) {
          print("Error starting showcase for key $currentKey after finding context: $e");
          _handleStepError(showCaseContext); // Decide how to handle showcase error
        }
      } else {
        // Widget not ready yet, retry next frame (up to a limit)
        _waitRetries++;
        if (_waitRetries <= _maxWaitRetries) {
          ////debugPrint("Widget for key $currentKey not ready yet. Retrying frame ($_waitRetries/$_maxWaitRetries)...");
          // Schedule the check again for the next frame
          _waitForWidgetAndShowcase(showCaseContext, currentKey);
        } else {
          // Max retries reached, widget likely never appeared
          print("Error: Widget for key $currentKey did not become available after $_maxWaitRetries frames.");
          _handleStepError(showCaseContext); // Skip step or stop tutorial
        }
      }
    });
  }

  // Consolidated error handling for a step
  void _handleStepError(BuildContext showCaseContext) {
     print("Error occurred during tutorial step $_currentStep. Skipping to next step.");
     // Optionally dismiss any lingering showcase overlay if needed
     // ShowCaseWidget.of(showCaseContext)?.dismiss();
     advanceStep(); // Move to the next step
  }

   // Consolidated completion handling
  void _handleTutorialCompletion(BuildContext showCaseContext) {
    print("Tutorial sequence complete.");
     _setTutorialActive(false);
     // Dismiss any final showcase bubble if necessary
     ShowCaseWidget.of(showCaseContext).dismiss();
     showCompletionPrompt();
  }

  // Prepare the UI for the specific step (REVISED - NO ARTIFICIAL DELAYS FOR BUILDS)
  Future<bool> _prepareForStep(BuildContext context, GlobalKey key) async {
    final uiState = context.read<UiStateProvider>();
    int targetPageIndex = -1;
    bool navigationOccurred = false; // Flag to return


    // Determine target page index based on key
    if (key == AppTutorialKeys.settingsButton || key == AppTutorialKeys.editPrograms || key == AppTutorialKeys.addDayToProgram || key == AppTutorialKeys.addExerciseToProgram) {
      targetPageIndex = 2; // Program Page
    } else if (key == AppTutorialKeys.editScheduleButton) {
      targetPageIndex = 1; // Schedule Page
    } else if (key == AppTutorialKeys.recentWorkouts || key == AppTutorialKeys.addGoals) {
      targetPageIndex = 3; // Analytics Page
    } else if (key == AppTutorialKeys.startWorkout) {
      targetPageIndex = 0; // Workout Page
    }

    // --- Navigation ---
    if (targetPageIndex != -1 && uiState.currentPageIndex != targetPageIndex) {
      ////debugPrint("Navigating from ${uiState.currentPageIndex} to $targetPageIndex for key $key");
      uiState.currentPageIndex = targetPageIndex;
      navigationOccurred = true; // Set the flag

      // IMPORTANT: We DON'T await a Future.delayed here anymore for build timing.
      // The framework needs time to process the state change and rebuild.
      // _waitForWidgetAndShowcase will handle waiting for the result.
      // We might need a minimal yield just to let the event loop process the state change:
      await Future.delayed(Duration.zero); // Yield execution briefly
    }

    // --- Drawer Opening (Example - If needed for AppTutorialKeys.editPrograms) ---
    //  if (key == AppTutorialKeys.editPrograms) {
    //    // Ensure Program Page (index 2) is active
    //    if (uiState.currentPageIndex == 2) {
    //       //debugPrint("Requesting program drawer open for editPrograms step");
    //       // Use the robust method established earlier
    //       WidgetsBinding.instance.addPostFrameCallback((_) {
    //          // Check if main scaffold state is available before calling
    //          mainScaffoldKey.currentState?.openProgramDrawer();
    //          // Note: We might still need _waitForWidgetAndShowcase if the item *inside*
    //          // the drawer needs time to build after the drawer animation.
    //       });
    //       // Give drawer animation some time if the target is *inside* it.
    //       await Future.delayed(const Duration(milliseconds: 400)); // Adjust if needed for drawer animation
    //    }
    //  }

    // --- Expansion Logic ---
    if (key == AppTutorialKeys.addExerciseToProgram) {
      if (uiState.currentPageIndex == 2) {
        exerciseDemoExpandController.expand();
        // Expansion likely has its own animation, wait a reasonable time for it.
        await Future.delayed(const Duration(milliseconds: 400));
      }
    } else if (key == AppTutorialKeys.startWorkout) {
      if (uiState.currentPageIndex == 0) {
        // Wait a frame to ensure workoutPageKey state might be ready after nav
         await Future.delayed(Duration.zero);
         WidgetsBinding.instance.addPostFrameCallback((_) {
            workoutPageKey?.currentState?.expandTile();
         });
        // Wait for expansion animation
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

        return navigationOccurred; // Return the flag

  } // End of _prepareForStep

  void showCompletionPrompt() {
    final uiState = _ctx.read<UiStateProvider>();
    // Get the current theme
    final theme = Theme.of(_ctx); // Use _ctx here as it's the context available in this method

    showModalBottomSheet(
      context: _ctx,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure buttons are full width
            children: [
              Center(
                child: Text(
                  "You're all set!",
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Would you like to create your very first program now, or explore the app on your own?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  uiState.currentPageIndex = 2;
                  Navigator.pop(context);
                  context.read<UiStateProvider>().requestProgramDrawerOpen();
                },
                // Style for the primary button
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, // Background color
                  foregroundColor: theme.colorScheme.onPrimary, // Text color
                  padding: const EdgeInsets.symmetric(vertical: 16), // Adjust padding
                  shape: RoundedRectangleBorder( // Optional: add rounded corners
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Create First Program",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )
                ),
              ),

              const SizedBox(height: 8), // Spacing between buttons
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  // nothing else, let them explore
                },
                // Style for the outlined button
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary, // Text color (same as outline)
                   side: BorderSide(color: theme.colorScheme.primary, width: 2), // Outline border
                   padding: const EdgeInsets.symmetric(vertical: 16), // Adjust padding
                    shape: RoundedRectangleBorder( // Optional: add rounded corners
                      borderRadius: BorderRadius.circular(12),
                    ),
                ),
                child: const Text(
                  "Explore on Your Own",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

}