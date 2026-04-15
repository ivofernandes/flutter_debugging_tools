import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads ALL keys stored in [SharedPreferences] and presents them in a
/// scrollable table with per-row delete and a global "Clear All" button.
///
/// Does not depend on any app-specific code; works with any app that uses the
/// `shared_preferences` package.
class SharedPreferencesPanel extends StatefulWidget {
  const SharedPreferencesPanel({super.key});

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
    // Pre-compute all values once to avoid repeated map lookups.
    final entries = {for (final k in keys) k: prefs.get(k).toString()};

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
            TextButton.icon(
              onPressed: () async {
                final all = entries.entries.map((e) => '${e.key}: ${e.value}').join('\n');
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
            final value = entry.value;
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
