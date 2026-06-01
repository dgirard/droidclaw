import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:droidclaw/core/providers/llm_response.dart';

import 'support/fake_llm_provider.dart';
import 'support/hive_test_harness.dart';
import 'support/in_memory_kg.dart';

void main() {
  test('FakeLLMProvider scripts responses and records received messages',
      () async {
    final provider = FakeLLMProvider([
      toolCallResponse('web_search', {'query': 'x'}),
      textResponse('done'),
    ]);

    final r1 = await provider
        .chat(messages: [const Message(role: 'user', content: 'hi')], model: 'm');
    expect(r1.toolCalls.single.name, 'web_search');
    expect(r1.finishReason, 'tool_calls');

    final r2 = await provider.chat(messages: const [], model: 'm');
    expect(r2.content, 'done');

    expect(provider.callCount, 2);
    expect(provider.receivedMessages.first.single.content, 'hi');
  });

  test('in-memory KnowledgeGraphDB applies schema and is empty', () async {
    final db = inMemoryKnowledgeGraphDB();
    final rows =
        await db.customSelect('SELECT count(*) AS c FROM entities').get();
    expect(rows.first.data['c'], 0);
    await db.close();
  });

  test('Hive harness opens and closes the sessions box', () async {
    final hive = await HiveTestHarness.create();
    final box = await Hive.openBox<String>('sessions');
    await box.put('k', 'v');
    expect(box.get('k'), 'v');
    await hive.dispose();
  });
}
