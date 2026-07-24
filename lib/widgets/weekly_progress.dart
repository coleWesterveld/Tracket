import 'package:firstapp/other_utilities/format_weekday.dart';
import 'package:firstapp/widgets/progress_tick.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';
import 'package:firstapp/providers_and_settings/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../database/database_helper.dart'; // Adjust this import as needed
import '../providers_and_settings/program_provider.dart';
import '../database/profile.dart';
import '../other_utilities/lightness.dart';

class PageViewWithIndicator extends StatefulWidget {
  final Function(Exercise) onSelected;
  final ThemeData theme;

  const PageViewWithIndicator({
    super.key,
    required this.onSelected,
    required this.theme,
  });

  @override
  _PageViewWithIndicatorState createState() => _PageViewWithIndicatorState();
}

class _PageViewWithIndicatorState extends State<PageViewWithIndicator> {
  final PageController _pageController = PageController();
  List<DateTime?>? recentWorkoutDates;
  late Profile profile;

  @override
  void initState() { 

    super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
      profile = Provider.of<Profile>(context, listen: false);
      _loadDates();
      profile.addListener(_loadDates);
    });
  }

  @override
  void dispose() {
    profile.removeListener(_loadDates);
    super.dispose();
  }

  void _loadDates() async {
    recentWorkoutDates = await context.read<Profile>().getRecentWorkoutDates();
    setState(() {});
  }

  // A PageView forces one shared height across all pages, so we size it to the
  // TALLEST day (the one with the most exercises) rather than a hardcoded box that
  // clipped longer days (#14). Past the cap, a day's list scrolls internally.
  static const double _rowHeight = 30.0;        // one ExerciseProgressRow
  static const double _dayHeaderHeight = 44.0;  // title row + spacer
  static const double _dayChrome = 24.0;        // card padding + margins
  static const double _minPageHeight = 180.0;
  static const double _maxPageHeight = 460.0;   // sane cap so it can't grow unbounded

  double _pageHeightFor(List<List<Exercise>> exercisesPerDay, int dayCount) {
    int mostExercises = 0;
    for (int i = 0; i < dayCount && i < exercisesPerDay.length; i++) {
      if (exercisesPerDay[i].length > mostExercises) {
        mostExercises = exercisesPerDay[i].length;
      }
    }
    final double needed =
        _dayHeaderHeight + _dayChrome + (mostExercises * _rowHeight);
    return needed.clamp(_minPageHeight, _maxPageHeight);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<Profile>();
    final days = profile.split;
    final exercisesPerDay = profile.exercises;

    final double pageHeight = _pageHeightFor(exercisesPerDay, days.length);

    return Column(
      // Self-sizing so the enclosing "Last 7 Days" card grows to fit (#14)
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: pageHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: days.length,
            itemBuilder: (context, index) {
              return DayProgress(
                index: index,
                day: days[index],
                exercises: exercisesPerDay[index],
                onSelected: widget.onSelected,
                theme: widget.theme,
                date: recentWorkoutDates?[index],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SmoothPageIndicator(
            controller: _pageController,
            count: days.length,
            effect: const ExpandingDotsEffect(
              dotHeight: 8.0,
              dotWidth: 8.0,
              activeDotColor: Colors.blue,
              dotColor: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// DayProgress widget – one page that shows a day’s title and the list of exercises for that day.
class DayProgress extends StatefulWidget {
  final int index;
  final Day day;
  final List<Exercise> exercises;
  final Function(Exercise) onSelected;
  final ThemeData theme;
  final DateTime? date;

  const DayProgress({
    super.key,
    required this.index,
    required this.day,
    required this.exercises,
    required this.onSelected,
    required this.theme,
    required this.date
  });

  @override
  State<DayProgress> createState() => _DayProgressState();
}

class _DayProgressState extends State<DayProgress> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: widget.theme.colorScheme.outline, width: 0.5),
          borderRadius: BorderRadius.circular(16),
          color: widget.theme.colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: widget.theme.colorScheme.shadow,
              offset: const Offset(2, 2),
              blurRadius: 4.0,
            ),
          ]
        ),
        // No fixed 200x200 box — the page fills the shared height computed by
        // PageViewWithIndicator, so longer days are no longer clipped (#14).
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with day title and date (for now, still a mock date)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                    ),
                    child: Text(
                      widget.day.dayTitle,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      maxLines: 2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.date != null)
                    Text(formatDateShort(widget.date!))
                  

                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.exercises.length,
                  itemBuilder: (context, exerciseIndex) {
                    final exercise = widget.exercises[exerciseIndex];
                    return ExerciseProgressRow(
                      exercise: exercise,
                      onSelected: widget.onSelected,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The widget that shows progress for a single exercise by reading data from the database.
class ExerciseProgressRow extends StatefulWidget {
  final Exercise exercise;
  final Function(Exercise) onSelected;
  const ExerciseProgressRow({
    super.key, 
    required this.exercise,
    required this.onSelected
  });

  @override
  _ExerciseProgressRowState createState() => _ExerciseProgressRowState();
}
class _ExerciseProgressRowState extends State<ExerciseProgressRow> {
  late Future<Map<String, dynamic>?> _progressFuture;


  @override
  void initState() {
    super.initState();
    _progressFuture = fetchProgress();
  }

  /// Fetch progress from the database:
  /// - Look up all set_log records for the given exercise.
  /// - Find the most recent record within the last 7 days and the most recent record older than 7 days.
  Future<Map<String, dynamic>?> fetchProgress() async {
    final records = await DatabaseHelper.instance
        .fetchAllSetRecords(exerciseId: widget.exercise.exerciseID); // using exercise id
    if (records.isEmpty) return null;

    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
    Map<String, dynamic>? recentRecord;
    Map<String, dynamic>? previousRecord;

    // Records are ordered descending (newest first)
    for (var record in records) {
      DateTime recordDate = DateTime.parse(record['date']);
      if ((recordDate.isAfter(sevenDaysAgo) || recordDate.isAtSameMomentAs(sevenDaysAgo)) &&
          recentRecord == null) {
        recentRecord = record;
      } else if (recordDate.isBefore(sevenDaysAgo) && previousRecord == null) {
        previousRecord = record;
      }
      if (recentRecord != null && previousRecord != null) break;
    }

    if (recentRecord != null) {
      return {
        'recent': recentRecord,
        'previous': previousRecord, // might be null if not found
      };
    }
    return null;
  }

  /// Returns a widget representing the change as an arrow icon and text.
  /// Shared with the finish summary so both read the same way.
  Widget buildTick(double diff, String unit) =>
      ProgressTick(diff: diff, unit: unit);

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsModel>();
    return GestureDetector(
      onTap: (){
        widget.onSelected(widget.exercise);
      },
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _progressFuture,
        builder: (context, snapshot) {
          Widget progressIndicator;
          if (snapshot.connectionState == ConnectionState.waiting) {
            progressIndicator = const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            // If no record in the last 7 days, show "- same"
            progressIndicator = const ProgressTickSame();
          } else {
            final recent = snapshot.data!['recent'];
            final previous = snapshot.data!['previous'];
      
            double recentWeight = recent['weight'];
            double recentReps = recent['reps'];
      
            double diffWeight = 0;
            double diffReps = 0;
            if (previous != null) {
              double previousWeight = previous['weight'];
              double previousReps = previous['reps'];
              diffWeight = recentWeight - previousWeight;
              if (settings.useMetric){
                diffWeight = lbToKg(pounds: diffWeight);
              }

              diffReps = recentReps - previousReps;
            }
      
            List<Widget> changes = [];
            if (diffWeight != 0) {
              changes.add(buildTick(diffWeight, settings.useMetric ? 'kg' : 'lb'));
            }
            if (diffReps != 0) {
              changes.add(buildTick(diffReps, "rep"));
            }
      
            if (changes.isEmpty) {
              progressIndicator = const ProgressTickSame();
            } else {
              progressIndicator = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...changes.map((w) => Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: w,
                      )),
                ],
              );
            }
          }
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: lighten(const Color(0xFF1e2025), 30),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Exercise title on the left
                  Expanded(
                    child: Text(
                      widget.exercise.exerciseTitle,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  // Progress indicator (tick icons and text)
                  progressIndicator,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
