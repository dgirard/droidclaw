import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'tool.dart';

/// Tool that picks an image from gallery or camera and copies it to workspace.
class PickImageTool extends Tool {
  final String workspacePath;

  PickImageTool({required this.workspacePath});

  @override
  String get name => 'pick_image';

  @override
  String get description =>
      'Open the system image picker to select a photo from gallery '
      'or take a new photo with the camera. The image is copied to the '
      'workspace for further processing (e.g. OCR). Foreground only.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'source': {
            'type': 'string',
            'enum': ['gallery', 'camera'],
            'description': 'Image source: gallery (photo library) or camera',
          },
        },
        'required': ['source'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final source = arguments['source'] as String?;
    if (source == null) {
      return ToolResult.error('Missing required parameter: source');
    }

    final imageSource = switch (source) {
      'gallery' => ImageSource.gallery,
      'camera' => ImageSource.camera,
      _ => null,
    };
    if (imageSource == null) {
      return ToolResult.error(
          'Unknown source: $source. Use "gallery" or "camera".');
    }

    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: imageSource,
        imageQuality: 85,
      );

      if (xfile == null) {
        return ToolResult.simple('Image selection cancelled by user.');
      }

      // Copy to workspace images directory
      final imagesDir = p.join(workspacePath, 'images');
      await Directory(imagesDir).create(recursive: true);
      final destPath = p.join(imagesDir, xfile.name);
      final copiedFile = await File(xfile.path).copy(destPath);
      final sizeKb = ((await copiedFile.length()) / 1024).toStringAsFixed(0);
      final relativePath = 'images/${xfile.name}';

      return ToolResult.dual(
        forLLM: 'Image saved to workspace: path="$relativePath", '
            'size=${sizeKb}KB, source=$source. '
            'Use the ocr tool with this path to extract text.',
        forUser: 'Image saved: $relativePath (${sizeKb}KB)',
      );
    } catch (e) {
      return ToolResult.error('Image pick failed: $e');
    }
  }
}
