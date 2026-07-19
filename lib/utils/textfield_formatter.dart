import 'package:flutter/services.dart';

class WorkoutFormattingFormatter extends TextInputFormatter {
  final _setRegex = RegExp(r'\[[0-9.]+,\s*[0-9.]+\](?:\([WD]\))?');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only care about backspace/delete
    if (newValue.text.length >= oldValue.text.length) {
      return newValue;
    }

    final deletedIndex = newValue.selection.baseOffset;

    // Safety
    if (deletedIndex < 0 || deletedIndex >= oldValue.text.length) {
      return newValue;
    }

    final deletedChar = oldValue.text[deletedIndex];

    // If a bracket was deleted, remove the entire set.
    if (deletedChar == '[' || deletedChar == ']') {
      for (final match in _setRegex.allMatches(oldValue.text)) {
        if (deletedIndex >= match.start && deletedIndex < match.end) {
          final newText =
              oldValue.text.replaceRange(match.start, match.end, '');

          return TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: match.start),
          );
        }
      }
    }

    // Otherwise allow normal editing (numbers, commas, etc.)
    return newValue;
  }
}