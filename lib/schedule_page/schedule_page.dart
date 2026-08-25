// schedule page
//not updated
//import 'dart:ffi';

// TODO: these indicators are not very clear, i need to make the design more intuitive
// ie. what days have passed, what indicates today vs. indicates selected day

import 'dart:async';

import 'package:firstapp/app_tutorial/app_tutorial_keys.dart';
import 'package:firstapp/app_tutorial/tutorial_manager.dart';
import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/providers_and_settings/ui_state_provider.dart';
import 'package:firstapp/widgets/display_workout.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers_and_settings/program_provider.dart';
import '../database/profile.dart';
import 'edit_schedule.dart';
import '../other_utilities/lightness.dart';
import 'package:firstapp/other_utilities/events.dart';
import 'package:showcaseview/showcaseview.dart';

// TODO: not showing what the exercise that was done was??

class SchedulePage extends StatefulWidget {

  const SchedulePage({
    Key? mykey,
  }) : super(key: mykey);

  @override
  _MyScheduleState createState() => _MyScheduleState();
}

// this class contains the list view of expandable card tiles 
// title is day title (eg. 'legs') and when expanded, leg exercises for that day show up
class _MyScheduleState extends State<SchedulePage> with WidgetsBindingObserver {
  /// Where this page sits in the root IndexedStack (see main.dart). The stack
  /// builds every page at launch and never disposes them, so the tab index is
  /// the only signal that this one is back on screen.
  static const int _scheduleTabIndex = 1;

  /// Refreshed on every load, NOT once in initState: this State outlives any
  /// single day, so a field frozen at launch still calls the launch day "today"
  /// after the app has sat in the background overnight.
  DateTime today = DateTime.now();
  Map<DateTime, List<Event>> events = {};

  // this becomes origin from profile class in initializer
  // origin is some day of this week, specified by user
  // this may need to be changed for longer startdays and saved in database
  DateTime startDay = DateTime.now();

  DateTime? _selectedDay;
  late ValueNotifier<List<Event>> _selectedEvents;
  Future<List<SetRecord>>? loggedSets;

  /// The day [loggedSets] was fetched for, so a refresh that changes nothing
  /// does not re-fetch it and flash the skeleton.
  DateTime? _loggedSetsDay;

  /// Days in the last 43 with at least one logged set. This is a snapshot, and
  /// the DB moves under it: sets are written the moment a box is checked and
  /// deleted again by unchecking one or discarding the workout. Reload it
  /// whenever the page comes back into view, otherwise it both misses workouts
  /// logged since launch and keeps ghost days whose sets are already gone.
  Set<DateTime>? didWorkout;

  UiStateProvider? _uiState;
  int _lastTabIndex = 0;

  Future<void> loadDaysActive() async {
    final DateTime now = DateTime.now();
    // From midnight, not from this moment 43 days ago, so the oldest day in the
    // window is judged on all of its sets rather than the ones logged late in
    // the day.
    final List<DateTime> days = await context.read<Profile>().getDaysWithHistory(
      normalizeDay(now).subtract(const Duration(days: 43)),
      now,
    );
    if (!mounted) return;

    final Set<DateTime> loaded = days.toSet();
    final bool historyChanged = didWorkout == null
        || didWorkout!.length != loaded.length
        || !didWorkout!.containsAll(loaded);

    setState(() {
      today = now;
      didWorkout = loaded;
      if (historyChanged || _loggedSetsDay != normalizeDay(_selectedDay!)) {
        _refreshLoggedSets();
      }
    });
  }

  /// Queues the logged sets for the selected day, or clears them when that day
  /// has no history. Callers are responsible for the setState around it.
  void _refreshLoggedSets() {
    final DateTime day = normalizeDay(_selectedDay!);
    _loggedSetsDay = day;
    loggedSets = (didWorkout?.contains(day) ?? false)
        ? context.read<Profile>().getSetsForDay(day)
        : null;
  }

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedDay = today;
    _selectedEvents = ValueNotifier(getWorkoutForDay(day: _selectedDay!, context: context));

    _uiState = context.read<UiStateProvider>();
    _lastTabIndex = _uiState!.currentPageIndex;
    _uiState!.addListener(_onTabChanged);

    loadDaysActive();
    //loadEvents();
  }

  /// Reload when the schedule tab comes back into view. Event driven, so
  /// nothing runs while the user is on another tab.
  void _onTabChanged() {
    final int index = _uiState!.currentPageIndex;
    final bool cameIntoView = index == _scheduleTabIndex && _lastTabIndex != _scheduleTabIndex;
    _lastTabIndex = index;
    if (cameIntoView) loadDaysActive();
  }

  /// The other moment the snapshot can be stale without this page hearing about
  /// it: the app was in the background, possibly across midnight. Only worth a
  /// query if the schedule is what the user is coming back to.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed
        && _uiState?.currentPageIndex == _scheduleTabIndex) {
      loadDaysActive();
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) return;
    setState((){
      _selectedDay = selectedDay;
      //today = focusedDay;
      _refreshLoggedSets();
      _selectedEvents.value = getWorkoutForDay(day: selectedDay, context: context);
    });
  }

  Widget buildLegend(){
    int crossCount = 2;
    int numLabels = context.watch<Profile>().split.where((d) => !d.isTemporary).length;
    
    Orientation orientation = MediaQuery.of(context).orientation;
    return SizedBox(
      //color: Colors.red,
      width: double.infinity,
      height: orientation == Orientation.portrait ? 34*(numLabels / crossCount).ceilToDouble() : 50,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: orientation == Orientation.portrait ?  crossCount: 1,
        //crossAxisSpacing: 5,
        //mainAxisSpacing: 5,
        childAspectRatio: 6,
        children: legendLabels(),
      ),
    );
  }

  List<Widget> legendLabels(){


    List<Widget> labels = [];
    for (Day day in context.watch<Profile>().split){
      if (day.isTemporary) continue; // skip one-off workout days
      labels.add(
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: SizedBox(
            height: 20,
            child: Row(
            children: [
              Container(
                width: 15,
                height: 15, 
                decoration: BoxDecoration(
                  color: Color(day.dayColor),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  " ${day.dayTitle}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700
                  )
                )
              ),
            ],
            ),
          ),
        )
        );

      //labels.add(label);
    }
    return labels;
  }

    @override
  void dispose() {
    _uiState?.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _selectedEvents.dispose(); // Dispose the ValueNotifier to avoid memory leaks
    super.dispose();
  }

  BoxDecoration _buildToday(BuildContext context){
    final theme = Theme.of(context);

    final events = getWorkoutForDay(day: today, context: context);
    if (events.isNotEmpty){
      return BoxDecoration(
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
        //borderRadius: const BorderRadius.all(Radius.circular(14)),
        color: darken(Color(context.watch<Profile>().split[events[0].index].dayColor),50), 
        shape: BoxShape.circle, 
      );
    }

    return  BoxDecoration(
        color:  darken(const Color(0xFF1e2025), 50),
        border: Border.all(color: theme.colorScheme.onSurface, width: 3),
        //borderRadius:  const BorderRadius.all(Radius.circular(14)),
        shape: BoxShape.circle, 
      );
    
    
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedEvents.value = getWorkoutForDay(day: _selectedDay!, context: context);
  }

  @override
  
  // main scaffold, putting it all together
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = context.watch<TutorialManager>();

    if (!context.watch<Profile>().isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    startDay = context.watch<Profile>().origin;

    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Showcase(
                  disableDefaultTargetGestures: true,
                  key: AppTutorialKeys.editScheduleButton,
                  description: "Schedule your workouts to get timely reminders for upcoming workouts and gear you need.",
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
                  child: TextButton(
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            //context.read<UiStateProvider>().customAppBarTitle = "Edit Schedule";
                            return EditSchedule(
                              theme: theme
                            );
                          }
                        )
                      );
                    }, 
                    child: const Text("Edit Schedule")),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 14, right: 14),
              child: Container(
                
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.5
                  ),
                  
                  color: theme.colorScheme.surface,
                  //border: Border
                  borderRadius: BorderRadius.circular(12),

                  boxShadow: [
                    BoxShadow(
                      blurRadius: 5,
                      offset: const Offset(0, 0),
                      spreadRadius: 2,
                      color: theme.colorScheme.shadow

                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
        
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                      child: TableCalendar(
                        availableGestures: AvailableGestures.horizontalSwipe,
                        
                      
                      //TODO: add button in header to take user back to today
                        // limit to only monthview
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                      
                        // will return true if seected day is same as day, will highlight day as selected
                        selectedDayPredicate: (day) {
                          return _selectedDay!.year == day.year &&
                            _selectedDay!.month == day.month &&
                            _selectedDay!.day == day.day;
                        },
                      
                        // manage when a day gets tapped
                        onDaySelected: _onDaySelected,
                      
                        // given a day, load its events
                        // eventLoader: (day){
                        //   return getWorkoutForDay(day: day, context: context);
                        // },
                        
                        
                        // build by day
                        
                        calendarBuilders: CalendarBuilders(
                        outsideBuilder: (context, day, focusedDay) => _buildDay(context, day, focusedDay, theme, this.context),
                      
                      
                        defaultBuilder: (context, day, focusedDay) => _buildDay(context, day, focusedDay, theme, this.context),

                        selectedBuilder: (context, day, focusedDay) {
                          return Container(
                            decoration: BoxDecoration(
                              //color:  theme.colorScheme.,
                              border: Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3.0,
                              ),
                              //border: Border.all(color: theme.colorScheme.surface, width: 1),        borderRadius:  const BorderRadius.all(Radius.circular(14)),
                              shape: BoxShape.circle, 
                            ),

                            child: Center(child: Text('${day.day}'))
                          );
                        },

                        ),
                        rowHeight: 70,
                        focusedDay: _selectedDay!, 
                        firstDay: DateTime(today.year - 5, today.month, today.day), 
                        lastDay: DateTime(today.year + 5, today.month, today.day),
                        calendarStyle: CalendarStyle(
                          markerDecoration: const BoxDecoration(),
                          defaultDecoration: const BoxDecoration(
                            //color: Colors.white,
                            //borderRadius: BorderRadius.circular(14),
                            shape: BoxShape.circle,
                          ),
                          
                          
                          //selectedDecoration: _buildSelected(context),
                          todayDecoration: _buildToday(context),
                      
                          // the days default to circle shape, and this throws errors on animating selection (even after chaning default)
                          // idk a better way to do this, but this works, even if its maybe not elegant
                          rangeEndDecoration: const BoxDecoration(
                            //color: Colors.white,
                            //borderRadius: BorderRadius.circular(14),
                            shape: BoxShape.circle,
                          ),
                          weekendDecoration: const BoxDecoration(
                            //color: Colors.white,
                            //borderRadius: BorderRadius.circular(14),
                            shape: BoxShape.circle,
                          ),
                          outsideDecoration: const BoxDecoration(
                            //color: Colors.white,
                            //borderRadius: BorderRadius.circular(14),
                            shape: BoxShape.circle,
                          ),
                      
                          selectedTextStyle: TextStyle(
                            color: theme.colorScheme.onPrimary, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    buildLegend(),
                  ],
                ),
              ),
            ),

            // shows more info upon click
            ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents, 
              builder: (context, value, _) {
                // Only a day with logged sets is given a future, so there is no
                // need to ask here whether the day is in the past.
                if (loggedSets == null) return _buildPlannedWorkout(value, theme);

                return FutureBuilder<List<SetRecord>>(
                  future: loggedSets, 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingCard(theme);
                    }

                    if (snapshot.hasError) return _buildHistoryError(theme);

                    final List<SetRecord> sets = snapshot.data ?? const [];

                    // The day list said this day had history and the sets are
                    // gone, so they were deleted after it was loaded: a
                    // discarded workout, an unchecked set. Fall back to what was
                    // planned rather than hand an empty list to DisplayWorkout,
                    // which reads its first entry for the date.
                    if (sets.isEmpty) return _buildPlannedWorkout(value, theme);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0, left: 14.0, right: 14.0),
                      // TODO: maybe make this tappable to see in fullscreen view?
                      child: DisplayWorkout(
                        color: theme.colorScheme.surface,
                        exerciseHistory: sets,
                        theme: theme,
                      ),
                    );
                  },
                );
              }
            )
          ],
        ),
    );
  }

  /// What is planned for the selected day, or nothing at all on a rest day.
  /// Also the fallback for a day whose logged sets have since been deleted.
  Widget _buildPlannedWorkout(List<Event> value, ThemeData theme) {
    if (value.isEmpty) return const SizedBox(height: 0);

    return Padding(
      padding: const EdgeInsets.all(12.0).copyWith(top: 0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 5,
              offset: const Offset(2, 2),
              spreadRadius: 2,
              color: theme.colorScheme.shadow
            )
          ],
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 0.5
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListTile(
            onTap:() {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return EditSchedule(
                      theme: theme
                    );
                  }
                )
              );
            },
            title: Text(
              "Day ${value[0].index + 1} • ${value[0].title}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700
              )
            ),
            subtitle: Text(formatDate(_selectedDay!)),
            trailing: Text(
              // TODO: tappable to add time?
              value[0].time?.format(context) ?? "No Time Set",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700
              )
            )
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    return Skeletonizer(
      enabled: true, 
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14.0, left: 14.0, right: 14.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: BoxBorder.all(
              color: theme.colorScheme.outline,
              width: 0.5
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow,
                offset: const Offset(2, 2),
                blurRadius: 4.0,
              ),
            ]
          ),
          child: const Padding(
            padding: EdgeInsets.all(14.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Loading...",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    )
                  )
                ),
                
                Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text("Loading..."),
                ),
        
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Notes Loading"
                  ),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  /// A read that failed used to look exactly like one that was slow: an errored
  /// future carries no data either, so the skeleton stayed up forever. Say so,
  /// and offer the read again.
  Widget _buildHistoryError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0, left: 14.0, right: 14.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: 0.5
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow,
              offset: const Offset(2, 2),
              blurRadius: 4.0,
            ),
          ]
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14.0, top: 6.0, bottom: 6.0, right: 6.0),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Could not load this day's workout.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(_refreshLoggedSets),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // context is a bit strange, theres a local and a 'real' context
  Widget? _buildDay(context, DateTime day, focusedDay, ThemeData theme, BuildContext realContext) {
    // The calendar hands over UTC midnight for each cell, which is the evening
    // before in local time, so comparing the raw instants called tomorrow a past
    // day from 8pm on. Compare the calendar days themselves.
    final bool isFuture = normalizeDay(day).isAfter(normalizeDay(today));

    if (isFuture){
      // if day is in the future, we show what is planned

    } else{
      
      if (didWorkout == null){
        return const CircularProgressIndicator();
      }
      // if in the past, check if they completed a workout that day
      if (didWorkout!.contains(normalizeDay(day))){
        ////debugPrint("found it");
        return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[700],
            // borderRadius: const BorderRadius.all(
            //   Radius.circular(16.0),
            // ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
      );
      }

      return null;
    }
    var events = getWorkoutForDay(day: day, context: realContext);
  
    //DateTime origin = DateTime(2024, 1, 7);
    
    if (events.isNotEmpty){
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Container(
          decoration: BoxDecoration(
            color: isFuture
              ? Color(realContext.watch<Profile>().split[events[0].index].dayColor)
              : Colors.red,
            // borderRadius: const BorderRadius.all(
            //   Radius.circular(16.0),
            // ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
      );
    }
    
    return null;
  }
}