// Display a single set in a program, usually within dropdown day

/*
Todo here: 
we probably only need one TEC for each field, not 3 for each set
since only one at a time is editable

also, the text fields are not well labelled, its hard to tell what youre inputting

done button is not working as intended
*/

import 'package:firstapp/other_utilities/decimal_input_formatter.dart';
import 'package:firstapp/other_utilities/format_reps.dart';
import 'package:firstapp/other_utilities/keyboard_config.dart';
import 'package:flutter/material.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:provider/provider.dart';

import 'package:firstapp/providers_and_settings/program_provider.dart';
import 'package:collection/collection.dart';


class DisplaySet extends StatefulWidget {
  const DisplaySet({
    super.key,
    required this.index,
    required this.exerciseIndex,
    required this.setIndex,
    required this.theme,
  });

  final int index;
  final int exerciseIndex;
  final int setIndex;
  final ThemeData theme;


  @override
  State<DisplaySet> createState() => _DisplaySetState();
}

class _DisplaySetState extends State<DisplaySet> {
  late TextEditingController _setsController;
  late TextEditingController _rpeController;
  late TextEditingController _repsLowerController;
  late TextEditingController _repsUpperController;

  final Function listEquals = const ListEquality().equals;
  final _focusNodes = List.generate(4, (_) => FocusNode());

  // Rep target can be a RANGE (5-8) or a single EXACT number (3). There's no
  // separate DB column for this — "exact" simply means setLower == setUpper (#7).
  bool _exactReps = false;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<Profile>(context, listen: false);
    final setData = profile.sets[widget.index][widget.exerciseIndex][widget.setIndex];

    _exactReps = setData.setLower == setData.setUpper;

    _setsController = TextEditingController(text: setData.numSets.toString());
    _rpeController = TextEditingController(text: setData.rpe.toString());
    _repsLowerController = TextEditingController(text: setData.setLower.toString());
    _repsUpperController = TextEditingController(text: setData.setUpper.toString());
  }

  @override
  void dispose() {
    _setsController.dispose();
    _rpeController.dispose();
    _repsLowerController.dispose();
    _repsUpperController.dispose();
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _saveSet() {
    context.read<Profile>().editIndex = [-1, -1, -1];

    final int lower = int.tryParse(_repsLowerController.text) ?? 0;
    // In "exact" mode there is only one field — persist it as lower == upper (#7)
    final int upper =
        _exactReps ? lower : (int.tryParse(_repsUpperController.text) ?? 0);

    final profile = Provider.of<Profile>(context, listen: false);
    profile.setsAssign(
      index1: widget.index,
      index2: widget.exerciseIndex,
      index3: widget.setIndex,
      data: profile.sets[widget.index][widget.exerciseIndex][widget.setIndex].copyWith(
        newNumSets: int.tryParse(_setsController.text) ?? 0,
        newRpe: double.tryParse(_rpeController.text) ?? 0,
        newSetLower: lower,
        newSetUpper: upper,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (
          listEquals(
            context.watch<Profile>().editIndex,
            [widget.index, widget.exerciseIndex, widget.setIndex]
          )
        )
          Container(
            color: widget.theme.colorScheme.surfaceContainerHighest,
            width: MediaQuery.sizeOf(context).width - 48,
            height: 66,
            child: KeyboardActions(
              config: buildKeyboardActionsConfig(context, widget.theme, _focusNodes),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Sets"),
                        SetTextField(
                          controller: _setsController, 
                          focusNode: _focusNodes[0],
                          hint: 'Sets', 
                          maxWidth: 50
                        ),
                      ],
                    ),
                    const Spacer(flex: 1),
                    // const Text('x'),
                    // const Spacer(flex: 1),
                
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tapping the label flips between a rep RANGE and a single
                        // EXACT number. Doing it on the label keeps the toggle inside
                        // the existing 66px edit row (no space for a SegmentedButton).
                        InkWell(
                          onTap: () => setState(() {
                            _exactReps = !_exactReps;
                            if (_exactReps) {
                              // collapsing a range -> keep the lower bound as the target
                              _repsUpperController.text = _repsLowerController.text;
                            }
                          }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_exactReps ? "Exact Reps" : "Rep Range"),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.swap_horiz,
                                size: 16,
                                color: widget.theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SetTextField(
                              controller: _repsLowerController,
                              focusNode: _focusNodes[1],
                              hint: 'Reps',
                              maxWidth: 50
                            ),
                            if (!_exactReps) ...[
                              const SizedBox(width: 8),
                              const Text("-"),
                              const SizedBox(width: 8),
                              SetTextField(
                                controller: _repsUpperController,
                                focusNode: _focusNodes[2],
                                hint: 'Reps',
                                maxWidth: 50
                              ),
                            ],
                          ],
                        ),

                      ],
                    ),
                
                    const Spacer(flex: 1),
                    
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("RPE"),
                        SetTextField(
                          controller: _rpeController, 
                          focusNode: _focusNodes[3],
                          hint: 'RPE', 
                          maxWidth: 50,
                          isRPE: true, // Mark this as RPE field for 0-10 validation
                        ),
                      ],
                    ),
                
                    const Spacer(flex: 10),
                
                    IconButton(
                      onPressed: _saveSet,
                      icon: Icon(
                        Icons.check, 
                        color: widget.theme.colorScheme.secondary
                      ),
                      
                      padding: const EdgeInsets.all(0.0),
                
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all<OutlinedBorder>(
                          const CircleBorder(), 
                        ),
                
                        minimumSize: WidgetStateProperty.all<Size>(
                          const Size(32, 32), 
                        ),
                
                        side: WidgetStateProperty.all<BorderSide>(
                          BorderSide(
                            color: widget.theme.colorScheme.secondary,
                            width: 2.0,
                          ),
                        ),
                      ),                  
                    )
                  ],
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => context.read<Profile>().editIndex = [
              widget.index, 
              widget.exerciseIndex, 
              widget.setIndex
            ],

            child: AbsorbPointer(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 48,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final setData = context
                              .watch<Profile>()
                              .sets[widget.index][widget.exerciseIndex][widget.setIndex];
                          // formatRepRange collapses lower==upper to a single number (#7)
                          return Text(
                            '${setData.numSets} sets x '
                            '${formatRepRange(setData.setLower, setData.setUpper)} reps'
                            ' @ RPE ${setData.rpe}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Simplified SetTextField
class SetTextField extends StatelessWidget {
  const SetTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxWidth,
    required this.focusNode,
    this.isRPE = false, // Flag to identify RPE field
  });

  final TextEditingController controller;
  final String hint;
  final double maxWidth;
  final FocusNode focusNode;
  final bool isRPE;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: TextFormField(
        selectAllOnFocus: true,
        textInputAction: TextInputAction.next,
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // Use RPE formatter for RPE field (0-10 range), otherwise one decimal formatter
          isRPE ? RPEInputFormatter() : OneDecimalTextInputFormatter()
        ],
        decoration: InputDecoration(
          filled: true,
          contentPadding: const EdgeInsets.only(bottom: 10, left: 8),
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 30),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          hintText: hint,
        ),
      ),
    );
  }
}
