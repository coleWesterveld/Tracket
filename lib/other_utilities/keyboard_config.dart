import 'package:keyboard_actions/keyboard_actions.dart';
import "package:flutter/material.dart";


/// The bar that sits above the keyboard for numeric fields, which on iOS have
/// no return key of their own and so otherwise offer no way out.
///
/// Pass every field the user should be able to step through in ONE call. Two
/// things depend on that:
///
///  * The chevrons walk [nodes] in order. A config built from a single node has
///    nowhere to step, so its arrows sit permanently greyed out.
///  * One config across a whole group means the bar stays put when focus moves
///    between its fields. Separate configs each own their own bar, so every
///    focus change fades one out and another in and the keyboard visibly dips.
KeyboardActionsConfig buildKeyboardActionsConfig(BuildContext context, ThemeData theme, List<FocusNode> nodes) {
  return KeyboardActionsConfig(
    keyboardBarColor: theme.colorScheme.surface,
    keyboardSeparatorColor: theme.colorScheme.outlineVariant,
    keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
    // The package's own arrows point up and down, which reads wrong for fields
    // laid out left to right. Ours are in the toolbar below instead.
    nextFocus: false,
    actions: List.generate(nodes.length, (i) {
      return KeyboardActionsItem(
        focusNode: nodes[i],
        displayArrows: false,
        toolbarButtons: [
          (node) => Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: "Previous field",
                      color: theme.colorScheme.onSurface,
                      disabledColor: theme.disabledColor,
                      onPressed: i > 0 ? () => nodes[i - 1].requestFocus() : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: "Next field",
                      color: theme.colorScheme.onSurface,
                      disabledColor: theme.disabledColor,
                      onPressed: i < nodes.length - 1 ? () => nodes[i + 1].requestFocus() : null,
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                      onPressed: () => node.unfocus(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
        ],
      );
    }),
  );
}
