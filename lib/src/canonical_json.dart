import 'dart:convert';

/// JSON with object keys sorted at every level, so the same value always has the same bytes.
/// What gets hashed or MACed (the engine's audit chain and command arguments, pairing messages)
/// is hashed in this form, so both sides of the LAN compute the same bytes.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();

    return {for (final key in keys) key: _sorted(value[key])};
  }

  if (value is List) return [for (final item in value) _sorted(item)];

  return value;
}
