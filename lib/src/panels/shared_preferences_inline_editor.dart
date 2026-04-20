import 'package:flutter/material.dart';

import 'shared_preferences_editor.dart';

class SharedPreferencesInlineEditor extends StatelessWidget {
  const SharedPreferencesInlineEditor({
    required this.keyController,
    required this.valueController,
    required this.editingKey,
    required this.editorType,
    required this.onTypeChanged,
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final TextEditingController keyController;
  final TextEditingController valueController;
  final String? editingKey;
  final PreferenceValueType editorType;
  final ValueChanged<PreferenceValueType> onTypeChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: keyController,
              enabled: editingKey == null,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PreferenceValueType>(
              value: editorType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: PreferenceValueType.values
                  .map(
                    (type) => DropdownMenuItem<PreferenceValueType>(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: editingKey == null
                  ? (value) {
                      if (value != null) onTypeChanged(value);
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valueController,
              maxLines: editorType == PreferenceValueType.stringList ? 2 : 1,
              decoration: InputDecoration(
                labelText: editorType == PreferenceValueType.stringList
                    ? 'Value (comma-separated)'
                    : 'Value',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onSave, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
