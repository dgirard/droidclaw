import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';

import 'tool.dart';

/// Tool that generates QR code images and saves them to the workspace.
class QrGenerateTool extends Tool {
  final String workspacePath;

  QrGenerateTool({required this.workspacePath});

  @override
  String get name => 'qr_generate';

  @override
  String get description =>
      'Generate a QR code image from text and save it as a PNG file '
      'in the workspace. Use for URLs, WiFi configs, contact info, etc.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'string',
            'description': 'The text or URL to encode in the QR code',
          },
          'filename': {
            'type': 'string',
            'description':
                'Output filename (default: qr_code.png). '
                    'Saved in workspace root.',
          },
        },
        'required': ['data'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final data = arguments['data'] as String?;
    if (data == null || data.isEmpty) {
      return ToolResult.error('Missing required parameter: data');
    }

    if (data.length > 4296) {
      return ToolResult.error(
          'Data too long for QR code (${data.length} chars, max 4296)');
    }

    final filename = (arguments['filename'] as String?) ?? 'qr_code.png';

    // Validate path stays within workspace
    final resolvedPath = _resolvePath(filename);
    if (resolvedPath == null) {
      return ToolResult.error('Filename escapes workspace: $filename');
    }

    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: false,
      );

      final imageData = await qrPainter.toImageData(512.0);
      if (imageData == null) {
        return ToolResult.error('Failed to generate QR code image');
      }

      final bytes = imageData.buffer.asUint8List(
        imageData.offsetInBytes,
        imageData.lengthInBytes,
      );

      final file = File(resolvedPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);

      final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
      return ToolResult.dual(
        forLLM: 'QR code generated: file="$filename", '
            'data="${data.length > 100 ? '${data.substring(0, 100)}...' : data}", '
            'size=${sizeKb}KB',
        forUser: 'QR code saved: $filename (${sizeKb}KB)',
      );
    } catch (e) {
      return ToolResult.error('QR generation failed: $e');
    }
  }

  String? _resolvePath(String relativePath) {
    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) {
      return null;
    }
    final resolved = p.join(workspacePath, normalized);
    final canonical = p.canonicalize(resolved);
    if (!canonical.startsWith(p.canonicalize(workspacePath))) {
      return null;
    }
    return resolved;
  }
}
