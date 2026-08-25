import 'package:flutter/material.dart';
//import 'data_saving.dart';

//import 'dart:math';
// split, sets, etc in provider
// on opening app, set split data and other data to whatever is in database
// database is initialized with values but is then changed by user
// give that split to2provider
// whenever data is changed, update database in provider asynchronously
// whenever we retrieve data from provider, we now have to user futurebuilder

// A lot of the database functionality here could maybe be double checked...

// okay, im gonna try breaking this up into a few different Providers
//

/// Which screen opened the full-screen exercise search.
///
/// The pages that can open it (the workout logger, the program editor and
/// analytics) are all alive at once: the first two sit in the root IndexedStack
/// and stay built underneath the pushed workout route. A single bool meant all
/// three rendered their own search at the same time, and the off-screen copies
/// competed with the visible one for the keyboard. Naming the owner keeps
/// exactly one on screen.
enum ExerciseSearchOwner { none, workout, program, analytics }

class UiStateProvider extends ChangeNotifier {
  int _currentPageIndex = 0;
  bool _isAddingGoal = false;
  bool _isDisplayingChart = false;
  String? _customAppBarTitle;
  int? _expandProgramIndex;
  bool _openProgramDrawerRequested = false;
  bool _showAppBarBackButton = false;
  ExerciseSearchOwner _exerciseSearchOwner = ExerciseSearchOwner.none;
  bool _hasSetNotifs = false;
  Map<String, dynamic>? _pendingExerciseForChart;



  int get currentPageIndex => _currentPageIndex;
  int? get expandProgramIndex => _expandProgramIndex;
  bool get openProgramDrawerRequested => _openProgramDrawerRequested;
  bool get showAppBarBackButton => _showAppBarBackButton;
  /// True while any page is showing the exercise search. Used by the root
  /// scaffold to get its bottom sheet out of the way.
  bool get isChoosingExercise => _exerciseSearchOwner != ExerciseSearchOwner.none;

  ExerciseSearchOwner get exerciseSearchOwner => _exerciseSearchOwner;

  /// True only for the page that opened the search, so the others stay put.
  bool isSearchingExerciseFor(ExerciseSearchOwner page) =>
      _exerciseSearchOwner == page;

  bool get hasSetNotifs => _hasSetNotifs;
  Map<String, dynamic>? get pendingExerciseForChart => _pendingExerciseForChart;


  // The action to perform when the back button is pressed
  VoidCallback? _onAppBarBackButtonPress;
  VoidCallback? get onAppBarBackButtonPress => _onAppBarBackButtonPress;

   /// Sets the configuration for the AppBar's leading widget and title.
  void setAppBarConfig({
    bool showBackButton = false,
    VoidCallback? onPressed,
  }) {
    _showAppBarBackButton = showBackButton;
    _onAppBarBackButtonPress = onPressed;
    notifyListeners(); // Notify widgets watching this provider
  }

  /// Resets the AppBar configuration to its default state (no back button, default title).
  void resetAppBarConfig() {
    setAppBarConfig(showBackButton: false, onPressed: null);
  }


  void requestProgramDrawerOpen() {
    _openProgramDrawerRequested = true;
    // No need to notify listeners immediately,
    // MainScaffold will check it.
    // Or notify if MainScaffold needs to react instantly.
     notifyListeners();
  }

  void consumeProgramDrawerRequest() {
     if (_openProgramDrawerRequested) {
        _openProgramDrawerRequested = false;
        // Optionally notify if needed elsewhere, but maybe not.
        // notifyListeners();
     }
  }


  // In Analytics
  bool get isAddingGoal => _isAddingGoal;
  bool get isDisplayingChart => _isDisplayingChart;
  //bool get isEditing => _isEditing;
  String? get customAppBarTitle => _customAppBarTitle;

  // In UiStateProvider class
  bool _replayTutorialRequested = false;
  bool get replayTutorialRequested => _replayTutorialRequested;

  void requestTutorialReplay() {
    _replayTutorialRequested = true;
    notifyListeners();
  }

  void consumeTutorialReplayRequest() {
    _replayTutorialRequested = false;
    // Optionally notifyListeners(); if needed elsewhere
  }

  set customAppBarTitle (String? customAppBarTitle){
    _customAppBarTitle = customAppBarTitle;
    notifyListeners();
  }

  set hasSetNotifs (bool hasSetNotifs){
    _hasSetNotifs = hasSetNotifs;
    notifyListeners();
  }

  set currentPageIndex(int newIndex){
    assert(currentPageIndex >= 0 && currentPageIndex <= 3, "current page index $newIndex is not an index of a page. please use index 0-4.");
    resetAppBarConfig();
    _currentPageIndex = newIndex;
    
    notifyListeners();
  }

  /// Opens the exercise search on [page], or closes it with
  /// [ExerciseSearchOwner.none].
  set exerciseSearchOwner(ExerciseSearchOwner owner){
    if (_exerciseSearchOwner == owner) return;
    _exerciseSearchOwner = owner;
    notifyListeners();
  }

  set isAddingGoal(bool isAddingGoal){
    _isAddingGoal = isAddingGoal;
    notifyListeners();
  }

  set isDisplayingChart(bool isDisplayingChart){
    _isDisplayingChart = isDisplayingChart;
    notifyListeners();
  }

  set expandProgramIndex (int? newIndex){
    _expandProgramIndex = newIndex;
    notifyListeners();
  }

  set pendingExerciseForChart(Map<String, dynamic>? exercise) {
    _pendingExerciseForChart = exercise;
    notifyListeners();
  }
}