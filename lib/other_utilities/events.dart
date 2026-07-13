// Some helpers to load events (workouts) for the calendar

import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firstapp/other_utilities/days_between.dart';


class Event{
  final String title;
  final int index;
  final TimeOfDay? time;
  Event(this.title, this.index, this.time);

  @override
  String toString() {
    return 'event{title: $title, index: $index, time: $time';
  }
}

// Given a specific date and program start day, this function will find the workout, if any, for a specific day
// from the split in the program provider
List<Event> getWorkoutForDay ({required DateTime day, required BuildContext context, DateTime? startDay}){
  // startday should be provider origin if not provided
  startDay = context.read<Profile>().origin;

  for (var splitDay = 0; splitDay < context.read<Profile>().split.length; splitDay ++){
    final programDay = context.read<Profile>().split[splitDay];
    if (programDay.isTemporary) continue; // skip free workout days

    if (daysBetween(startDay , day) % context.read<Profile>().splitLength == programDay.dayOrder) {
      return [
        Event(
          programDay.dayTitle,
          splitDay,
          programDay.workoutTime,
        )
      ];
    }
  }
  return [];
}
  