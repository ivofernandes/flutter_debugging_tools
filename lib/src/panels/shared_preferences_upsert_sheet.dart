import 'package:flutter/material.dart';

import 'shared_preferences_editor.dart';

class PreferenceDraft {
  const PreferenceDraft({
    required this.key,
    required this.rawValue,
    required this.type,
  });

  final String key;
  final String rawValue;
  final PreferenceValueType type;
}

Future<PreferenceDraft?> showSharedPreferencesUpsertSheet({
  required BuildContext hostContext,
  String? existingKey,
  Object? existingValue,
}) async {
  final keyController = TextEditingController(text: existingKey ?? '');
  final valueController = TextEditingController(
    text: existingValue is List<String>
        ? existingValue.join(', ')
        : existingValue?.toString() ?? '',
  );
  var selectedType = preferenceTypeFromValue(existingValue);

  final shouldSave = await showModalBottomSheet<bool>(
    context: hostContext,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existingKey == null ? 'Add preference' : 'Edit preference',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  enabled: existingKey == null,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PreferenceValueType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: PreferenceValueType.values
                      .map(
                        (type) => DropdownMenuItem<PreferenceValueType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: existingKey == null
                      ? (value) {
                          if (value != null) {
                            setSheetState(() => selectedType = value);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: valueController,
                  maxLines: selectedType == PreferenceValueType.stringList ? 2 : 1,
                  decoration: InputDecoration(
                    labelText: selectedType == PreferenceValueType.stringList
                        ? 'Value (comma-separated)'
                        : 'Value',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  final draft = shouldSave == true
      ? PreferenceDraft(
          key: keyController.text.trim(),
          rawValue: valueController.text.trim(),
          type: selectedType,
        )
      : null;
  keyController.dispose();
  valueController.dispose();
  return draft;
}
