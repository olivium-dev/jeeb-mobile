import 'package:flutter/widgets.dart';

const keyboardDismissOnTapOutsideKey = ValueKey<String>(
  'keyboard-dismiss-on-tap-outside',
);

/// Makes touch taps outside the active text field dismiss the soft keyboard.
///
/// Flutter's default [EditableTextTapOutsideIntent] action deliberately keeps
/// focus for touch pointers on Android and iOS. Overriding that action once at
/// the app root gives every routed and modal text field the expected Jeeb
/// behavior while preserving [TextFieldTapRegion] groups (for example, suffix
/// controls) and the normal gesture arena for buttons, scrolling, and maps.
///
/// [Actions] is non-visual and adds no semantics or pointer interceptor of its
/// own.
Widget keyboardDismissOnTapOutside({required Widget child}) {
  return Actions(
    key: keyboardDismissOnTapOutsideKey,
    actions: <Type, Action<Intent>>{
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}
