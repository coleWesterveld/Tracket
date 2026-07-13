
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

class RestDay extends StatelessWidget {
  const  RestDay({super.key, 
    //super.key,
    required this.isActive,
    required this.index,
    required this.startDay,
    required this.theme,
  });

  final bool isActive;
  final int index;
  final int startDay;
  final ThemeData theme;

  static List<String> daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: DottedBorder(
        strokeWidth: 2,
        // [strokelength, spacelength]
        dashPattern: const [15, 10],
        borderType: BorderType.RRect, // Rounded rectangle border
        radius: const Radius.circular(12),
        
        color: isActive 
          ? theme.colorScheme.primaryContainer 
          : theme.colorScheme.outline,
        
        
        child: Container(
        height: 56,
        width: double.infinity,
        
        decoration: BoxDecoration(
          color: isActive 
            ? theme.colorScheme.primary
            : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          //border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  topLeft: Radius.circular(12),
                ),

                // border: Border(
                //   right: BorderSide(
                //     color: Colors.grey,
                //     width: 2.0,
                //   ),
                // ),

                color: theme.colorScheme.surface,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                     
                      daysOfWeek[(index + startDay) % 7],
                      style: const TextStyle(
                        height: 1.0,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    Text(
                     
                      "${index + 1}",
                    
                      style: const TextStyle(
                        height: 1.0,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        //color: lighten(const Color(0xFF1e2025), 60)
                      ),
                    ),
                  ],
                )
              ),

            ),

            Expanded(
              //width: double.infinity,
              child: Center(
                //alignment: Alignment.center,
                child: Container(
                  child: const Text(
                    "Rest Day",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  )
                ),
              ),
            ),
            
          ],
        ),
      ),
      ),
    );
  }
}