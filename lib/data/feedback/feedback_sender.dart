import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/feedback.dart';

/// Sends feedback to the GymLog form on Google Forms (1.8.0).
abstract interface class FeedbackSender {
  /// True when Google accepted the answer.
  Future<bool> send(FeedbackMessage message);
}

/// One HTTPS POST to the public form, only after the user tapped "Senden"
/// (CLAUDE.md rule 6, approved by the human for 1.8.0). No token, no sign-in.
/// Google answers 200 with its confirmation page when the answer is stored;
/// a missing required field or a changed form gives 400.
final class GoogleFormFeedbackSender implements FeedbackSender {
  GoogleFormFeedbackSender({Uri? endpoint})
    : _endpoint = endpoint ?? FeedbackForm.submitUri;

  final Uri _endpoint;

  static const timeout = Duration(seconds: 15);

  @override
  Future<bool> send(FeedbackMessage message) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(_endpoint).timeout(timeout);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(Uri(queryParameters: feedbackFields(message)).query);
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      return response.statusCode == HttpStatus.ok;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

/// The unsent text (1.8.0): kept until Google accepted it, also offline or
/// when the app is closed.
abstract interface class FeedbackDraftStore {
  Future<({FeedbackKind kind, String text})?> load();
  Future<void> save(FeedbackKind kind, String text);
  Future<void> clear();
}

/// A small JSON file in the app's documents directory.
final class FileFeedbackDraftStore implements FeedbackDraftStore {
  FileFeedbackDraftStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/feedback_draft.json');

  @override
  Future<({FeedbackKind kind, String text})?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return (
        kind: FeedbackKind.values.byName(json['kind']! as String),
        text: json['text']! as String,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(FeedbackKind kind, String text) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'kind': kind.name, 'text': text}));
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  }
}
