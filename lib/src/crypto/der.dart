import 'dart:convert';
import 'dart:typed_data';

/// Just enough DER (X.690) for P-256 keys, ECDSA signatures and the certificates of the
/// installation CA. Nothing here parses arbitrary ASN.1: [DerReader] reads the few structures a
/// peer sends, and refuses anything that isn't exactly that shape.
abstract final class Der {
  static const int tagBoolean = 0x01;
  static const int tagInteger = 0x02;
  static const int tagBitString = 0x03;
  static const int tagOctetString = 0x04;
  static const int tagOid = 0x06;
  static const int tagUtf8String = 0x0c;
  static const int tagIa5String = 0x16;
  static const int tagUtcTime = 0x17;
  static const int tagGeneralizedTime = 0x18;
  static const int tagSequence = 0x30;
  static const int tagSet = 0x31;

  static Uint8List tlv(int tag, List<int> value) {
    final length = value.length;
    final header = <int>[tag];

    if (length < 0x80) {
      header.add(length);
    } else {
      final bytes = <int>[];
      for (var rest = length; rest > 0; rest >>= 8) {
        bytes.insert(0, rest & 0xff);
      }
      header..add(0x80 | bytes.length)..addAll(bytes);
    }

    return Uint8List.fromList([...header, ...value]);
  }

  static Uint8List sequence(List<List<int>> items) => tlv(tagSequence, [for (final item in items) ...item]);

  static Uint8List set(List<List<int>> items) => tlv(tagSet, [for (final item in items) ...item]);

  static Uint8List boolean(bool value) => tlv(tagBoolean, [value ? 0xff : 0x00]);

  /// A non-negative integer, minimal and with a leading zero when the top bit is set.
  static Uint8List integer(BigInt value) {
    if (value.isNegative) throw ArgumentError.value(value, "value", "negative");

    var bytes = unsigned(value);
    if (bytes.isEmpty) bytes = Uint8List(1);
    if (bytes.first & 0x80 != 0) bytes = Uint8List.fromList([0, ...bytes]);

    return tlv(tagInteger, bytes);
  }

  static Uint8List smallInteger(int value) => integer(BigInt.from(value));

  static Uint8List oid(String dotted) {
    final parts = dotted.split(".").map(int.parse).toList();
    final bytes = <int>[parts[0] * 40 + parts[1]];

    for (final part in parts.skip(2)) {
      final chunk = <int>[part & 0x7f];
      for (var rest = part >> 7; rest > 0; rest >>= 7) {
        chunk.insert(0, 0x80 | (rest & 0x7f));
      }
      bytes.addAll(chunk);
    }

    return tlv(tagOid, bytes);
  }

  static Uint8List bitString(List<int> bytes, {int unusedBits = 0}) => tlv(tagBitString, [unusedBits, ...bytes]);

  static Uint8List octetString(List<int> bytes) => tlv(tagOctetString, bytes);

  static Uint8List utf8String(String text) => tlv(tagUtf8String, utf8.encode(text));

  static Uint8List ia5String(String text) => tlv(tagIa5String, ascii.encode(text));

  /// UTCTime through 2049, GeneralizedTime after, as RFC 5280 §4.1.2.5 requires.
  static Uint8List time(DateTime at) {
    final utc = at.toUtc();
    String two(int n) => n.toString().padLeft(2, "0");
    final rest = "${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z";

    return utc.year < 2050
      ? tlv(tagUtcTime, ascii.encode("${two(utc.year % 100)}$rest"))
      : tlv(tagGeneralizedTime, ascii.encode("${utc.year.toString().padLeft(4, "0")}$rest"));
  }

  /// `[n] EXPLICIT`: the constructed context tag wrapping a whole element.
  static Uint8List explicit(int n, List<int> element) => tlv(0xa0 | n, element);

  /// `[n] IMPLICIT` over a primitive value (a GeneralName's `dNSName`, `iPAddress`, a key id).
  static Uint8List implicitPrimitive(int n, List<int> value) => tlv(0x80 | n, value);

  /// `[n] IMPLICIT` over a constructed value (`permittedSubtrees`).
  static Uint8List implicitConstructed(int n, List<List<int>> items) =>
    tlv(0xa0 | n, [for (final item in items) ...item]);

  /// Big-endian bytes of [value] without leading zeros (empty for zero).
  static Uint8List unsigned(BigInt value) {
    final bytes = <int>[];
    for (var rest = value; rest > BigInt.zero; rest >>= 8) {
      bytes.insert(0, (rest & BigInt.from(0xff)).toInt());
    }

    return Uint8List.fromList(bytes);
  }

  /// Big-endian bytes of [value], left-padded to [length].
  static Uint8List fixed(BigInt value, int length) {
    final bytes = unsigned(value);
    if (bytes.length > length) throw ArgumentError.value(value, "value", "longer than $length bytes");

    return Uint8List(length)..setRange(length - bytes.length, length, bytes);
  }

  static BigInt toBigInt(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }

    return value;
  }
}

/// One element read by [DerReader]: its tag, its value bytes and the whole encoding.
final class DerElement {
  const DerElement(this.tag, this.value, this.encoded);

  final int tag;
  final Uint8List value;

  /// Tag, length and value, exactly as they were on the wire (what a signature covers).
  final Uint8List encoded;

  DerReader get children => DerReader(value);
}

/// Reads DER elements one after the other. Any malformed or indefinite length is a
/// [FormatException]: a peer's bytes are never trusted to be well formed.
final class DerReader {
  DerReader(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isEmpty => _offset >= _bytes.length;

  DerElement next([int? expectTag]) {
    if (_bytes.length - _offset < 2) throw const FormatException("DER: truncated");

    final start = _offset;
    final tag = _bytes[_offset++];
    var length = _bytes[_offset++];

    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      if (count == 0 || count > 4 || _bytes.length - _offset < count) {
        throw const FormatException("DER: bad length");
      }

      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _bytes[_offset++];
      }
    }

    if (length > _bytes.length - _offset) throw const FormatException("DER: truncated");
    if (expectTag != null && tag != expectTag) {
      throw FormatException("DER: expected tag 0x${expectTag.toRadixString(16)}, got 0x${tag.toRadixString(16)}");
    }

    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;

    return DerElement(tag, value, Uint8List.sublistView(_bytes, start, _offset));
  }

  BigInt integer() {
    final value = next(Der.tagInteger).value;
    if (value.isEmpty || value.first & 0x80 != 0) throw const FormatException("DER: not a positive integer");

    return Der.toBigInt(value);
  }

  String oid() {
    final bytes = next(Der.tagOid).value;
    if (bytes.isEmpty) throw const FormatException("DER: empty OID");

    final parts = <int>[bytes.first ~/ 40, bytes.first % 40];
    var part = 0;
    for (final byte in bytes.skip(1)) {
      part = (part << 7) | (byte & 0x7f);
      if (byte & 0x80 == 0) {
        parts.add(part);
        part = 0;
      }
    }

    return parts.join(".");
  }

  /// A BIT STRING with no unused bits (keys and signatures).
  Uint8List bitString() {
    final value = next(Der.tagBitString).value;
    if (value.isEmpty || value.first != 0) throw const FormatException("DER: bit string with unused bits");

    return Uint8List.sublistView(value, 1);
  }
}

/// PEM armour (RFC 7468), the format `SecurityContext` reads.
abstract final class Pem {
  static String encode(String label, List<int> der) {
    final body = base64.encode(der);
    final lines = [for (var i = 0; i < body.length; i += 64) body.substring(i, (i + 64).clamp(0, body.length))];

    return "-----BEGIN $label-----\n${lines.join("\n")}\n-----END $label-----\n";
  }

  /// The DER of the first [label] block in [text].
  static Uint8List decode(String label, String text) {
    final match = RegExp("-----BEGIN $label-----([^-]+)-----END $label-----").firstMatch(text);
    if (match == null) throw FormatException("PEM: no $label block");

    return base64.decode(match.group(1)!.replaceAll(RegExp(r"\s"), ""));
  }
}
