import 'dart:async';
import 'dart:convert';

import '../core/request.dart';
import '../models/file_upload.dart';
import '../models/request_result.dart';

/// Represents a message in the AI chat history.
class AiMessage {
  const AiMessage({required this.role, required this.content});

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  /// The role of the message author. Must be 'system', 'user', or 'assistant'.
  final String role;

  /// The text content of the message.
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Represents the result of a non-streaming AI chat request.
class AiChatResult {
  const AiChatResult({required this.text, this.json});

  factory AiChatResult.fromJson(Map<String, dynamic> json) {
    return AiChatResult(
      text: json['text'] as String? ?? '',
      json: json['json'],
    );
  }

  /// The generated text response.
  final String text;

  /// The parsed structured JSON object, if the agent was configured
  /// with a structured output type or custom schema.
  final dynamic json;
}

/// Represents a single event/chunk in an AI chat event stream.
class AiStreamEvent {
  const AiStreamEvent({required this.type, this.id, this.delta, this.error});

  factory AiStreamEvent.fromJson(Map<String, dynamic> json) {
    return AiStreamEvent(
      type: json['type'] as String? ?? 'unknown',
      id: json['id'] as String?,
      delta: json['delta'] as String?,
      error: json['error'] as String?,
    );
  }

  /// The event type (e.g. `'text-delta'`, `'error'`).
  final String type;

  /// The message ID associated with this event.
  final String? id;

  /// The text fragment generated in this chunk.
  final String? delta;

  /// An error message if the event type indicates an error.
  final String? error;
}

/// The Ai module provides access to the AI Chat API.
class Ai {
  Ai(this.requestHelper);

  final RequestHelper requestHelper;

  /// Sends a prompt to an AI agent.
  ///
  /// [agent] is the ULID or unique name of the agent.
  /// [prompt] is the user prompt.
  /// [collection] is the collection where the agent is stored.
  /// [messages] is the past conversation history.
  /// [attachments] is the list of files to upload.
  /// [outputType] overrides or specifies the output type ('text' or 'json').
  /// [schema] specifies the target JSON Schema constraints.
  /// [stream] if true, throws an [ArgumentError] prompting the user to use [chatStream] instead.
  Future<RequestResult<AiChatResult>> chat({
    required String agent,
    required String prompt,
    required String collection,
    List<AiMessage>? messages,
    List<FileUpload>? attachments,
    bool? stream,
  }) async {
    if (stream == true) {
      throw ArgumentError(
        'For streaming responses, please use the chatStream method.',
      );
    }

    final body = <String, dynamic>{'agent': agent, 'prompt': prompt};

    if (messages != null) {
      body['messages'] = messages.map((m) => m.toJson()).toList();
    }
    if (attachments != null) {
      body['attachments'] = attachments;
    }

    final result = await requestHelper.execute(
      method: 'POST',
      path: '/collections/$collection/ai/chat',
      body: body,
    );

    final dataMap = Map<String, dynamic>.from(result.data as Map);
    return RequestResult<AiChatResult>(
      data: AiChatResult.fromJson(dataMap),
      meta: result.meta,
      message: result.message,
    );
  }

  /// Initiates a streaming AI chat request (Server-Sent Events).
  ///
  /// Yields [AiStreamEvent] chunks containing text deltas or errors.
  ///
  /// [agent] is the ULID or unique name of the agent.
  /// [prompt] is the user prompt.
  /// [collection] is the user-defined collection where the agent is stored.
  /// [messages] is the past conversation history.
  /// [attachments] is the list of files to upload.
  Stream<AiStreamEvent> chatStream({
    required String agent,
    required String prompt,
    required String collection,
    List<AiMessage>? messages,
    List<FileUpload>? attachments,
  }) {
    return _chatStreamImpl(
      agent: agent,
      prompt: prompt,
      collection: collection,
      messages: messages,
      attachments: attachments,
    );
  }

  Stream<AiStreamEvent> _chatStreamImpl({
    required String agent,
    required String prompt,
    required String collection,
    List<AiMessage>? messages,
    List<FileUpload>? attachments,
  }) async* {
    final body = <String, dynamic>{
      'agent': agent,
      'prompt': prompt,
      'stream': true,
    };

    if (messages != null) {
      body['messages'] = messages.map((m) => m.toJson()).toList();
    }
    if (attachments != null) {
      body['attachments'] = attachments;
    }

    final byteStream = requestHelper.executeStream(
      method: 'POST',
      path: '/collections/$collection/ai/chat',
      body: body,
    );

    final lineStream = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.trim().isEmpty) continue;
      if (!line.startsWith('data: ')) continue;

      final dataStr = line.substring(6).trim();
      if (dataStr == '[DONE]') break;

      try {
        final decoded = jsonDecode(dataStr);
        if (decoded is Map<String, dynamic>) {
          yield AiStreamEvent.fromJson(decoded);
        }
      } catch (_) {
        // Ignore parsing errors for non-JSON or malformed chunks
      }
    }
  }
}
