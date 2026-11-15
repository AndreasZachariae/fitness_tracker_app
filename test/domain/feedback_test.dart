import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/feedback.dart';

/// 1.8.0: feedback to the Google form.
void main() {
  const message = (
    kind: FeedbackKind.feature,
    text: '  Zeile 1, "zitiert" & äöüß\nZeile 2  ',
    appVersion: '1.8.0-dev.70',
    channel: 'DEV',
    androidVersion: 'Android 14 (API 34)',
  );

  test('fields: option texts exactly as in the form, text trimmed', () {
    expect(feedbackFields(message), {
      FeedbackForm.kind: 'Funktionswunsch',
      FeedbackForm.text: 'Zeile 1, "zitiert" & äöüß\nZeile 2',
      FeedbackForm.appVersion: '1.8.0-dev.70',
      FeedbackForm.channel: 'DEV',
      FeedbackForm.androidVersion: 'Android 14 (API 34)',
    });
    expect(FeedbackKind.bug.formValue, 'Bug');
    // Unknown Android version: the optional field is left out.
    final fields = feedbackFields((
      kind: FeedbackKind.bug,
      text: 'x',
      appVersion: '1.8.0',
      channel: 'Release',
      androidVersion: '',
    ));
    expect(fields.containsKey(FeedbackForm.androidVersion), isFalse);
    expect(
      cleanFeedbackText('a' * 2500),
      hasLength(FeedbackForm.maxTextLength),
    );
  });

  test('prefilled link: the form with every value, long text shortened', () {
    final uri = prefilledFeedbackUri(message);
    expect(uri.host, 'docs.google.com');
    expect(uri.path, endsWith('/viewform'));
    expect(uri.queryParameters['usp'], 'pp_url');
    expect(
      uri.queryParameters[FeedbackForm.text],
      'Zeile 1, "zitiert" & äöüß\nZeile 2',
    );
    expect(uri.queryParameters[FeedbackForm.kind], 'Funktionswunsch');
    final long = prefilledFeedbackUri((
      kind: FeedbackKind.bug,
      text: 'b' * 1900,
      appVersion: '1.8.0',
      channel: 'Release',
      androidVersion: '',
    ));
    final text = long.queryParameters[FeedbackForm.text]!;
    expect(text, hasLength(FeedbackForm.maxLinkTextLength + 1));
    expect(text, endsWith('…'));
    expect(FeedbackForm.submitUri.toString(), endsWith('/formResponse'));
  });

  test('Android version label', () {
    expect(androidVersionLabel(34), 'Android 14 (API 34)');
    expect(androidVersionLabel(32), 'Android 12L (API 32)');
    expect(androidVersionLabel(40), 'API 40');
    expect(androidVersionLabel(null), '');
  });
}
