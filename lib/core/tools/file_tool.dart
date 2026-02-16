import 'dart:io';

import 'package:path/path.dart' as p;

import 'tool.dart';

/// Sandboxed file operations tool. Restricted to the app workspace directory.
class FileTool extends Tool {
  final String workspacePath;

  FileTool({required this.workspacePath});

  @override
  String get name => 'file';

  @override
  String get description =>
      'Read, write, or list files in the workspace directory. '
      'Operations: read_file, write_file, list_dir.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'enum': ['read_file', 'write_file', 'list_dir'],
            'description': 'The file operation to perform',
          },
          'path': {
            'type': 'string',
            'description': 'Relative path within the workspace',
          },
          'content': {
            'type': 'string',
            'description': 'Content to write (for write_file operation)',
          },
        },
        'required': ['operation', 'path'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final operation = arguments['operation'] as String?;
    final relativePath = arguments['path'] as String?;

    if (operation == null || relativePath == null) {
      return ToolResult.error('Missing required parameters: operation, path');
    }

    // Validate path doesn't escape workspace
    final resolvedPath = _resolvePath(relativePath);
    if (resolvedPath == null) {
      return ToolResult.error('Path escapes workspace: $relativePath');
    }

    try {
      return switch (operation) {
        'read_file' => await _readFile(resolvedPath),
        'write_file' => await _writeFile(
            resolvedPath, arguments['content'] as String? ?? ''),
        'list_dir' => await _listDir(resolvedPath),
        _ => ToolResult.error('Unknown operation: $operation'),
      };
    } catch (e) {
      return ToolResult.error('File operation failed: $e');
    }
  }

  /// Resolve and validate a path, ensuring it stays within workspace.
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

  Future<ToolResult> _readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.error('File not found: ${p.relative(path, from: workspacePath)}');
    }
    final content = await file.readAsString();
    return ToolResult.dual(
      forLLM: content,
      forUser: 'Read ${content.length} chars from ${p.relative(path, from: workspacePath)}',
    );
  }

  Future<ToolResult> _writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return ToolResult.dual(
      forLLM: 'File written successfully: ${p.relative(path, from: workspacePath)}',
      forUser: 'Wrote ${content.length} chars to ${p.relative(path, from: workspacePath)}',
    );
  }

  Future<ToolResult> _listDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return ToolResult.error('Directory not found: ${p.relative(path, from: workspacePath)}');
    }
    final entries = await dir.list().toList();
    final buffer = StringBuffer();
    for (final entry in entries) {
      final name = p.relative(entry.path, from: workspacePath);
      final type = entry is Directory ? '[dir]' : '[file]';
      buffer.writeln('$type $name');
    }
    return ToolResult.simple(buffer.toString().trimRight());
  }
}
