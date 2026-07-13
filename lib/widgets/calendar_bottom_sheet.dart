// A small glimpse of what a week of a program might look like
// for easy view at bottom while creating a program

// TODO: location of days in week is not accurate - based on old system

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details
import 'package:table_calendar/table_calendar.dart';
import 'package:firstapp/other_utilities/events.dart';
import 'package:firstapp/schedule_page/edit_schedule.dart';


class CalendarBottomSheet extends StatefulWidget {
  const CalendarBottomSheet({
    super.key,
    required this.today,
    required this.theme,
  });


  final DateTime today;
  final ThemeData theme;

  @override
  State<CalendarBottomSheet> createState() => _CalendarBottomSheetState();
}

class _CalendarBottomSheetState extends State<CalendarBottomSheet> {

  @override
  Widget build(BuildContext context) {
    final profile = context.read<Profile>();

    return GestureDetector(

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              //context.read<UiStateProvider>().customAppBarTitle = "Edit Schedule";
              return EditSchedule(
                theme: widget.theme
              );
            }
          )
        );
      },
      child: Container(
        
        padding: const EdgeInsets.all(8.0),
        height: 82.5,

        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: widget.theme.colorScheme.outline,
              width: 0.5,
            ),
          ),
        ),
      
        child: TableCalendar(

          // This is kinda a strange solution but what happens is that the day absorbs the pointer from the gesture detector
          // so we just make it do the same thing! I want to detect taps BUT not absorb swipes
          onDaySelected: (_, __) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EditSchedule(
                      theme: widget.theme
                    ),
              )
            );
          },

          focusedDay: DateTime.now(),
          headerVisible: false,
          calendarFormat: CalendarFormat.week,
      
          calendarBuilders: CalendarBuilders(
            
      
            // Builds a single day
          outsideBuilder: (ctx, day, focusedDay) => _buildDay(ctx, day, focusedDay, profile),
      
      
      
      
          defaultBuilder: (ctx, day, focusedDay) => _buildDay(ctx, day, focusedDay, profile),

          todayBuilder: (ctx, day, focusedDay) => _buildDay(ctx, day, focusedDay, profile),
      
          ),
          rowHeight: 50,
          firstDay: DateTime.utc(2010, 10, 16), 
          lastDay: DateTime.utc(2030, 3, 14),
          calendarStyle: CalendarStyle(
          
            todayDecoration: const BoxDecoration(
              //color: Colors.white,
              //borderRadius: BorderRadius.circular(14),
              shape: BoxShape.circle,
            ),
            //markerDecoration: const BoxDecoration(),
            defaultDecoration: const BoxDecoration(
              //color: Colors.white,
              //borderRadius: BorderRadius.circular(14),
              shape: BoxShape.circle,
            ),

            
            
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
              color: widget.theme.colorScheme.onPrimary, 
              fontWeight: FontWeight.bold,
            ),
      
            weekendTextStyle: TextStyle(color: widget.theme.colorScheme.onSurface)
      
          ),
      
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: widget.theme.colorScheme.onSurface),
            weekendStyle: TextStyle(color: widget.theme.colorScheme.onSurface),
          ),
      
        ),
      ),
    );
  }

  Widget? _buildDay(context, day, focusedDay, Profile profile) {
    var events = getWorkoutForDay(
      day: day, 
      context: context,
    );
  
    //DateTime origin = DateTime(2024, 1, 7);
    
    if (events.isNotEmpty){
      return  Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Color(profile.split[events[0].index].dayColor),
            // borderRadius: const BorderRadius.all(
            //   Radius.circular(12.0),
            // ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              "${profile.split[events[0].index].dayOrder + 1}",
              style: TextStyle(
                color: widget.theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w900
              ),
            ),
          ),
        ),
      );
    }
    
    return  Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            // borderRadius: const BorderRadius.all(
            //   Radius.circular(12.0),
            // ),
            shape: BoxShape.circle,
          ),
        ),
      );
  }
}
