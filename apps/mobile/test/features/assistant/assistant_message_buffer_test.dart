import 'package:craftr_mobile/features/assistant/assistant_message_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agrupa mensajes dentro de la ventana en un solo flush', () async {
    final batches = <BufferedAssistantBatch>[];
    final buffer = AssistantMessageBuffer(
      window: const Duration(milliseconds: 40),
      onFlush: (batch) async {
        batches.add(batch);
      },
    );

    buffer.queue('Primer mensaje');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    buffer.queue('Segundo mensaje');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(batches.length, 1);
    expect(batches.first.message, 'Primer mensaje\n\nSegundo mensaje');
    expect(batches.first.bufferSize, 2);
    expect(batches.first.delayMs, greaterThanOrEqualTo(40));
    expect(batches.first.tokensSavedEstimated, greaterThan(0));
  });

  test('separa mensajes fuera de ventana en llamadas distintas', () async {
    final batches = <BufferedAssistantBatch>[];
    final buffer = AssistantMessageBuffer(
      window: const Duration(milliseconds: 40),
      onFlush: (batch) async {
        batches.add(batch);
      },
    );

    buffer.queue('Mensaje A');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    buffer.queue('Mensaje B');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(batches.length, 2);
    expect(batches[0].message, 'Mensaje A');
    expect(batches[1].message, 'Mensaje B');
    expect(batches[0].bufferSize, 1);
    expect(batches[1].bufferSize, 1);
    expect(batches[0].tokensSavedEstimated, 0);
    expect(batches[1].tokensSavedEstimated, 0);
  });

  test('preserva el orden del contenido final', () async {
    final batches = <BufferedAssistantBatch>[];
    final buffer = AssistantMessageBuffer(
      window: const Duration(milliseconds: 40),
      onFlush: (batch) async {
        batches.add(batch);
      },
    );

    buffer.queue('uno');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    buffer.queue('dos');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    buffer.queue('tres');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(batches.length, 1);
    expect(batches.single.message, 'uno\n\ndos\n\ntres');
  });
}
