import 'dart:typed_data';

/// Byte codec for entity embeddings stored as Float32 little-endian BLOBs
/// in the `entities.embedding` column.
///
/// Single home for the (de)serialization idiom previously copy-pasted at
/// every read/write site — the wire format is unchanged.
class EmbeddingCodec {
  const EmbeddingCodec._();

  /// Decode a BLOB into a Float32 vector.
  ///
  /// Copies [blob] into a fresh buffer first so the view is always aligned
  /// at offset 0 (DB layers may hand back views into larger buffers).
  static Float32List decode(List<int> blob) =>
      Float32List.view(Uint8List.fromList(blob).buffer);

  /// Encode a vector into the BLOB representation.
  static Uint8List encode(List<double> values) =>
      Float32List.fromList(values).buffer.asUint8List();
}
