import 'dart:convert';
import 'package:test/test.dart';
import 'package:veloquent_sdk/veloquent_sdk.dart';
import 'mocks.dart';

void main() {
  group('AI Chat', () {
    late MockHttpAdapter httpAdapter;
    late Veloquent sdk;

    setUp(() {
      httpAdapter = MockHttpAdapter();
      sdk = Veloquent(
        apiUrl: 'http://localhost:3000',
        http: httpAdapter,
        storage: MockStorageAdapter(),
      );
    });

    test('chat executes a normal HTTP request and returns AiChatResult', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'text': 'Hello there!',
          'json': {'key': 'value'}
        }
      });

      final result = await sdk.ai.chat(
        agent: 'test-agent',
        prompt: 'Hi',
        collection: 'custom-agents',
        messages: [
          const AiMessage(role: 'user', content: 'previous prompt'),
          const AiMessage(role: 'assistant', content: 'previous response'),
        ],
      );

      expect(result.data.text, 'Hello there!');
      expect(result.data.json, {'key': 'value'});

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/collections/custom-agents/ai/chat');
      expect(req?['body']?['agent'], 'test-agent');
      expect(req?['body']?['prompt'], 'Hi');
      
      final msgs = req?['body']?['messages'] as List;
      expect(msgs.length, 2);
      expect(msgs[0]['role'], 'user');
      expect(msgs[1]['content'], 'previous response');
    });

    test('chat with stream=true throws ArgumentError', () async {
      expect(
        () => sdk.ai.chat(
          agent: 'test-agent',
          prompt: 'Hi',
          collection: 'agents',
          stream: true,
        ),
        throwsArgumentError,
      );
    });

    test('chatStream parses SSE stream events', () async {
      final mockData = [
        'data: {"type":"text_delta","id":"msg-1","delta":"Hello"}\n\n',
        'data: {"type":"text_delta","id":"msg-1","delta":" World"}\n\n',
        'data: [DONE]\n\n',
      ];
      final mockByteStream = Stream.fromIterable(mockData).map((s) => utf8.encode(s));
      httpAdapter.mockStreamResponse(mockByteStream);

      final stream = sdk.ai.chatStream(
        agent: 'test-agent',
        prompt: 'Hi',
        collection: 'agents',
      );

      final events = await stream.toList();

      expect(events.length, 2);
      expect(events[0].type, 'text_delta');
      expect(events[0].id, 'msg-1');
      expect(events[0].delta, 'Hello');

      expect(events[1].delta, ' World');

      final req = httpAdapter.lastRequest;
      expect(req?['isStream'], isTrue);
      expect(req?['method'], 'POST');
      expect(req?['url'], 'http://localhost:3000/api/collections/agents/ai/chat');
      expect(req?['body']?['agent'], 'test-agent');
      expect(req?['body']?['prompt'], 'Hi');
      expect(req?['body']?['stream'], isTrue);
    });

    test('chat with attachments sends a multipart request', () async {
      httpAdapter.mockResponse(200, {
        'message': 'OK',
        'data': {
          'text': 'Attachment processed!',
          'json': null
        }
      });

      final upload = FileUpload(
        bytes: [1, 2, 3],
        filename: 'test.txt',
        mimeType: 'text/plain',
      );

      await sdk.ai.chat(
        agent: 'test-agent',
        prompt: 'Look at this file',
        collection: 'agents',
        attachments: [upload],
      );

      final req = httpAdapter.lastRequest;
      expect(req?['method'], 'POST');
      expect(req?['isMultipart'], isTrue);
      expect(req?['fields']?['agent'], 'test-agent');
      expect(req?['fields']?['prompt'], 'Look at this file');
      
      final files = req?['files'] as List?;
      expect(files, isNotNull);
      expect(files!.any((f) => f['field'] == 'attachments' && f['filename'] == 'test.txt'), isTrue);
    });
  });
}
