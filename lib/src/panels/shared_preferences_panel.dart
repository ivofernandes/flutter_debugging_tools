import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_editor.dart';
import 'shared_preferences_upsert_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _showUpsertSheet({String? existingKey, Object? existingValue}) async {
    final hostContext = widget.navigatorKey?.currentContext ?? context;
    if (Navigator.maybeOf(hostContext) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Navigator available to open editor')),
      );
      return;
    }

    final draft = await showSharedPreferencesUpsertSheet(
      hostContext: hostContext,
      existingKey: existingKey,
      existingValue: existingValue,
    );
    if (draft == null) return;
    final key = draft.key;
    final rawValue = draft.rawValue;
    final selectedType = draft.type;

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key is required')),
      );
      return;
    }
    final validationError = validatePreferenceValue(type: selectedType, rawValue: rawValue);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final prefs = _prefs;
    if (prefs == null) return;
    final ok = await savePreferenceValue(
      prefs: prefs,
      key: key,
      rawValue: rawValue,
      type: selectedType,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingKey == null ? 'Preference added' : 'Preference updated'),
          duration: const Duration(seconds: 1),
        ),
      );
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
              onPressed: _showUpsertSheet,
              icon: const Icon(Icons.add),
            ),
          ],
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
                          onPressed: () => _showUpsertSheet(
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
