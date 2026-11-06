import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../domain/session_rules.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/snackbars.dart';

enum _ForgottenChoice { finish, resume, discard }

/// Asks what to do with a session older than 12 h whenever the app is
/// opened or comes back to the foreground (SPEC §6.2 "Vergessene Session").
class ForgottenSessionGuard extends ConsumerStatefulWidget {
  const ForgottenSessionGuard({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ForgottenSessionGuard> createState() =>
      _ForgottenSessionGuardState();
}

class _ForgottenSessionGuardState extends ConsumerState<ForgottenSessionGuard> {
  late final AppLifecycleListener _lifecycle;

  /// Sessions the user chose to continue, until the next app start.
  final _resumed = <int>{};
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_asking || !mounted) return;
    final repo = ref.read(sessionRepositoryProvider);
    final Session? session;
    try {
      session = await repo.getActive();
    } on Object {
      return;
    }
    if (session == null ||
        _resumed.contains(session.id) ||
        !isForgottenSession(session, ref.read(clockProvider).now()) ||
        !mounted) {
      return;
    }
    _asking = true;
    try {
      await _ask(session);
    } finally {
      _asking = false;
    }
  }

  Future<void> _ask(Session session) async {
    final choice = await showDialog<_ForgottenChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(S.forgottenTitle(formatShortDate(session.startedAt))),
        content: const Text(S.forgottenBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, _ForgottenChoice.discard),
            child: const Text(S.discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ForgottenChoice.resume),
            child: const Text(S.resume),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ForgottenChoice.finish),
            child: const Text(S.finishTraining),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final repo = ref.read(sessionRepositoryProvider);
    try {
      switch (choice) {
        case _ForgottenChoice.resume:
          _resumed.add(session.id);
        case _ForgottenChoice.discard:
          final sure = await showConfirmDialog(
            context,
            title: S.discardConfirmTitle,
            body: S.discardConfirmBody,
            confirmLabel: S.discard,
            destructive: true,
          );
          if (!sure) return await _ask(session);
          await repo.delete(session.id);
        case _ForgottenChoice.finish:
          final lastSet = await repo.lastSetTime(session.id);
          await repo.finishSession(
            session.id,
            endedAt: forgottenSessionEnd(session, lastSet),
          );
          if (mounted) await context.push(AppRoutes.summary(session.id));
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
