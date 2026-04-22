import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_editor.dart';
import 'shared_preferences_inline_editor.dart';

/// Reads ALL keys stored in [SharedPreferences] and presents them in a
/// scrollable table with per-row delete and a global "Clear All" button.
///
/// Does not depend on any app-specific code; works with any app that uses the
/// `shared_preferences` package.
class SharedPreferencesPanel extends StatefulWidget {
  const SharedPreferencesPanel({this.navigatorKey, super.key});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<SharedPreferencesPanel> createState() => _SharedPreferencesPanelState();
}

class _SharedPreferencesPanelState extends State<SharedPreferencesPanel> {
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _isEditorVisible = false;
  String? _editingKey;
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  PreferenceValueType _editorType = PreferenceValueType.string;
  String? _keyErrorText;
  String? _valueErrorText;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _valueController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    }
  }

  Future<void> _deleteKey(String key) async {
    await _prefs?.remove(key);
    await _load();
  }

  Future<void> _clearAll() async {
    await _prefs?.clear();
    await _load();
  }

  void _copyValue(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _startEditing({String? existingKey, Object? existingValue}) {
    setState(() {
      _isEditorVisible = true;
      _editingKey = existingKey;
      _keyController.text = existingKey ?? '';
      _valueController.text = existingValue is List<String>
          ? existingValue.join(', ')
          : existingValue?.toString() ?? '';
      _editorType = preferenceTypeFromValue(existingValue);
      _keyErrorText = null;
      _valueErrorText = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditorVisible = false;
      _editingKey = null;
      _keyController.clear();
      _valueController.clear();
      _editorType = PreferenceValueType.string;
      _keyErrorText = null;
      _valueErrorText = null;
    });
  }

  Future<void> _saveEditing() async {
    final key = _keyController.text.trim();
    final rawValue = _valueController.text.trim();

    if (key.isEmpty) {
      setState(() {
        _keyErrorText = 'Key is required';
      });
      return;
    }
    final validationError = validatePreferenceValue(
      type: _editorType,
      rawValue: rawValue,
    );
    if (validationError != null) {
      setState(() {
        _valueErrorText = validationError;
      });
      return;
    }
    setState(() {
      _keyErrorText = null;
      _valueErrorText = null;
    });

    final prefs = _prefs;
    if (prefs == null) return;
    final ok = await savePreferenceValue(
      prefs: prefs,
      key: key,
      rawValue: rawValue,
      type: _editorType,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingKey == null ? 'Preference added' : 'Preference updated'),
          duration: const Duration(seconds: 1),
        ),
      );
      _cancelEditing();
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save preference')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefs = _prefs;
    if (prefs == null) {
      return const Text('Could not load SharedPreferences.');
    }

    final keys = prefs.getKeys().toList()..sort();
    final entries = {for (final k in keys) k: prefs.get(k)};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${keys.length} key(s) stored',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => _startEditing(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (_isEditorVisible)
          SharedPreferencesInlineEditor(
            keyController: _keyController,
            valueController: _valueController,
            editingKey: _editingKey,
            editorType: _editorType,
            onTypeChanged: (value) {
              setState(() {
                _editorType = value;
                _valueErrorText = null;
              });
            },
            keyErrorText: _keyErrorText,
            valueErrorText: _valueErrorText,
            onKeyChanged: (_) {
              if (_keyErrorText != null) {
                setState(() => _keyErrorText = null);
              }
            },
            onValueChanged: (_) {
              if (_valueErrorText != null) {
                setState(() => _valueErrorText = null);
              }
            },
            onCancel: _cancelEditing,
            onSave: _saveEditing,
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () async {
                final all = entries.entries
                    .map((e) => '${e.key}: ${displayPreferenceValue(e.value)}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: all));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All preferences copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy all'),
            ),
            TextButton.icon(
              onPressed: keys.isEmpty ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep, size: 16),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
        const Divider(),
        if (keys.isEmpty)
          const Text('(empty)')
        else
          ...entries.entries.map((entry) {
            final key = entry.key;
            final value = displayPreferenceValue(entry.value);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _startEditing(
                            existingKey: key,
                            existingValue: entry.value,
                          ),
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _deleteKey(key),
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _copyValue(context, value),
                      child: Text(
                        value,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
