/// Feedback from the app to the GymLog feedback form on Google Forms
/// (1.8.0). Pure Dart: the fields of the form and the addresses.
library;

/// Kind of feedback; [formValue] is the option text in the form, exactly.
enum FeedbackKind {
  bug('Bug'),
  feature('Funktionswunsch');

  const FeedbackKind(this.formValue);

  final String formValue;
}

/// The public form "GymLog Feedback" (no sign-in, no e-mail addresses).
/// Its id and field numbers are not secret: anyone can open the form.
abstract final class FeedbackForm {
  static const id = '1FAIpQLSd82s3DDN66toHKX6fiwdhDY5c5QiDEOJ_1_qZXbwxTKEz95g';
  static const base = 'https://docs.google.com/forms/d/e/$id';

  /// Where the app sends the answer (HTTPS POST).
  static final submitUri = Uri.parse('$base/formResponse');

  static const kind = 'entry.174375934';
  static const text = 'entry.436842667';
  static const appVersion = 'entry.236193311';
  static const channel = 'entry.2091464426';
  static const androidVersion = 'entry.943036014';

  /// Longest description; longer text is cut (the form has no limit, but a
  /// prefilled browser link must stay short).
  static const maxTextLength = 2000;

  /// Characters of the description in the browser link at most.
  static const maxLinkTextLength = 1200;
}

/// One message to the form.
typedef FeedbackMessage = ({
  FeedbackKind kind,
  String text,
  String appVersion,

  /// "DEV" or "Release" (options of the form).
  String channel,

  /// "Android 14 (API 34)"; empty when unknown.
  String androidVersion,
});

/// The trimmed description, at most [FeedbackForm.maxTextLength] characters.
String cleanFeedbackText(String text) {
  final t = text.trim();
  return t.length <= FeedbackForm.maxTextLength
      ? t
      : t.substring(0, FeedbackForm.maxTextLength);
}

/// The form fields of [m].
Map<String, String> feedbackFields(FeedbackMessage m) => {
  FeedbackForm.kind: m.kind.formValue,
  FeedbackForm.text: cleanFeedbackText(m.text),
  FeedbackForm.appVersion: m.appVersion,
  FeedbackForm.channel: m.channel,
  if (m.androidVersion.isNotEmpty)
    FeedbackForm.androidVersion: m.androidVersion,
};

/// The form in the browser with everything filled in (fallback when sending
/// from the app fails). Long text is shortened with "…".
Uri prefilledFeedbackUri(FeedbackMessage m) {
  final fields = feedbackFields(m);
  final text = fields[FeedbackForm.text]!;
  if (text.length > FeedbackForm.maxLinkTextLength) {
    fields[FeedbackForm.text] =
        '${text.substring(0, FeedbackForm.maxLinkTextLength)}…';
  }
  return Uri.parse('${FeedbackForm.base}/viewform')
      .replace(queryParameters: {'usp': 'pp_url', ...fields});
}

/// "Android 14 (API 34)" for an Android API level; "API 37" when the
/// release is not known yet; empty without a level.
String androidVersionLabel(int? sdkInt) {
  if (sdkInt == null || sdkInt <= 0) return '';
  const releases = {
    24: '7.0',
    25: '7.1',
    26: '8.0',
    27: '8.1',
    28: '9',
    29: '10',
    30: '11',
    31: '12',
    32: '12L',
    33: '13',
    34: '14',
    35: '15',
    36: '16',
  };
  final release = releases[sdkInt];
  return release == null ? 'API $sdkInt' : 'Android $release (API $sdkInt)';
}
