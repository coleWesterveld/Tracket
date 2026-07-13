import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:firstapp/other_utilities/timespan.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';


class ExerciseProgressChart extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final ThemeData theme;
  final Timespan selectedTimespan;
  final ValueChanged<Timespan>? onTimespanChanged;
  final bool useMetric;

  // For long timespans we will drop some data to make the chart less busy
  // I wont do this by default but will give the option to
  // Ill let -1 mean to do it automatically based on the number of records
  final int? decimationFactor;


  const ExerciseProgressChart({
    super.key, 
    required this.exercise,
    required this.theme,
    required this.selectedTimespan,
    this.onTimespanChanged,
    this.decimationFactor,
    this.useMetric = false
  });

  @override
  _ExerciseProgressChartState createState() => _ExerciseProgressChartState();
}

class _ExerciseProgressChartState extends State<ExerciseProgressChart> {
  List<FlSpot> _dataPoints = [];
  List<String> _dates = [];
  List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(ExerciseProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimespan != widget.selectedTimespan) {
      // Refresh data when timespan changes
      _fetchData(); 
    }
  }

    Future<void> _fetchData() async {
    final dbHelper = DatabaseHelper.instance;
    
    // 1. Get the start date for the selected timespan
    final startDate = getStartDateForTimespan(widget.selectedTimespan);

    // 2. Fetch the data using the new query
    // The query already filters by date and groups by session to get the max e1RM
    final sessionData = await dbHelper.fetchSessionMaxE1RM(
      exerciseId: widget.exercise['exercise_id'],
      startDate: startDate,
    );

    List<FlSpot> points = [];
    List<String> dates = [];
    List<String> years = [];

    if (sessionData.isEmpty) {
      setState(() {
        _dataPoints = [];
        _dates = [];
        _years = [];
      });
      return;
    }

    // 3. Process the results from the query
    // sessionData now contains one entry per session, ordered chronologically
    for (int i = 0; i < sessionData.length; i++) {
      final record = sessionData[i];
      DateTime date = DateTime.parse(record['date']);
      double e1rmPounds = record['max_e1rm_pounds'] as double;

      // Convert e1RM to kilograms if metric is used for display
      double displayE1RM = widget.useMetric ? lbToKg(pounds: e1rmPounds) : e1rmPounds;

      // Add the data point. X value is simply the index since data is chronological.
      points.add(FlSpot(i.toDouble(), displayE1RM));

      // Format date and year for labels
      dates.add(DateFormat('MMM d').format(date));
      years.add(DateFormat('yyyy').format(date));
    }

    // 4. Apply decimation logic if needed (this part remains similar)
    if (widget.decimationFactor != null) {
      int factor = widget.decimationFactor!;
      if (widget.decimationFactor == -1) {
        // Adjust auto-decimation factor based on the number of sessions
        if (points.length <= 50) {
          factor = 1; // No decimation needed for 50 or fewer points
        } else {
          factor = points.length ~/ 50; // Aim for roughly 50 points
        }
      }

      List<FlSpot> newPoints = [];
      List<String> newDates = [];
      List<String> newYears = [];
      
      // Reindex the x values to be continuous after decimation
      int newIndex = 0;
      for (int i = 0; i < points.length; i += factor) {
        newPoints.add(FlSpot(newIndex.toDouble(), points[i].y)); // Use newIndex as the new x
        newDates.add(dates[i]);
        newYears.add(years[i]);
        newIndex++;
      }

      points = newPoints;
      dates = newDates;
      years = newYears;
    }

    // 5. Update the state
    setState(() {
      _dataPoints = points;
      _dates = dates;
      _years = years;
    });
  }

  @override
  Widget build(BuildContext context) {
    //final settings = context.read<SettingsModel>();
    ////debugPrint("datapoints.length: ${_dataPoints}");
    return _dataPoints.isEmpty
        ? const Center(child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "No history found for this exercise."
            ),
        ))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  widget.exercise['exercise_title'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    //duration: Duration.zero,

                    LineChartData(


                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          
                          sideTitles: SideTitles(
                            minIncluded: false,
                            maxIncluded: false,
                            showTitles: true,
                            reservedSize: 40, // Space for label
                          ),
                          
                          axisNameSize: 22, // Adjust spacing for clarity
                        ),

                        leftTitles: AxisTitles(
                          
                          sideTitles: const SideTitles(
                            minIncluded: false,
                            maxIncluded: false,
                            showTitles: true,
                            reservedSize: 40, // Space for label
                          ),
                          axisNameWidget: Text(
                            'Predicted 1RM ${widget.useMetric ? '(kg)' : '(lb)'}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          axisNameSize: 22, // Adjust spacing for clarity
                        ),

                        topTitles: AxisTitles(
                          sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _dates.length) {
                                // Show year only if it's the first point or year changed
                                if (index == 0 || 
                                    (index > 0 && _years[index] != _years[index - 1])) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(_years[index]),
                                  );
                                }
                              }
                              return const SizedBox.shrink(); // Hide other labels
                            },
                            interval: 1,
                        ),
                        ),
                        

                        bottomTitles: AxisTitles(

                          sideTitles: SideTitles(
                          reservedSize: 50,
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index < 0 || index >= _dates.length) return const SizedBox.shrink();

                            // Show at most 4 evenly-spaced labels to avoid overlap
                            final int maxLabels = _dataPoints.length < 4 ? _dataPoints.length : 4;
                            final int step = _dataPoints.length < 4 ? 1 : (_dataPoints.length / maxLabels).ceil();

                            if (index % step != 0) return const SizedBox.shrink();

                            return SideTitleWidget(
                              meta: meta,
                              child: Transform.rotate(
                                angle: -pi / 4,
                                child: Text(_dates[index], style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                          interval: 1, // Keep interval 1 so the graph still renders all points
                        ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index >= 0 && index < _dates.length) {
                                return LineTooltipItem(
                                  '${spot.y.toStringAsFixed(1)} ${widget.useMetric ? 'kg' : 'lb'}\n${(_dates[index])} ${_years[index]}',
                                  const TextStyle(color: Colors.white),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      gridData: const FlGridData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _dataPoints,
                          isCurved: false,
                          color: Colors.blue,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text(
                      "Timespan: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14
                      )
                    ),

                    DropdownButton<Timespan>(
                        value: widget.selectedTimespan,
                        onChanged: (Timespan? newValue) {
                          if (newValue != null) {
                            // This assumes you'll handle the state change in parent widget
                            // If managing state here, you'd use setState instead
                            widget.onTimespanChanged?.call(newValue);
                          }
                        },
                        items: Timespan.values.map((Timespan timespan) {
                          return DropdownMenuItem<Timespan>(
                            value: timespan,
                            child: Text(
                              timespan.displayName,
                              style: TextStyle(
                                color: widget.theme.colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ],
            ),
          );
  }
}
