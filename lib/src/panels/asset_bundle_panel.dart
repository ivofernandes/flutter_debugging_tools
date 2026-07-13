import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Debug UI for inspecting assets declared in the app bundle manifest.
class AssetBundlePanel extends StatefulWidget {
  const AssetBundlePanel({
    this.bundle,
    this.compact = false,
    super.key,
  });

  /// Asset bundle to inspect. Defaults to Flutter's [rootBundle].
  final AssetBundle? bundle;

  /// Whether the panel is shown inside the compact debug drawer.
  final bool compact;

  @override
  State<AssetBundlePanel> createState() => _AssetBundlePanelState();
}

class _AssetBundlePanelState extends State<AssetBundlePanel> {
  late Future<List<String>> _assetsFuture;
  final TextEditingController _filterController = TextEditingController();
  String _query = '';
  String? _selectedAsset;
  Future<_AssetPreview>? _previewFuture;

  @override
  void initState() {
    super.initState();
    _assetsFuture = _loadAssetKeys();
    _filterController.addListener(() {
      setState(() => _query = _filterController.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(covariant AssetBundlePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundle != widget.bundle) {
      _selectedAsset = null;
      _previewFuture = null;
      _assetsFuture = _loadAssetKeys();
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  AssetBundle get _bundle => widget.bundle ?? rootBundle;

  Future<List<String>> _loadAssetKeys() async {
    final manifestText = await _bundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(manifestText);
    final keys = switch (decoded) {
      Map<String, dynamic> map => map.keys.toList(),
      List<dynamic> list => list.cast<String>(),
      _ => <String>[],
    };
    keys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return keys;
  }

  Future<_AssetPreview> _loadPreview(String assetKey) async {
    final bytes = await _bundle.load(assetKey);
    final uint8 = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final text = _decodeText(uint8);
    return _AssetPreview(byteLength: uint8.length, text: text);
  }

  String? _decodeText(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    try {
      final text = const Utf8Decoder(allowMalformed: false).convert(bytes);
      final controlCharacters = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');
      if (controlCharacters.hasMatch(text)) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  void _selectAsset(String assetKey) {
    setState(() {
      _selectedAsset = assetKey;
      _previewFuture = _loadPreview(assetKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _assetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Unable to load asset manifest: ${snapshot.error}');
        }

        final assets = snapshot.data ?? const <String>[];
        final visibleAssets = _query.isEmpty
            ? assets
            : assets
                  .where((asset) => asset.toLowerCase().contains(_query))
                  .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text(
              '${visibleAssets.length}/${assets.length} asset(s)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Filter assets',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxHeight: widget.compact ? 220 : 360,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: visibleAssets.isEmpty
                  ? const Center(child: Text('No assets match the filter.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: visibleAssets.length,
                      itemBuilder: (context, index) {
                        final asset = visibleAssets[index];
                        return ListTile(
                          dense: widget.compact,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(asset),
                          selected: asset == _selectedAsset,
                          onTap: () => _selectAsset(asset),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            if (_selectedAsset == null)
              const Text('Select an asset to inspect its bundle bytes.')
            else
              _AssetPreviewView(
                assetKey: _selectedAsset!,
                previewFuture: _previewFuture!,
                compact: widget.compact,
              ),
          ],
        );
      },
    );
  }
}

class _AssetPreviewView extends StatelessWidget {
  const _AssetPreviewView({
    required this.assetKey,
    required this.previewFuture,
    required this.compact,
  });

  final String assetKey;
  final Future<_AssetPreview> previewFuture;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AssetPreview>(
      future: previewFuture,
      builder: (context, snapshot) {
        final title = Text('Selected asset: $assetKey');
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const LinearProgressIndicator()],
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, Text('Unable to load asset: ${snapshot.error}')],
          );
        }

        final preview = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            Text('${preview.byteLength} byte(s)'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: compact ? 120 : 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview.text ?? '<binary asset preview unavailable>',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AssetPreview {
  const _AssetPreview({required this.byteLength, required this.text});

  final int byteLength;
  final String? text;
}
