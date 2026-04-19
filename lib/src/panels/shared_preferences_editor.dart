import 'package:shared_preferences/shared_preferences.dart';

enum PreferenceValueType { string, integer, doubleNumber, boolean, stringList }

extension PreferenceValueTypeLabel on PreferenceValueType {
  String get label => switch (this) {
    PreferenceValueType.string => 'String',
    PreferenceValueType.integer => 'Int',
    PreferenceValueType.doubleNumber => 'Double',
    PreferenceValueType.boolean => 'Bool',
    PreferenceValueType.stringList => 'String List',
  };
}

String displayPreferenceValue(Object? value) {
  if (value is List<String>) {
    return value.join(', ');
  }
  return value.toString();
}

PreferenceValueType preferenceTypeFromValue(Object? value) {
  if (value is int) return PreferenceValueType.integer;
  if (value is double) return PreferenceValueType.doubleNumber;
  if (value is bool) return PreferenceValueType.boolean;
  if (value is List<String>) return PreferenceValueType.stringList;
  return PreferenceValueType.string;
}

String? validatePreferenceValue({
  required PreferenceValueType type,
  required String rawValue,
}) {
  if (type == PreferenceValueType.integer && int.tryParse(rawValue) == null) {
    return 'Enter a valid integer';
  }
  if (type == PreferenceValueType.doubleNumber && double.tryParse(rawValue) == null) {
    return 'Enter a valid double';
  }
  if (type == PreferenceValueType.boolean &&
      rawValue.toLowerCase() != 'true' &&
      rawValue.toLowerCase() != 'false') {
    return 'Enter true or false';
  }
  return null;
}

Future<bool> savePreferenceValue({
  required SharedPreferences prefs,
  required String key,
  required String rawValue,
  required PreferenceValueType type,
}) {
  switch (type) {
    case PreferenceValueType.string:
      return prefs.setString(key, rawValue);
    case PreferenceValueType.integer:
      final value = int.tryParse(rawValue);
      return value == null ? Future.value(false) : prefs.setInt(key, value);
    case PreferenceValueType.doubleNumber:
      final value = double.tryParse(rawValue);
      return value == null ? Future.value(false) : prefs.setDouble(key, value);
    case PreferenceValueType.boolean:
      final lowered = rawValue.toLowerCase();
      if (lowered != 'true' && lowered != 'false') {
        return Future.value(false);
      }
      return prefs.setBool(key, lowered == 'true');
    case PreferenceValueType.stringList:
      final list = rawValue
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return prefs.setStringList(key, list);
  }
}
