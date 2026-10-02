## 0.0.4 unreleased
- Fixed Flutter web compilation with `flutter_svg` 2.3.0 by loading SVG file
  bytes explicitly instead of passing a `dart:io` `File` to `SvgPicture.file`.
- Load SVG previews asynchronously and display a fallback when reading fails.

## 0.0.3 2026-09-04
- Preview files and bundled assets with `multi_asset_player`, including
  its text, image, document, media, archive, and unknown-file presentations.
- Render SVG files as vector images instead of displaying their XML source.
- Added a persistent default-route selector to the navigation panel so debug
  sessions can reopen the same screen after an application or web reload.

## 0.0.2 2026-08-10

Asset bundle debug. AppLogger. Screen size simulation. Better docs.

## 0.0.1 2026-06-20

First release with navigation, network, shared preferences, files and sqlite panels.
