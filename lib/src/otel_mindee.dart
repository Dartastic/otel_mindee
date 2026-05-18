// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_mindee_suppression.dart';

const _tracerName = 'dartastic_otel_libs_mindee';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class MindeeResult {
  const MindeeResult({
    this.product,
    this.productVersion,
    this.endpointOwner,
    this.requestId,
    this.documentId,
    this.documentType,
    this.processingTimeMs,
    this.pageCount,
    this.predictionConfidence,
    this.fullTextOcrEnabled,
    this.cropperEnabled,
    this.asyncEnqueued,
    this.asyncJobStatus,
    this.creditsConsumed,
    this.statusCode,
  });

  /// `invoices` / `receipts` / `passport` / `id_card` /
  /// `driver_license` / `bank_check` / `bill_of_lading` /
  /// `proof_of_address` / `financial_document` / `us_w9` /
  /// `business_card` / `barcode_reader` / `multi_receipts_detector`
  /// / `nutrition_facts_label` / `resume` / `custom`.
  final String? product;

  /// Mindee bumps version per training round.
  final String? productVersion;

  /// `mindee` for built-in products; otherwise the user account that
  /// owns a custom API.
  final String? endpointOwner;

  /// `X-Request-ID` header.
  final String? requestId;

  /// Document/upload id.
  final String? documentId;

  /// Inferred document type (some products do multi-class
  /// classification before extraction).
  final String? documentType;

  final int? processingTimeMs;

  /// Mindee bills per page above the included quota.
  final int? pageCount;

  /// Aggregate prediction confidence (0.0-1.0) — useful for routing
  /// low-confidence results to human review.
  final double? predictionConfidence;

  /// `true` when full-page OCR was requested alongside extraction.
  final bool? fullTextOcrEnabled;

  /// `true` when crop API was requested.
  final bool? cropperEnabled;

  /// `true` when the request went via the async enqueue endpoint vs
  /// sync `predict`.
  final bool? asyncEnqueued;

  /// `waiting` / `processing` / `completed` / `failed`.
  final String? asyncJobStatus;

  /// API credits charged for this request.
  final int? creditsConsumed;

  final int? statusCode;
}

class MindeeCallResult<T> {
  const MindeeCallResult({required this.value, this.result});
  final T value;
  final MindeeResult? result;
}

/// Wraps a Mindee API call in a CLIENT span. [operation] is one of
/// `predict`, `enqueue`, `parse_queue`, `feedback`, `workflows.execute`,
/// `documents.list`, `documents.update`.
Future<T> tracedMindee<T>({
  required String operation,
  required Future<MindeeCallResult<T>> Function() invoke,
}) async {
  if (mindeeInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'mindee',
    'rpc.method': operation,
    'mindee.operation': operation,
  };

  final span = _tracer().startSpan(
    'mindee $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.product != null) {
        extras.add(OTel.attributeString(
          'mindee.product',
          r.result!.product!,
        ));
      }
      if (r.result!.productVersion != null) {
        extras.add(OTel.attributeString(
          'mindee.product.version',
          r.result!.productVersion!,
        ));
      }
      if (r.result!.endpointOwner != null) {
        extras.add(OTel.attributeString(
          'mindee.endpoint.owner',
          r.result!.endpointOwner!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'mindee.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.documentId != null) {
        extras.add(OTel.attributeString(
          'mindee.document.id',
          r.result!.documentId!,
        ));
      }
      if (r.result!.documentType != null) {
        extras.add(OTel.attributeString(
          'mindee.document.type',
          r.result!.documentType!,
        ));
      }
      if (r.result!.processingTimeMs != null) {
        extras.add(OTel.attributeInt(
          'mindee.processing_ms',
          r.result!.processingTimeMs!,
        ));
      }
      if (r.result!.pageCount != null) {
        extras.add(OTel.attributeInt(
          'mindee.page.count',
          r.result!.pageCount!,
        ));
      }
      if (r.result!.predictionConfidence != null) {
        extras.add(OTel.attributeDouble(
          'mindee.prediction.confidence',
          r.result!.predictionConfidence!,
        ));
      }
      if (r.result!.fullTextOcrEnabled != null) {
        extras.add(OTel.attributeBool(
          'mindee.full_text_ocr',
          r.result!.fullTextOcrEnabled!,
        ));
      }
      if (r.result!.cropperEnabled != null) {
        extras.add(OTel.attributeBool(
          'mindee.cropper',
          r.result!.cropperEnabled!,
        ));
      }
      if (r.result!.asyncEnqueued != null) {
        extras.add(OTel.attributeBool(
          'mindee.async.enqueued',
          r.result!.asyncEnqueued!,
        ));
      }
      if (r.result!.asyncJobStatus != null) {
        extras.add(OTel.attributeString(
          'mindee.async.job_status',
          r.result!.asyncJobStatus!,
        ));
        if (r.result!.asyncJobStatus == 'failed') {
          span.setStatus(SpanStatusCode.Error, 'Mindee async job failed');
        }
      }
      if (r.result!.creditsConsumed != null) {
        extras.add(OTel.attributeInt(
          'mindee.credits.consumed',
          r.result!.creditsConsumed!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Mindee HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
