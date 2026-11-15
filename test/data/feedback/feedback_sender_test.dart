import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/feedback/feedback_sender.dart';
import 'package:gymlog/domain/feedback.dart';

/// 1.8.0: sending to the form and keeping the draft.
void main() {
  const message = (
    kind: FeedbackKind.bug,
    text: 'Absturz beim Speichern, "Satz 2" & äöü',
    appVersion: '1.8.0',
    channel: 'Release',
    androidVersion: 'Android 14 (API 34)',
  );

  test('POST with the form fields; 200 = accepted, else not', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var status = HttpStatus.ok;
    final bodies = <Map<String, String>>[];
    final methods = <String>[];
    server.listen((request) async {
      methods.add(request.method);
      final body = await utf8Body(request);
      bodies.add(Uri.splitQueryString(body));
      request.response.statusCode = status;
      await request.response.close();
    });
    final sender = GoogleFormFeedbackSender(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/formResponse'),
    );

    expect(await sender.send(message), isTrue);
    expect(methods.single, 'POST');
    expect(bodies.single, feedbackFields(message));

    status = HttpStatus.badRequest; // e.g. the form was changed
    expect(await sender.send(message), isFalse);
  });

  test('no connection: not sent, no exception', () async {
    final sender = GoogleFormFeedbackSender(
      endpoint: Uri.parse('http://127.0.0.1:1/formResponse'),
    );
    expect(await sender.send(message), isFalse);
  });

  test('draft: saved, loaded, cleared', () async {
    final dir = Directory.systemTemp.createTempSync('gymlog-feedback');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FileFeedbackDraftStore(() async => dir);
    expect(await store.load(), isNull);
    await store.save(FeedbackKind.feature, 'Ein Wunsch\nmit Umbruch');
    expect(await store.load(), (
      kind: FeedbackKind.feature,
      text: 'Ein Wunsch\nmit Umbruch',
    ));
    await store.clear();
    expect(await store.load(), isNull);
  });
}

Future<String> utf8Body(HttpRequest request) async {
  final bytes = <int>[];
  await for (final chunk in request) {
    bytes.addAll(chunk);
  }
  return String.fromCharCodes(bytes);
}
