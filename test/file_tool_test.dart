// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:test/test.dart';

import 'package:droidclaw/core/tools/file_tool.dart';
import 'package:droidclaw/shared/constants.dart';

void main() {
  late Directory tmp;
  late Directory workspace;
  late FileTool tool;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('file_tool_test_');
    workspace = Directory('${tmp.path}/workspace')..createSync();
    tool = FileTool(workspacePath: workspace.path);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('write then read round-trips within the workspace', () async {
    final w = await tool.execute(
        {'operation': 'write_file', 'path': 'notes/a.txt', 'content': 'hello'});
    expect(w.isError, isFalse);
    final r =
        await tool.execute({'operation': 'read_file', 'path': 'notes/a.txt'});
    expect(r.forLLM, 'hello');
  });

  test('rejects parent-traversal paths', () async {
    final r = await tool
        .execute({'operation': 'read_file', 'path': '../secret.txt'});
    expect(r.isError, isTrue);
    expect(r.forLLM, contains('escapes workspace'));
  });

  test('rejects absolute paths', () async {
    final r = await tool
        .execute({'operation': 'read_file', 'path': '/etc/passwd'});
    expect(r.isError, isTrue);
  });

  test('rejects a sibling directory sharing a name prefix', () async {
    // workspace is .../workspace; .../workspace_evil shares the prefix.
    Directory('${tmp.path}/workspace_evil').createSync();
    File('${tmp.path}/workspace_evil/x.txt').writeAsStringSync('secret');
    final r = await tool.execute(
        {'operation': 'read_file', 'path': '../workspace_evil/x.txt'});
    expect(r.isError, isTrue);
    expect(r.forLLM, contains('escapes workspace'));
  });

  test('enforces the write-size cap', () async {
    final big = 'x' * (AppConstants.fileWriteMaxChars + 1);
    final r = await tool
        .execute({'operation': 'write_file', 'path': 'big.txt', 'content': big});
    expect(r.isError, isTrue);
    expect(r.forLLM, contains('write limit'));
    expect(File('${workspace.path}/big.txt').existsSync(), isFalse);
  });

  test('allows listing the workspace root', () async {
    await tool.execute(
        {'operation': 'write_file', 'path': 'a.txt', 'content': 'x'});
    final r = await tool.execute({'operation': 'list_dir', 'path': '.'});
    expect(r.isError, isFalse);
    expect(r.forLLM, contains('a.txt'));
  });
}
