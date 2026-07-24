import 'package:firstapp/other_utilities/decimal_input_formatter.dart';
import 'package:firstapp/other_utilities/format_reps.dart';
import 'package:firstapp/other_utilities/keyboard_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firstapp/providers_and_settings/program_provider.dart';
import '../providers_and_settings/settings_provider.dart';
import 'package:firstapp/widgets/shake_widget.dart';
import 'package:firstapp/providers_and_settings/active_workout_provider.dart';
import 'dart:async'; // For Timer
import 'package:keyboard_actions/keyboard_actions.dart';

// TODO: text field is selected at first by default
class GymSetRow extends StatefulWidget {
  final int repsLower;
  final int repsUpper;
  final double expectedRPE;
  final int exerciseIndex, setIndex;
  final Function(bool) onChanged;
  final bool? initiallyChecked;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController rpeController;
  final int? recordID;

  const GymSetRow({
    super.key,
    required this.repsLower,
    required this.repsUpper,
    required this.expectedRPE,
    required this.exerciseIndex,
    required this.setIndex,
    required this.onChanged,
    required this.repsController,
    required this.weightController,
    required this.rpeController,
    this.initiallyChecked,
    required this.recordID
  });

  @override
  GymSetRowState createState() => GymSetRowState();
}

class GymSetRowState extends State<GymSetRow> with SingleTickerProviderStateMixin {

  final FocusNode weightFocus = FocusNode();
  final FocusNode repsFocus = FocusNode();
  final FocusNode rpeFocus = FocusNode();

  bool _isChecked = false;
  bool _weightError = false;
  bool _repsError = false;
  bool _rpeError = false;
  bool _moveItmoveIt = false;

  // For detecting changes on focus loss
  String _initialWeightOnFocus = "";
  String _initialRepsOnFocus = "";
  String _initialRpeOnFocus = "";

  late AnimationController _saveAnimationController;
  String? _animatingFieldIdentifier; // 'weight', 'reps', or 'rpe'

  // For "Saved" confirmation
  String? _fieldJustSaved; // Will be 'weight', 'reps', or 'rpe'
  Timer? _saveConfirmationTimer;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.recordID != null;

    _saveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Total duration of the animation sequence
    );

    _saveAnimationController.addListener(() {
      if (mounted) {
        setState(() {}); // Trigger rebuilds to show animation frames
      }
    });

    _saveAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _animatingFieldIdentifier = null; // Clear after animation completes
          });
        }
      }
    });

    weightFocus.addListener(_onWeightFocusChange);
    repsFocus.addListener(_onRepsFocusChange);
    rpeFocus.addListener(_onRpeFocusChange);

  }


  @override
  void didUpdateWidget(GymSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordID != oldWidget.recordID) {
      setState(() {
        _isChecked = widget.recordID != null;
      });
    }
  }


  void _validateInputs() {
    setState(() {
      _weightError = widget.weightController.text.isEmpty || double.tryParse(widget.weightController.text) == null;
      _repsError = widget.repsController.text.isEmpty || double.tryParse(widget.repsController.text) == null;
      _rpeError = widget.rpeController.text.isEmpty || double.tryParse(widget.rpeController.text) == null;
    });

    if (_weightError || _repsError || _rpeError) {
      _moveItmoveIt = true;
    }
  }

  void _clearErrors() {
    setState(() {
      _weightError = false;
      _repsError = false;
      _rpeError = false;
    });
  }

  // track for save confirmations and user updating already logged set
  void _onWeightFocusChange() {
    if (weightFocus.hasFocus) {
      _initialWeightOnFocus = widget.weightController.text;
      if (_animatingFieldIdentifier == 'weight') _saveAnimationController.stop(); // Stop animation if re-focused
      setState(() => _animatingFieldIdentifier = null );
      
      // Auto-select all text when focused for easy overwriting
      if (widget.weightController.text.isNotEmpty) {
        widget.weightController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.weightController.text.length,
        );
      }
    } else {
      if (widget.recordID != null && widget.weightController.text != _initialWeightOnFocus) {
        _handleFieldUpdate('weight');
      }
    }
  }

  void _onRpeFocusChange() {
    if (rpeFocus.hasFocus) {
      _initialRpeOnFocus = widget.rpeController.text;
      if (_animatingFieldIdentifier == 'rpe') _saveAnimationController.stop();
      setState(() => _animatingFieldIdentifier = null );
      
      // Auto-select all text when focused for easy overwriting
      if (widget.rpeController.text.isNotEmpty) {
        widget.rpeController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.rpeController.text.length,
        );
      }
    } else {
      if (widget.recordID != null && widget.rpeController.text != _initialRpeOnFocus) {
        _handleFieldUpdate('rpe');
      }
    }
  }

  void _onRepsFocusChange() {
    if (repsFocus.hasFocus) {
      _initialRepsOnFocus = widget.repsController.text;
      if (_animatingFieldIdentifier == 'reps') _saveAnimationController.stop();
      setState(() => _animatingFieldIdentifier = null );
      
      // Auto-select all text when focused for easy overwriting
      if (widget.repsController.text.isNotEmpty) {
        widget.repsController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.repsController.text.length,
        );
      }
    } else {
      if (widget.recordID != null && widget.repsController.text != _initialRepsOnFocus) {
        _handleFieldUpdate('reps');
      }
    }
  }

  Future<void> _handleFieldUpdate(String fieldName) async {
    if (widget.recordID == null || _saveAnimationController.isAnimating && _animatingFieldIdentifier == fieldName) {
         return; // Don't update if no recordID or already animating this field
    }

    // Temporarily unfocus to prevent keyboard issues during animation (optional)
    // FocusScope.of(context).unfocus();
    // await Future.delayed(Duration(milliseconds: 50)); // Give time for keyboard to hide if unfocused

    _validateInputs();
    if (_weightError || _repsError || _rpeError) {
      //debugPrint("Validation error on update for field $fieldName, not saving.");

      // revert changes that cause an error. this is also paired with red and shake to indicate error.
      if (_weightError){
        widget.weightController.text = _initialWeightOnFocus;
      } else if (_repsError){
        widget.repsController.text = _initialRepsOnFocus;
      } else if (_rpeError){
        widget.rpeController.text = _initialRpeOnFocus;
      }

      return;
    }

    final profileProvider = context.read<Profile>();
    final double? weight = double.tryParse(widget.weightController.text);
    final double? reps = double.tryParse(widget.repsController.text);
    final double? rpe = double.tryParse(widget.rpeController.text);

    if (weight == null || reps == null || rpe == null) {
      //debugPrint("Error parsing values for update.");
      return;
    }

    bool success = await profileProvider.updateLoggedSet(
      recordID: widget.recordID!,
      fields: {'reps': reps, 'weight': weight, 'rpe': rpe},
    );

    if (success && mounted) {
      setState(() {
        _animatingFieldIdentifier = fieldName;
      });
      _saveAnimationController.reset();
      _saveAnimationController.forward();

      _initialWeightOnFocus = widget.weightController.text;
      _initialRepsOnFocus = widget.repsController.text;
      _initialRpeOnFocus = widget.rpeController.text;
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update set"), duration: Duration(seconds: 2)),
      );
    }
  }

  void _clearSavedConfirmation() {
    _saveConfirmationTimer?.cancel();
    if (_fieldJustSaved != null) {
      setState(() {
        _fieldJustSaved = null;
      });
    }
  }

  @override
  void dispose() {
    _saveAnimationController.dispose();
    weightFocus.removeListener(_onWeightFocusChange);
    repsFocus.removeListener(_onRepsFocusChange);
    rpeFocus.removeListener(_onRpeFocusChange);
    weightFocus.dispose();
    repsFocus.dispose();
    rpeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // debugPrint("${MediaQuery.sizeOf(context).width}");
    assert(context.read<ActiveWorkoutProvider>().sessionID != null, "SessionID is null");
    assert(context.read<ActiveWorkoutProvider>().activeDayIndex != null, "No active day index");
    assert(context.read<ActiveWorkoutProvider>().activeDay != null, "No active day");
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool smallScreen = screenWidth < 405;
    // displays horizontally fine for large screens, stacks vertically for smaller screens to prevent overflow
    // Field widths + their horizontal padding (8 each side = 16 total per field)
    // RPE: 35+16=51, Weight: 50+16=66, Reps: 40+16=56, Checkbox: 24+16=40
    if (!smallScreen){
      return ShakeWidget(
        shake: _moveItmoveIt,
        onAnimationComplete: () => _moveItmoveIt = false,
        child: Container(
          decoration: BoxDecoration(
            color: _isChecked ? Colors.blue.withAlpha(128) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // if (widget.setIndex == 0)
                //   Row(
                //     children: [
                //       const Expanded(child: SizedBox()),
                //       SizedBox(width: 51, child: Text("RPE", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                //       SizedBox(width: 66, child: Text("Weight", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                //       SizedBox(width: 56, child: Text("Reps", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                //       const SizedBox(width: 40),
                //     ],
                //   ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "${formatRepRange(widget.repsLower, widget.repsUpper)} reps @ ${widget.expectedRPE} RPE",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    _buildTextFieldWithConfirmation(
                      widget.rpeController,
                      rpeFocus,
                      "RPE",
                      35,
                      _rpeError,
                      "rpe",
                    ),

                    _buildTextFieldWithConfirmation(
                      widget.weightController,
                      weightFocus,
                      "Wt",
                      50,
                      _weightError,
                      "weight",
                    ),

                    _buildTextFieldWithConfirmation(
                      widget.repsController,
                      repsFocus,
                      "Reps",
                      40,
                      _repsError,
                      "reps",
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: InkWell(
                        onTap: () {
                          if (context.read<SettingsModel>().hapticsEnabled) {
                            HapticFeedback.heavyImpact();
                          }

                          // is not checked means now we are trying to save it
                          // we dont need to validate inputs when unsaving
                          if (!_isChecked){
                            WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
                            _validateInputs();
                            if (_weightError || _repsError || _rpeError) return;
                          }

                          _clearSavedConfirmation();

                          setState(() {
                            _isChecked = !_isChecked;
                            widget.onChanged(_isChecked);
                          });


                        },
                        child: Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isChecked ? Colors.blue : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: _isChecked
                              ? Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 16.0,
                                    color: _isChecked ? Colors.blue : Colors.grey,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

    } else {
      final double quarterWidth = (screenWidth - 8) / 4 - 32;
      final double halfWidth = (screenWidth - 8) / 2 - 32 - 24;
      return ShakeWidget(
        shake: _moveItmoveIt,
        onAnimationComplete: () => _moveItmoveIt = false,
        child: Container(
          decoration: BoxDecoration(
            color: _isChecked ? Colors.blue.withAlpha(128) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    "Target: ${formatRepRange(widget.repsLower, widget.repsUpper)} reps @ ${widget.expectedRPE} RPE",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Row(
                  // alignment: WrapAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      //   child: Text(
                      //     "${widget.repsLower}-${widget.repsUpper} reps @ ${widget.expectedRPE} RPE",
                      //     style: const TextStyle(fontSize: 16),
                      //   ),
                      // ),
                      _buildTextFieldWithConfirmation(
                        widget.rpeController,
                        rpeFocus,
                        "RPE",
                        quarterWidth,
                        _rpeError,
                        "rpe",
                      ),

                      _buildTextFieldWithConfirmation(
                        widget.weightController,
                        weightFocus,
                        "Weight",
                        halfWidth,
                        _weightError,
                        "weight",
                      ),

                      _buildTextFieldWithConfirmation(
                        widget.repsController,
                        repsFocus,
                        "Reps",
                        quarterWidth,
                        _repsError,
                        "reps",
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: InkWell(
                        onTap: () {
                          if (context.read<SettingsModel>().hapticsEnabled) {
                            HapticFeedback.heavyImpact();
                          }
                
                          // is not checked means now we are trying to save it
                          // we dont need to validate inputs when unsaving
                          if (!_isChecked){
                            WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
                            _validateInputs();
                            if (_weightError || _repsError || _rpeError) return;
                          }
                
                          _clearSavedConfirmation();
                
                          setState(() {
                            _isChecked = !_isChecked;
                            widget.onChanged(_isChecked);
                          });
                
                          
                        },
                        child: Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isChecked ? Colors.blue : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: _isChecked
                              ? Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 16.0,
                                    color: _isChecked ? Colors.blue : Colors.grey,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Divider(
                    thickness: 0.5,
                    height: 5,
                    color: Theme.of(context).colorScheme.outline,
                                ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // yeah atp this should maybe be made
   

  Widget _buildTextFieldWithConfirmation(
    TextEditingController controller,
    FocusNode focusNode,
    String hint,
    double width,
    bool hasError,
    String fieldIdentifier,
    ) {
    final bool amIAnimating = _animatingFieldIdentifier == fieldIdentifier;
    final double animValue = _saveAnimationController.value; // 0.0 to 1.0
    final theme = Theme.of(context);

    Color currentBgColor = hasError ? theme.colorScheme.errorContainer : theme.scaffoldBackgroundColor;
    double textOpacity = 1.0;
    double checkmarkOpacity = 0.0;

    if (amIAnimating) {
      // Animation phases:
      // 0.0 - 0.25: Fade text out, fade bg to green
      // 0.25 - 0.75: Show checkmark, bg green
      // 0.75 - 1.0: Fade checkmark out, fade text in, fade bg to normal
      if (animValue < 0.25) {
        textOpacity = 1.0 - (animValue / 0.25);
        currentBgColor = Color.lerp(currentBgColor, Colors.green.withOpacity(0.6), animValue / 0.25)!;
        checkmarkOpacity = animValue / 0.25; // Fade in checkmark with bg
      } else if (animValue < 0.75) {
        textOpacity = 0.0;
        currentBgColor = Colors.green.withOpacity(0.6);
        checkmarkOpacity = 1.0;
      } else {
        textOpacity = (animValue - 0.75) / 0.25;
        currentBgColor = Color.lerp(Colors.green.withOpacity(0.6), hasError ? theme.colorScheme.errorContainer : theme.colorScheme.surfaceContainerHighest.withAlpha(100), (animValue - 0.75) / 0.25)!;
        checkmarkOpacity = 1.0 - ((animValue - 0.75) / 0.25);
      }
      textOpacity = textOpacity.clamp(0.0, 1.0);
      checkmarkOpacity = checkmarkOpacity.clamp(0.0, 1.0);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        width: width,
        // height: 30,
        child: Stack(
              alignment: Alignment.center,
            
              children: [
                KeyboardActions(
                  disableScroll: true,
                  config: buildKeyboardActionsConfig(context, theme, [focusNode]),
                  child: TextFormField(
                    selectAllOnFocus: true,
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  
                    style: TextStyle(
                      fontSize: 14,
                      color: (theme.textTheme.bodyLarge?.color ?? Colors.black).withOpacity(textOpacity),
                    ),
                  
                    inputFormatters: [
                      // Use RPE-specific formatter for RPE field (0-10 range)
                      // Use generic one-decimal formatter for weight and reps
                      fieldIdentifier == "rpe" 
                        ? RPEInputFormatter()
                        : OneDecimalTextInputFormatter()
                    ],
                    decoration: InputDecoration(
                      
                      filled: true,
                      fillColor: hasError ? Colors.red.withAlpha(64) : currentBgColor,
                      contentPadding: const EdgeInsets.only(bottom: 10, left: 8),
                      constraints: BoxConstraints(
                        maxWidth: width,
                        maxHeight: 30,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      hintText: hint,
                      errorStyle: const TextStyle(height: 0),
                    ),
                    onChanged: (value) => _clearErrors(),
                  ),
                ),
            
                // Checkmark overlay
              if (checkmarkOpacity > 0) // Only build if visible or fading
                IgnorePointer( // Checkmark should not be interactive
                  child: Opacity(
                    opacity: checkmarkOpacity,
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white.withOpacity(0.9), // White checkmark, slightly transparent for blending
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}