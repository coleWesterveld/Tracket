// View analytics, this weeks progress, goals, and history

// scrolling is whack

// maybe cool idea: allow easy export as CSV
// goal is to have analytics on a few things, namely: 
// DOTS or other powerlifting scoring scores based off of SBD and bodyweight
// bodyweight
// estimated 1RM in lift of choice**
// training frequency by month/week or some kind of volume tracker?
// maybe something to do a spotify wrapped type thing
// should clearly show markers like stocks do or something ie. ^5% 
// show gains for this week and then long term
// maybe good to have a smart feature which puts graphs that are important at the top automatically
//  important could be "progressing exceptionally well/poorly"
// make sure one rep max is calculated from top set from last session

/* I want to allow the user to pin some calculated stats to the top, here are some ideas from deepseek/me:

DOTS Score (Relative Strength)
(Weight Lifted) * 500 / (-16.260 + 1.0552*x - 0.0022405*x² + 0.0000010076*x³) (x = body weight in kg)
Shows strength relative to body weight (great for tracking progress across weight classes)
Wilks Score (Alternative to DOTS for powerlifting)
SBD Total (Squat + Bench + Deadlift 1RMs)

Meet Predictor
Projects competition total based on training maxes
Attempt Selection Advisor
Suggests opener/2nd/3rd attempt weights based on training history

PR Heatmap
Calendar view highlighting personal record days

Plateau Detection
Flags lifts with no progress in X weeks

Add a "Random Stat of the Day" widget that shows:
"You've spent 42 hours under the squat bar this year"
"Your total volume = 17 Toyota Corollas"
*/

// TODO: allow back button in appbar when chart displaying 

// TODO: bigger text maybe? or at least, option to scale it? I need old people for testing

import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';
import 'package:firstapp/app_tutorial/tutorial_manager.dart';
import 'package:firstapp/widgets/target_weight_dialog.dart';
import 'package:firstapp/widgets/weekly_progress.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../database/database_helper.dart';
import "../providers_and_settings/program_provider.dart";
import 'package:provider/provider.dart';
import '../widgets/exercise_search.dart';
import '../widgets/exercise_progress_chart.dart';
import '../database/profile.dart';
import '../widgets/info_popup.dart';
import 'package:firstapp/widgets/exercise_history_list.dart';
import 'package:firstapp/widgets/goal_progress.dart';
import 'package:firstapp/other_utilities/timespan.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.theme,
  });

  final ThemeData theme;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, dynamic>? _exercise;

  //Future<List<List<SetRecord>>>? _exerciseHistory;

  List<Goal> _goals = [];
  String? tempGoalTitle;
  bool _isLoadingGoals = true;

  Timespan _selectedTimespan = Timespan.sixMonths; // Default timespan


  final scrollControl = ScrollController();
  bool showBackToTop = false;

  // Pagination state variables for exercise history
  List<List<SetRecord>> _allLoadedSessions = []; // Store all sessions loaded so far
  final int _sessionsPerPage = 20; // Number of sessions to load per page
  int _currentPage = 0; // Current page index (0-based)
  bool _isLoadingMore = false; // Flag to prevent multiple simultaneous fetches
  bool _hasMoreData = true; // Flag to indicate if more data is available

  @override
  void initState() {
    scrollControl.addListener(_scrollListener);
    super.initState();
    _fetchGoals();
    
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Refresh goals when page becomes visible to show updated progress
    _fetchGoals(useMetric: context.read<SettingsModel>().useMetric);
    
    // Check if there's a pending exercise to display from workout page
    final uiState = context.read<UiStateProvider>();
    if (uiState.pendingExerciseForChart != null) {
      final exercise = uiState.pendingExerciseForChart!;
      
      // Clear the pending exercise immediately to avoid re-triggering
      uiState.pendingExerciseForChart = null;
      
      // Load the exercise history
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadExerciseHistory(exercise);
        }
      });
    }
  }

  void _scrollListener() {
    // determine whether or not to show the "back to top" button
    final bool shouldShow = scrollControl.offset > 100;
    // Only call setState if the state needs to change
    if (shouldShow != showBackToTop) {
      setState(() {
        showBackToTop = shouldShow;
      });
    }

    // loading depending on scroll position for pagination - 300 pixels in advance
    if (_exercise != null 
        && scrollControl.position.pixels >= scrollControl.position.maxScrollExtent - 300 
        && !_isLoadingMore 
        && _hasMoreData) {

      _fetchMoreHistory();
    }
  }

  @override
  void dispose(){
    scrollControl.removeListener(_scrollListener);
    scrollControl.dispose();
    super.dispose();
  }

   // Define a function to handle the logic when a *new* exercise is selected
  void _loadExerciseHistory(Map<String, dynamic> exercise,) {
    final uiState = context.read<UiStateProvider>();
     // Reset pagination state for the new exercise
     _allLoadedSessions = [];
     _currentPage = 0;
     _hasMoreData = true; // Assume more data for a new exercise
     _isLoadingMore = false; // Reset loading state

     // Update the selected exercise and display state
     _exercise = exercise;
     uiState.isDisplayingChart = true;

     uiState.setAppBarConfig(
       showBackButton: true,
       onPressed: _handleAppBarBackButtonPressed, // Provide the callback for the button press
     );

     // Trigger the fetch for the first page of history for the new exercise
     // Don't await here, let it run in the background
     _fetchMoreHistory();
  }

  void _handleAppBarBackButtonPressed() {
    // Get provider instance (can be before or after setState depending on logic needs)
    final uiState = context.read<UiStateProvider>();

    // ### Reset local state to exit chart view ###
    setState(() {
      uiState.isDisplayingChart = false;
      _exercise = null;
      // Reset pagination state when leaving the chart view
      _allLoadedSessions = [];
      _currentPage = 0;
      _hasMoreData = true;
      _isLoadingMore = false;
    });

    // ### Tell Provider to reset AppBar config (hide back button, reset title) ###
     uiState.resetAppBarConfig();

     // Note: If you were navigating with Navigator.push, you would use Navigator.pop(context) here instead.
     // Since you are just changing local state (_displayChart), this is correct.
  }

  // Method to fetch the next page of history
  Future<void> _fetchMoreHistory() async {
    // Add extra check for _exercise being null just in case
    if (_isLoadingMore || !_hasMoreData || _exercise == null) {
      return; // Don't fetch if already loading, no more data, or exercise is null
    }

    // No need to setState here before the async call
    // setState(() {
    //   _isLoadingMore = true; // Setting it *after* the await is fine too, but here is okay
    // });
     // Setting loading state *before* the async call so UI updates immediately
     if (!_isLoadingMore) { // Prevent unnecessary setState if called multiple times quickly
         setState(() {
           _isLoadingMore = true;
         });
     }


    // Calculate offset
    final offset = _currentPage * _sessionsPerPage;

    // Fetch the next page of sessions
    final nextPageSessions = await DatabaseHelper.instance.fetchSessionsPage(
      exerciseId: _exercise!['exercise_id'],
      limit: _sessionsPerPage,
      offset: offset,
      useMetric: context.read<SettingsModel>().useMetric, // Pass unit preference
    );
    // Create a list to hold the new sessions to add
    final List<List<SetRecord>> sessionsToAdd = [];
    bool moreDataAvailable = false;

    if (nextPageSessions != null && nextPageSessions.isNotEmpty) {
       sessionsToAdd.addAll(nextPageSessions);

       // Check if the number of sessions returned is equal to the limit,
       // suggesting there might be more data on the next page.
       if (nextPageSessions.length == _sessionsPerPage) {
         moreDataAvailable = true;
       } else {
         moreDataAvailable = false; // Returned less than a full page
       }

    } else {
      // If fetchSessionsPage returns null or empty, it means no more data
       moreDataAvailable = false;
    }

    setState(() {
      _allLoadedSessions.addAll(sessionsToAdd); // Add the fetched sessions
      _currentPage++; // Increment page count regardless of whether data was found (it's the next page index)
      _hasMoreData = moreDataAvailable; // Update hasMoreData flag
      _isLoadingMore = false; // Set loading state to false
    });
  }

  // Load existing goals from the database
  Future<void> _fetchGoals({useMetric = false}) async {
    setState(() => _isLoadingGoals = true);

    final dbHelper = DatabaseHelper.instance;
    _goals = await dbHelper.fetchGoalsWithProgress(useMetric: useMetric);

    setState(() => _isLoadingGoals = false);
    
  }

  @override
  Widget build(BuildContext context) {
    final uiState = context.watch<UiStateProvider>();

    if (!context.watch<Profile>().isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      
      extendBody: false, // Allows FAB to overlap MainScaffold's bottom nav
      backgroundColor: Colors.transparent, // Prevents double background

      floatingActionButton: (uiState.isDisplayingChart && showBackToTop)
        ? FloatingActionButton(
          onPressed: (){
            scrollControl.animateTo(
              0, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeIn,
            );
          }, 
        child: const Icon(Icons.keyboard_double_arrow_up_sharp),
      )
      : null,

      body: Stack(
        children: [
          // Show analytics content with the persistent search bar only when not searching.
          if (!uiState.isChoosingExercise && !uiState.isAddingGoal)
            Column(
              children: [
                if (!uiState.isDisplayingChart) _buildPersistentSearchBar(context),
                Expanded(
                  child: uiState.isDisplayingChart
                      ? _buildExerciseHistory()
                      : _buildAnalyticsContent(),
                ),
              ],
            ),

          // When search is active, show the full-screen search overlay.
          if (uiState.isChoosingExercise) _buildFullScreenSearch(context),
          if (uiState.isAddingGoal) _createGoal(context),
        ],
      ),
    );
  }

  // Callback when an exercise is selected - get history from the database
  void _handleExerciseSelected(Map<String, dynamic> exercise) async {
    ////debugPrint("ran");
    _loadExerciseHistory(exercise);
  }

  // When a goal is being added and the user selected the exercise for the goal to be for
  // This brings up the selector for target weight
  void _exerciseForGoalSelected(Map<String, dynamic> exercise) async {
    final dbHelper = DatabaseHelper.instance;
    final exerciseName = exercise['exercise_title'];
    final useMetric = context.read<SettingsModel>().useMetric;

    final weight = await showDialog<double>(
      context: context,
      builder: (context) => TargetWeightDialog(
        exerciseName: exerciseName,
        theme: widget.theme,
        useMetric: useMetric,
      ),
    );

    if (weight != null) {

      // First calculate current 1RM for this exercise
      final currentOneRm = await _calculateCurrentOneRm(exercise['exercise_id']);

      // Weight is entered in the user's preferred unit, but we store in lbs
      final weightInLbs = useMetric ? kgToLb(kilograms: weight) : weight;

      // Create and save the goal with accurate progress
      final newGoal = Goal(
        exerciseId: exercise['exercise_id'] as int ,
        exerciseTitle: exerciseName,
        targetWeight: weightInLbs,
        currentOneRm: currentOneRm,
      );

      final insertedId = await dbHelper.insertGoal(newGoal);

      final savedGoal = newGoal.copyWith(id: insertedId);

      setState(() {
        _goals.add(savedGoal);
      });
    }
  }

  // calculates one rep max based off of top set from last session from the database
  Future<double> _calculateCurrentOneRm(int exerciseId) async {

    final db = await DatabaseHelper.instance.database;
    
    // First, get the most recent session_id for this exercise
    final recentSession = await db.query(
      'set_log',
      columns: ['session_id'],
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'datetime(date) DESC',
      limit: 1,
    );

    if (recentSession.isEmpty) return 0;
    
    final sessionId = recentSession.first['session_id'] as String;
    
    // Now get the set with the highest calculated 1RM from that session
    final topSet = await db.rawQuery('''
      SELECT weight, reps, rpe,
             (weight * (1.0 + (reps + (10.0 - rpe)) / 30.0)) AS calculated_1rm
      FROM set_log
      WHERE exercise_id = ? AND session_id = ?
      ORDER BY calculated_1rm DESC
      LIMIT 1
    ''', [exerciseId, sessionId]);

    if (topSet.isEmpty) return 0;
    
    final weight = topSet.first['weight'] as double;
    final reps = topSet.first['reps'] as double;
    final rpe = topSet.first['rpe'] as double;

    // Formula to estimate 1 rep max with RPE adjustment
    // Accounts for reps in reserve: reps + (10 - rpe)
    return weight * (1 + (reps + (10 - rpe)) / 30);
  }

  // Build the exercise history view.
  Widget _buildExerciseHistory() {

    //context.read<UiStateProvider>().

    if (_allLoadedSessions.isEmpty && _isLoadingMore && _currentPage == 0) { // Added _currentPage == 0 check
         return const Center(child: CircularProgressIndicator());
    }

    // Show "No History Found" if list is empty AND we are NOT currently loading more data
    if (_allLoadedSessions.isEmpty && !_isLoadingMore) { // Removed _currentPage == 0 check here
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: Text('No History Found For: ${_exercise?['exercise_title'] ?? "This exercise"}')),
        );
    }

    return Scrollbar(
      controller: scrollControl,
      child: SingleChildScrollView(
        
        controller: scrollControl,
        
        child: Column(
          children: [
            ExerciseProgressChart(
              exercise: _exercise!,
              theme: widget.theme,
              selectedTimespan: _selectedTimespan,
              useMetric: context.read<SettingsModel>().useMetric,

              // auto calculate based on number of records
              decimationFactor: -1,

              onTimespanChanged: (newTimespan) {
                setState(() {
                  _selectedTimespan = newTimespan;
                });
              },
            ),

            Divider(
              color: widget.theme.colorScheme.outline,
              thickness: 2,
              endIndent: 40,
              indent: 40,
            ),
      
            // for this I could implement a see more option maybe
            // the listview.builder does only build the ones in view so its actually not bad performance-wise already
            // performance testing shows this runs comfortably and not close to hitting memory ceiling on my mid-tier phone
            // so its fine unless further testings shows an issue or I decide its best for UX
            ExerciseHistoryList(
              exerciseHistory: _allLoadedSessions,
              theme: widget.theme,
              isLoadingMore: _isLoadingMore, // Pass loading state to the list widget
              hasMoreData: _hasMoreData, // Pass hasMoreData state

              
            ),
          ],
        ),
      ),
    );
      
    
  }

  // List of Goal widgets, tappable to edit/delete
  List<Widget> _buildGoalList() {
    ////debugPrint("${((MediaQuery.sizeOf(context).width - 48)~/2 - 1).floorToDouble()}");
    return _goals.map((goal) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () => _showGoalOptions(goal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ((MediaQuery.sizeOf(context).width - 48)~/2 - 1).floorToDouble(),
              ),

              child: Text(
                goal.exerciseTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),

            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  width: 0.5,
                  color: widget.theme.colorScheme.outline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.colorScheme.shadow,
                    offset: const Offset(2, 2),
                    blurRadius: 4.0,
                  ),
                ],
                borderRadius: BorderRadius.circular(16),
                color: widget.theme.colorScheme.surfaceContainerHighest,
              ),
              width: ((MediaQuery.sizeOf(context).width - 48)~/2 - 1).floorToDouble(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: GoalProgress(
                  goal: goal,
                  size: ((MediaQuery.sizeOf(context).width - 48)~/2 - 1).floorToDouble(),
                  theme: widget.theme,
                ),
              ),
            ),
          ],
        ),
      ),
    )).toList();
  }

  // Bottomsheet that pops up when a goal is tapped
  void _showGoalOptions(Goal goal) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('See Progress'),
              onTap: () {
                Navigator.pop(context);
                final uiState = context.read<UiStateProvider>();
                setState(() {
                  _exercise = {
                    'exercise_id': goal.exerciseId,
                    'exercise_title': goal.exerciseTitle,
                  };
                  uiState.isDisplayingChart = true;
                });
                _handleExerciseSelected(_exercise!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Target'),
              onTap: () {
                Navigator.pop(context);
                _editGoalWeight(goal);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete, 
                color: widget.theme.colorScheme.error
              ),

              title: Text(
                'Delete Goal', 
                style: TextStyle(
                  color: widget.theme.colorScheme.error
                )
              ),

              onTap: () {
                Navigator.pop(context);
                _deleteGoal(goal);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for editing goal target
  Future<void> _editGoalWeight(Goal goal) async {
    final dbHelper = DatabaseHelper.instance;
    final useMetric = context.read<SettingsModel>().useMetric;
    
    // Display weight in user's preferred unit
    final displayWeight = useMetric ? lbToKg(pounds: goal.targetWeight) : goal.targetWeight;
    final weightController = TextEditingController(text: displayWeight.toString());
    final unit = useMetric ? 'kg' : 'lbs';

    final newWeight = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Target for ${goal.exerciseTitle}'),
        content: TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),

          decoration: InputDecoration(
            labelText: 'Target Weight ($unit)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (weightController.text.isNotEmpty) {
                Navigator.pop(context, double.parse(weightController.text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newWeight != null) {
      // Convert to lbs for storage if user entered in kg
      final weightInLbs = useMetric ? kgToLb(kilograms: newWeight) : newWeight;
      
      final updatedGoal = goal.copyWith(targetWeight: weightInLbs);
      await dbHelper.updateGoal(updatedGoal);
      if (mounted){
        await _fetchGoals(useMetric: context.read<SettingsModel>().useMetric);
      }
    }
  }

  // Dialog and DB method to delete goal
  Future<void> _deleteGoal(Goal goal) async {

    final dbHelper = DatabaseHelper.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('This will remove your ${goal.exerciseTitle} target'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete', 
              style: TextStyle(
                color: widget.theme.colorScheme.error
              )
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await dbHelper.deleteGoal(goal.id!);
      setState(() {
        _goals.removeWhere((g) => g.id == goal.id);
      });
    }
  }

  // Build the original analytics content.
  SingleChildScrollView _buildAnalyticsContent() {
    final manager = context.watch<TutorialManager>();
    final uiState = context.watch<UiStateProvider>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [  
            Showcase(
              disableDefaultTargetGestures: true,
              key: AppTutorialKeys.recentWorkouts,
              description: "See your progress from the past week. Tap on an exercise to see an extended history.",
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
              child: Container(
                // No fixed height: the card now grows to fit the day with the most
                // exercises (PageViewWithIndicator computes a shared, capped page
                // height internally), instead of clipping at 325px (#14).
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: widget.theme.colorScheme.surface,  
              
                  border: Border.all(
                    width: 0.5,
                    color: Theme.of(context).colorScheme.outline,
                  ),

                  boxShadow: [
                    BoxShadow(
                      blurRadius: 5,
                      offset: const Offset(0, 0),
                      spreadRadius: 2,
                      color: widget.theme.colorScheme.shadow
              
                    )
                  ]
                ),
                    
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    // min: let the card size itself to its content (#14)
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                              "Last 7 Days",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      // Displays progress on exercises during past week workout.
                      // Self-sizing: no Expanded, since the parent is now unbounded.
                      PageViewWithIndicator(
                        theme: widget.theme,
                        onSelected: (exercise){
                          setState(() {
                            _exercise = exercise.toMap();
                            uiState.isDisplayingChart = true;
                          });
                          _handleExerciseSelected(exercise.toMap());

                         // _exerciseHistory = _handleExerciseSelected(exercise.toMap());
                        }
                      ),
                    ],
                  )
                )
              ),
            ),
      
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Showcase(
                disableDefaultTargetGestures: true,
                key: AppTutorialKeys.addGoals,
                description: "Add a target weight for an exercise, and watch your predicted one-rep max improve.",
                tooltipBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                descTextStyle: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                ),

                tooltipActions: [
                  TooltipActionButton(
                    type: TooltipDefaultActionType.skip,
                    onTap: () => manager.skipTutorial(),
                    name: "Finish",
                    backgroundColor: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.onSurface
                    ),
                    textStyle: TextStyle(
                      color: theme.colorScheme.onSurface
                    )

                    
                  ),
                ],
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: widget.theme.colorScheme.surface,  
                    
                    border: Border.all(
                    width: 0.5,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 5,
                        offset: const Offset(0, 0),
                        spreadRadius: 2,
                        color: widget.theme.colorScheme.shadow
                
                      )
                    ]
                  ),
                        
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Goals",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                
                                    InfoPopupWidget(
                                      popupContent: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Your \'Actual\' weight is your calculated approximate n rep max using the Epley formula:'),
                                          Center(child: Text(" \n 1 Rep Max = Weight • (1 + Reps / 30)")),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ButtonTheme(
                                    minWidth: 100,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() => uiState.isAddingGoal = true,);
                                      },
                                    
                                      style: ButtonStyle(
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12))),
                                            backgroundColor: WidgetStateProperty.all(widget.theme.colorScheme.primary,), 
                                      ),
                                      
                                      label: Text(
                                        "Add Goal",
                                        style: TextStyle(
                                          color: widget.theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _isLoadingGoals 
                          ? const Center(child: CircularProgressIndicator())
                          : Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: _buildGoalList(),
                          ),
                        ),
                      ],
                    )
                  )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Persistent search bar
  Widget _buildPersistentSearchBar(BuildContext context) {
    final uiState = context.read<UiStateProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            uiState.isChoosingExercise = true;
          });
        },
        child: Container(
          
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 0.5
            ),

            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                offset: const Offset(0, 0),
                spreadRadius: 2,
                color: widget.theme.colorScheme.shadow

              )
            ]
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: widget.theme.colorScheme.onSurface),

              const SizedBox(width: 8),

              Text(
                "Search exercise to view history...",
                style: TextStyle(color: widget.theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Full-screen search overlay.
  Widget _buildFullScreenSearch(BuildContext context) {
    final uiState = context.read<UiStateProvider>();

    return ExerciseSearchWidget(
      theme: widget.theme,
      onExerciseSelected: (exercise){
        setState(() {
          _exercise = exercise;
          uiState.isDisplayingChart = true;
        });
        _handleExerciseSelected(exercise);

       // _exerciseHistory = _handleExerciseSelected(exercise);
      },

      onSearchModeChanged: (isSearching) {
        setState(() {
          uiState.isChoosingExercise = isSearching;          
        });
      },
    );
  }

  Widget _createGoal(BuildContext context){
    final uiState = context.watch<UiStateProvider>();


    return ExerciseSearchWidget(
      onExerciseSelected: _exerciseForGoalSelected,
      onSearchModeChanged: (isSearching) {
        setState(() {
          uiState.isAddingGoal = isSearching;
        });
      },
      theme: widget.theme,
    );
  }
}
