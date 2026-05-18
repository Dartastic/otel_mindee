// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_mindee/otel_mindee.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_mindee-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('predict records product + pages + confidence + credits', () async {
    await tracedMindee<String>(
      operation: 'predict',
      invoke: () async => const MindeeCallResult(
        value: 'ok',
        result: MindeeResult(
          product: 'invoices',
          productVersion: 'v4.6',
          endpointOwner: 'mindee',
          documentId: 'doc_1',
          documentType: 'invoice',
          processingTimeMs: 1850,
          pageCount: 2,
          predictionConfidence: 0.93,
          fullTextOcrEnabled: false,
          creditsConsumed: 2,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('mindee predict')!);
    expect(a['mindee.product'], 'invoices');
    expect(a['mindee.product.version'], 'v4.6');
    expect(a['mindee.page.count'], 2);
    expect(a['mindee.prediction.confidence'], 0.93);
    expect(a['mindee.credits.consumed'], 2);
  });

  test('async job failed sets span error', () async {
    await tracedMindee<String>(
      operation: 'parse_queue',
      invoke: () async => const MindeeCallResult(
        value: 'ok',
        result: MindeeResult(
          asyncEnqueued: true,
          asyncJobStatus: 'failed',
        ),
      ),
    );
    expect(
      spans.findSpanByName('mindee parse_queue')!.status,
      SpanStatusCode.Error,
    );
  });

  test('processing async status does NOT set span error', () async {
    await tracedMindee<String>(
      operation: 'parse_queue',
      invoke: () async => const MindeeCallResult(
        value: 'ok',
        result: MindeeResult(
          asyncJobStatus: 'processing',
        ),
      ),
    );
    expect(
      spans.findSpanByName('mindee parse_queue')!.status,
      isNot(SpanStatusCode.Error),
    );
  });

  test('suppression skips spans', () async {
    await runWithoutMindeeInstrumentationAsync(() async {
      await tracedMindee<String>(
        operation: 'predict',
        invoke: () async => const MindeeCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('mindee '), isEmpty);
  });
}
