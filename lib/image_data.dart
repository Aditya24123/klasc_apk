import 'dart:convert';
import 'dart:typed_data';

// A malformed stored image should not prevent other saved ideas from opening.
Uint8List? decodeImageData(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    final bytes = base64Decode(value);
    return bytes.isEmpty ? null : bytes;
  } on FormatException {
    return null;
  }
}
