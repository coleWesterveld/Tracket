import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';                                 // For Slider
import 'package:flutter/services.dart';                                  // Haptics

import 'package:firstapp/providers_and_settings/program_provider.dart';  // Access Program Details
import 'package:firstapp/providers_and_settings/settings_provider.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PopUpDayEditor extends StatefulWidget {
  const PopUpDayEditor({
    super.key,
    required this.theme,
    required this.index,
    required this.titleTEC,
    required this.equipmentTEC, // Add equipment controller
  });

  final ThemeData theme;
  final int index;
  final TextEditingController titleTEC;
  final TextEditingController equipmentTEC;

  @override
  State<PopUpDayEditor> createState() => _PopUpDayEditorState();
}

class _PopUpDayEditorState extends State<PopUpDayEditor> {
  // For day-editor slider - false is editing title/equipment, true is editing colour
  bool? _sliding = false;

  // NOTE: the manual TextSelection-on-first-frame block that used to live in
  // initState is gone — both fields now use `selectAllOnFocus: true`, which is
  // the app's standard pattern (see display_set.dart) and handles this natively.

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: CupertinoSlidingSegmentedControl(
        padding: const EdgeInsets.all(4.0),
        children: const <bool, Text>{
          false: Text("Details"),
          true: Text("Color"),
        }, 
        onValueChanged: (bool? newValue) {
          setState(() {
            _sliding = newValue;
          });                       
        },
        thumbColor: widget.theme.colorScheme.secondary,
        groupValue: _sliding,
      ),
      content: editBuilder(widget.index, widget.theme, widget.titleTEC, widget.equipmentTEC),
      actions: [
        IconButton(
          onPressed: () {
            if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
            
            if (widget.titleTEC.text.isNotEmpty) {
              Provider.of<Profile>(context, listen: false).splitAssign(
                index: widget.index, 
                newDay: context.read<Profile>().split[widget.index].copyWith(
                  newDayTitle: widget.titleTEC.text,
                  newGear: widget.equipmentTEC.text,
                ),
                context: context
              );
            }
            Navigator.of(context, rootNavigator: true).pop('dialog');
            _sliding = false;
          },
          icon: const Icon(Icons.check)
        )
      ]
    );
  }

  Widget editBuilder(int index, ThemeData theme, TextEditingController titleTEC, TextEditingController equipmentTEC) { 
    if (_sliding == false) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day Title Field
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                selectAllOnFocus: true,
                maxLength: 50,
                onFieldSubmitted: (value) {
                  if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                  Navigator.of(context).pop(widget.titleTEC.text);
                },
                autofocus: true,
                controller: titleTEC,
                decoration: InputDecoration(
                  //counterText: "${titleTEC.text.length}/200",
                  labelText: "Workout Title",
                  suffixIcon: IconButton(
                    onPressed: titleTEC.clear,
                    icon: const Icon(Icons.highlight_remove),
                  ),
                  hintText: "e.g. Upper Body",
                ),
              ),
            ),
            
            // Equipment Field
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(

                selectAllOnFocus: true,
                onFieldSubmitted: (value) {
                  if (context.read<SettingsModel>().hapticsEnabled) HapticFeedback.heavyImpact();
                  Navigator.of(context).pop();
                },
                maxLength: 200,
                controller: equipmentTEC,
                maxLines: 2, // Allow multiple lines for equipment
                decoration: InputDecoration(
                  //counterText: "${equipmentTEC.text.length}/200",
                  labelText: "Equipment to Bring",
                  suffixIcon: IconButton(
                    onPressed: equipmentTEC.clear,
                    icon: const Icon(Icons.highlight_remove),
                  ),
                  hintText: "e.g. Belt, Straps, Chalk...",
                ),
              ),
            ),
            
            // Help text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "List all equipment you'll need for this workout",
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: 250,
        width: 300,
        child: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Color(context.watch<Profile>().split[index].dayColor),
            onColorChanged: (Color color) {
              context.read<Profile>().splitAssign(
                index: index,
                newDay: context.read<Profile>().split[index].copyWith(newDayColor: color.toARGB32()),
                context: context
              );
            },
            availableColors: Profile.colors,
            layoutBuilder: pickerLayoutBuilder,
            itemBuilder: pickerItemBuilder,
          ),
        ),
      );
    }
  }

  Widget pickerItemBuilder(Color color, bool isCurrentColor, void Function() changeColor) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((255 * 0.8).round()), 
            offset: const Offset(1, 2), 
            blurRadius: 0.0)
          ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: changeColor,
          borderRadius: BorderRadius.circular(8.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isCurrentColor ? 1 : 0,
            child: Icon(
              Icons.done,
              size: 36,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget pickerLayoutBuilder(BuildContext context, List<Color> colors, PickerItem child) {
    Orientation orientation = MediaQuery.of(context).orientation;
    return SizedBox(
      width: 300,
      height: orientation == Orientation.portrait ? 360 : 240,
      child: GridView.count(
        crossAxisCount: orientation == Orientation.portrait ? 5 : 4,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        children: [for (Color color in colors) child(color)],
      ),
    );
  }
}