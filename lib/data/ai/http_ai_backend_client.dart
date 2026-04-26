import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/debug/app_logger.dart';
import '../../domain/models/ai/agent_action.dart';
import 'ai_backend_client.dart';

const _tag = 'HttpAiBackendClient';

class HttpAiBackendClient implements AiBackendClient {
  HttpAiBackendClient({
    required this.baseUrl,
    required http.Client client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client;

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<AiChatResponse> sendChat(AiChatRequest request) async {
    return _sendJson('/api/ai/chat', request);
  }

  @override
  Future<AiChatResponse> sendAgent(AiChatRequest request) async {
    return _sendJson('/api/ai/agent', request);
  }

  @override
  Stream<AiChatStreamEvent> streamChat(AiChatRequest request) async* {
    yield* _stream('/api/ai/chat/stream', request);
  }

  @override
  Stream<AiChatStreamEvent> streamAgent(AiChatRequest request) async* {
    yield* _stream('/api/ai/agent/stream', request);
  }

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<AiChatResponse> _sendJson(String path, AiChatRequest request) async {
    final bodyStr = jsonEncode(request.toJson());
    AppLogger.info(
      _tag,
      'POST $path',
      data: {
        'requestId': request.requestId,
        'conversationId': request.conversationId,
        'mode': request.mode.name,
        'messageCount': request.messages.length,
        'bodyBytes': bodyStr.length,
      },
    );

    final sw = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _client
          .post(
            _uri(path),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: bodyStr,
          )
          .timeout(timeout);
    } on TimeoutException {
      AppLogger.error(_tag, 'POST $path timed out after ${timeout.inSeconds}s');
      throw const AiBackendException('AI backend request timed out');
    } on http.ClientException catch (error, st) {
      AppLogger.error(
        _tag,
        'POST $path connection failed',
        error: error,
        stackTrace: st,
      );
      throw AiBackendException(
        'AI backend connection failed: ${error.message}',
      );
    }

    sw.stop();
    AppLogger.info(
      _tag,
      'POST $path → ${response.statusCode}',
      data: {
        'durationMs': sw.elapsedMilliseconds,
        'bodyBytes': response.bodyBytes.length,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _errorDetail(response.body);
      AppLogger.error(
        _tag,
        'POST $path server error',
        data: {'status': response.statusCode, 'detail': detail},
      );
      throw AiBackendException(
        'AI backend failed with status ${response.statusCode}: $detail',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error, st) {
      AppLogger.error(
        _tag,
        'POST $path non-JSON response',
        error: error,
        stackTrace: st,
      );
      throw const AiBackendException('AI backend returned invalid JSON');
    }
    if (decoded is! Map) {
      AppLogger.error(
        _tag,
        'POST $path unexpected response shape',
        data: {'type': decoded.runtimeType.toString()},
      );
      throw const AiBackendException('AI backend returned invalid JSON');
    }

    return AiChatResponse.fromJson(decoded.cast<String, Object?>());
  }

  Stream<AiChatStreamEvent> _stream(String path, AiChatRequest request) async* {
    AppLogger.info(
      _tag,
      'SSE $path start',
      data: {
        'requestId': request.requestId,
        'conversationId': request.conversationId,
        'mode': request.mode.name,
        'messageCount': request.messages.length,
      },
    );

    final httpRequest = http.Request('POST', _uri(path))
      ..headers.addAll(const {
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(request.toJson());

    final sw = Stopwatch()..start();
    final http.StreamedResponse response;
    try {
      response = await _client.send(httpRequest).timeout(timeout);
    } on TimeoutException {
      AppLogger.error(_tag, 'SSE $path connect timed out');
      throw const AiBackendException('AI stream request timed out');
    } on http.ClientException catch (error, st) {
      AppLogger.error(
        _tag,
        'SSE $path connection failed',
        error: error,
        stackTrace: st,
      );
      throw AiBackendException('AI stream connection failed: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      final detail = _errorDetail(errorBody);
      AppLogger.error(
        _tag,
        'SSE $path server error',
        data: {'status': response.statusCode, 'detail': detail},
      );
      throw AiBackendException(
        'AI stream failed with status ${response.statusCode}: $detail',
      );
    }

    AppLogger.debug(_tag, 'SSE $path connected');
    var buffer = '';
    var eventCount = 0;
    var deltaCount = 0;

    try {
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final rawEvent = buffer.substring(0, eventEnd).trim();
          buffer = buffer.substring(eventEnd + 2);
          final event = _parseStreamEvent(rawEvent);
          if (event == null) {
            continue;
          }

          eventCount++;
          if (event.type == AiBackendStreamEventType.delta) {
            deltaCount++;
          } else {
            AppLogger.debug(
              _tag,
              'SSE event',
              data: {
                'type': event.type.name,
                'isDone': event.isDone,
                'actionCount': event.actions?.length,
              },
            );
          }

          yield event;
          if (event.isDone) {
            sw.stop();
            AppLogger.info(
              _tag,
              'SSE $path done',
              data: {
                'durationMs': sw.elapsedMilliseconds,
                'eventCount': eventCount,
                'deltaCount': deltaCount,
              },
            );
            return;
          }
        }
      }
    } catch (error, st) {
      AppLogger.error(
        _tag,
        'SSE $path stream error',
        error: error,
        stackTrace: st,
      );
      throw AiBackendException('AI stream connection interrupted: $error');
    }

    final tail = _parseStreamEvent(buffer.trim());
    if (tail != null) {
      yield tail;
    }

    sw.stop();
    AppLogger.info(
      _tag,
      'SSE $path ended',
      data: {
        'durationMs': sw.elapsedMilliseconds,
        'eventCount': eventCount,
        'deltaCount': deltaCount,
      },
    );
  }

  AiChatStreamEvent? _parseStreamEvent(String rawEvent) {
    if (rawEvent.isEmpty || rawEvent.startsWith(':')) {
      return null;
    }

    final dataLines = rawEvent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring('data:'.length).trim())
        .toList(growable: false);
    final payload = dataLines.isEmpty ? rawEvent : dataLines.join('\n');
    if (payload.isEmpty) {
      return null;
    }
    if (payload == '[DONE]') {
      return const AiChatStreamEvent(
        type: AiBackendStreamEventType.done,
        isDone: true,
      );
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final payloadMap = decoded.cast<String, Object?>();
        final eventType = payloadMap['event'] as String?;

        if (payloadMap['error'] is Map) {
          final error = payloadMap['error'] as Map;
          final fullMessage = _friendlyErrorMessage(
            message: error['message']?.toString(),
            detail: error['detail'],
            status: error['status'],
            code: error['code'],
          );
          AppLogger.error(
            _tag,
            'SSE error payload',
            data: {'message': fullMessage, 'code': error['code']},
          );
          throw AiBackendException(fullMessage);
        }
        if (eventType == 'error') {
          final fullMessage = _friendlyErrorMessage(
            message: payloadMap['message']?.toString(),
            detail: payloadMap['detail'],
            status: payloadMap['status'],
            code: payloadMap['code'],
          );
          AppLogger.error(
            _tag,
            'SSE error event',
            data: {'message': fullMessage, 'code': payloadMap['code']},
          );
          throw AiBackendException(fullMessage);
        }
        if (eventType == 'meta') {
          return AiChatStreamEvent(
            type: AiBackendStreamEventType.meta,
            requestId: payloadMap['requestId'] as String?,
            mode: parseAiConversationMode(payloadMap['mode']),
          );
        }
        if (eventType == 'done' || payloadMap['done'] == true) {
          return AiChatStreamEvent(
            type: AiBackendStreamEventType.done,
            isDone: true,
            requestId: payloadMap['requestId'] as String?,
            mode: parseAiConversationMode(payloadMap['mode']),
          );
        }
        final actions = (payloadMap['actions'] as List?)
            ?.whereType<Map>()
            .map((item) => AgentAction.fromJson(item.cast<String, Object?>()))
            .toList(growable: false);
        final textDelta =
            payloadMap['delta'] as String? ??
            payloadMap['content'] as String? ??
            payloadMap['text'] as String?;
        final type = actions != null
            ? AiBackendStreamEventType.action
            : AiBackendStreamEventType.delta;
        return AiChatStreamEvent(
          type: type,
          textDelta: textDelta,
          actions: actions,
          requestId: payloadMap['requestId'] as String?,
          mode: parseAiConversationMode(payloadMap['mode']),
          errorMessage: payloadMap['message'] as String?,
          isDone: payloadMap['done'] == true,
        );
      }
      if (decoded is String) {
        return AiChatStreamEvent(textDelta: decoded);
      }
    } on AiBackendException {
      rethrow;
    } on FormatException {
      return AiChatStreamEvent(textDelta: payload);
    }
    return null;
  }

  String _errorDetail(String body) {
    if (body.trim().isEmpty) {
      return 'empty response body';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          return '${error['message'] ?? decoded['detail'] ?? 'AI backend error'}${error['detail'] == null ? '' : ': ${error['detail']}'}';
        }
        return (decoded['detail'] ?? decoded['error'] ?? body).toString();
      }
    } on FormatException {
      // Fall back to the raw body below.
    }
    return body.length > 300 ? '${body.substring(0, 300)}...' : body;
  }

  String _friendlyErrorMessage({
    String? message,
    Object? detail,
    Object? status,
    Object? code,
  }) {
    final statusCode = status is int ? status : int.tryParse('$status');
    final combined = [
      message,
      detail?.toString(),
      code?.toString(),
    ].whereType<String>().join(' ');

    if (statusCode == 429 ||
        statusCode == 503 ||
        combined.contains('UNAVAILABLE') ||
        combined.toLowerCase().contains('high demand')) {
      return 'The AI model is temporarily busy. Please retry in a moment.';
    }
    if (statusCode == 500 || statusCode == 502 || statusCode == 504) {
      return 'The AI provider is temporarily unavailable. Please retry in a moment.';
    }
    if (combined.toLowerCase().contains('timed out')) {
      return 'The AI request timed out. Please retry in a moment.';
    }

    final trimmed = message?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'The AI request failed. Please try again.';
  }
}
