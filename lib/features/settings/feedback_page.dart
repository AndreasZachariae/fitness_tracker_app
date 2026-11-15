import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/feedback/feedback_sender.dart';
import '../../data/providers.dart';
import '../../domain/feedback.dart';
import '../../widgets/snackbars.dart';
import '../notifications/reminder_sync.dart';

/// Einstellungen → "Feedback geben" (1.8.0): a bug or a wish as text, sent
/// from the app to the GymLog feedback form on Google (no account, no
/// sign-in). The text stays saved until Google accepted it; when sending
/// fails, the form can be opened in the browser, filled in.
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _text = TextEditingController();
  FeedbackKind _kind = FeedbackKind.bug;
  bool _sending = false;
  bool _failed = false;
  Timer? _saveDraft;

  /// Read once: also used in [dispose], when ref may not be used any more.
  late final FeedbackDraftStore _store = ref.read(feedbackDraftStoreProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    final draft = await _store.load();
    if (draft == null || !mounted || _text.text.isNotEmpty) return;
    setState(() {
      _kind = draft.kind;
      _text.text = draft.text;
    });
  }

  @override
  void dispose() {
    _saveDraft?.cancel();
    if (_text.text.trim().isNotEmpty) {
      unawaited(_store.save(_kind, _text.text));
    }
    _text.dispose();
    super.dispose();
  }

  /// Keeps the draft while typing (also when the app is closed).
  void _changed() {
    setState(() => _failed = false);
    _saveDraft?.cancel();
    _saveDraft = Timer(const Duration(milliseconds: 500), () {
      unawaited(
        _text.text.trim().isEmpty
            ? _store.clear()
            : _store.save(_kind, _text.text),
      );
    });
  }

  FeedbackMessage _message() => (
    kind: _kind,
    text: _text.text,
    appVersion: ref.read(appInfoProvider).value?.version ?? '',
    channel: isDevBuild ? 'DEV' : 'Release',
    androidVersion: androidVersionLabel(ref.read(androidSdkProvider).value),
  );

  Future<void> _send() async {
    if (_text.text.trim().isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _failed = false;
    });
    final ok = await ref.read(feedbackSenderProvider).send(_message());
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _sending = false;
        _failed = true;
      });
      return;
    }
    _saveDraft?.cancel();
    await _store.clear();
    _text.clear();
    if (!mounted) return;
    setState(() => _sending = false);
    showMessage(context, S.feedbackThanks);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Shown so the user sees what goes along.
    final version = ref.watch(appInfoProvider).value?.version ?? '–';
    final android = androidVersionLabel(ref.watch(androidSdkProvider).value);
    final empty = _text.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text(S.feedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SegmentedButton<FeedbackKind>(
            key: const ValueKey('feedback-kind'),
            segments: [
              for (final k in FeedbackKind.values)
                ButtonSegment(
                  value: k,
                  icon: Icon(
                    k == FeedbackKind.bug
                        ? Icons.bug_report_outlined
                        : Icons.lightbulb_outline,
                  ),
                  label: Text(S.feedbackKind(k)),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (v) {
              setState(() => _kind = v.first);
              _changed();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('feedback-text'),
            controller: _text,
            minLines: 5,
            maxLines: 12,
            maxLength: FeedbackForm.maxTextLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: S.feedbackTextLabel(_kind),
              hintText: S.feedbackTextHint(_kind),
              alignLabelWithHint: true,
              helperText: S.feedbackNoPersonalData,
              helperMaxLines: 2,
            ),
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 8),
          Text(
            S.feedbackSentAlong(
              version,
              isDevBuild ? 'DEV' : 'Release',
              android,
            ),
            key: const ValueKey('feedback-along'),
            style: muted,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('feedback-send'),
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? S.feedbackSending : S.feedbackSend),
            onPressed: empty || _sending ? null : _send,
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(
              S.feedbackFailed,
              key: const ValueKey('feedback-failed'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text(S.feedbackInBrowser),
              onPressed: () =>
                  openInBrowser(prefilledFeedbackUri(_message()).toString()),
            ),
          ],
        ],
      ),
    );
  }
}
