import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/domain/feedback.dart';

import '../../helpers/fake_device.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.8.0: Einstellungen → "Feedback geben".
void main() {
  late AppDatabase db;
  late FakeFeedbackSender sender;
  late FakeFeedbackDraftStore draft;

  setUp(() {
    db = newTestDatabase();
    sender = FakeFeedbackSender();
    draft = FakeFeedbackDraftStore();
  });

  Future<void> openFeedback(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, feedbackSender: sender, feedbackDraft: draft);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    final entry = find.text(S.feedbackTitle);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await settle(tester);
  }

  Finder send() => find.byKey(const ValueKey('feedback-send'));

  testWidgets('send a wish: with version, channel and Android; then gone', (
    tester,
  ) async {
    await openFeedback(tester);
    expect(find.text(S.feedbackNoPersonalData), findsOneWidget);
    expect(
      find.text(S.feedbackSentAlong('0.9.0', 'DEV', 'Android 14 (API 34)')),
      findsOneWidget,
    );
    // Nothing to send yet.
    expect(tester.widget<FilledButton>(send()).onPressed, isNull);

    await tester.tap(find.text(S.feedbackKind(FeedbackKind.feature)));
    await tester.pump();
    expect(
      find.text(S.feedbackTextLabel(FeedbackKind.feature)),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('feedback-text')),
      'Bitte einen Timer für Dehnübungen',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(draft.draft?.text, 'Bitte einen Timer für Dehnübungen');

    await tester.tap(send());
    await settle(tester);
    expect(sender.sent.single, (
      kind: FeedbackKind.feature,
      text: 'Bitte einen Timer für Dehnübungen',
      appVersion: '0.9.0',
      channel: 'DEV',
      androidVersion: 'Android 14 (API 34)',
    ));
    expect(draft.draft, isNull, reason: 'arrived: draft gone');
    expect(find.text(S.feedbackThanks), findsOneWidget);
    expect(find.text(S.settings), findsWidgets, reason: 'back in settings');
    await disposeApp(tester, db);
  });

  testWidgets('sending fails: text kept, browser as fallback; draft returns', (
    tester,
  ) async {
    sender.accept = false;
    await openFeedback(tester);
    await tester.enterText(
      find.byKey(const ValueKey('feedback-text')),
      'Absturz beim Speichern',
    );
    await tester.pump();
    await tester.tap(send());
    await settle(tester);
    expect(find.byKey(const ValueKey('feedback-failed')), findsOneWidget);
    expect(find.text(S.feedbackInBrowser), findsOneWidget);
    expect(find.text('Absturz beim Speichern'), findsOneWidget);
    expect(draft.draft?.text, 'Absturz beim Speichern');

    // Leave and come back: the draft is there again.
    await leavePage(tester);
    await settle(tester);
    await tester.tap(find.text(S.feedbackTitle));
    await settle(tester);
    expect(find.text('Absturz beim Speichern'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
