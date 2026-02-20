import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

import 'tool.dart';

/// Tool that extracts text from images using on-device ML Kit OCR.
class OcrTool extends Tool {
  final String workspacePath;

  OcrTool({required this.workspacePath});

  @override
  String get name => 'ocr';

  @override
  String get description =>
      'Extract text from an image file in the workspace using on-device OCR. '
      'Supports photos, screenshots, receipts, documents. '
      'The image must already exist in the workspace (use pick_image or file tool first).';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'image_path': {
            'type': 'string',
            'description':
                'Relative path to image in workspace '
                    '(e.g. "images/receipt.jpg")',
          },
        },
        'required': ['image_path'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final imagePath = arguments['image_path'] as String?;
    if (imagePath == null || imagePath.isEmpty) {
      return ToolResult.error('Missing required parameter: image_path');
    }

    // Validate path stays within workspace
    final resolvedPath = _resolvePath(imagePath);
    if (resolvedPath == null) {
      return ToolResult.error('Path escapes workspace: $imagePath');
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      return ToolResult.error('Image not found: $imagePath');
    }

    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(resolvedPath);
      final recognizedText = await textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return ToolResult.simple(
            'No text found in image "$imagePath".');
      }

      final text = recognizedText.text;
      final blockCount = recognizedText.blocks.length;
      final preview = text.length > 200
          ? '${text.substring(0, 200)}...'
          : text;

      return ToolResult.dual(
        forLLM: 'OCR result from "$imagePath" '
            '($blockCount text blocks):\n\n$text',
        forUser: 'OCR: $preview',
      );
    } catch (e) {
      return ToolResult.error('OCR failed: $e');
    } finally {
      await textRecognizer.close();
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
