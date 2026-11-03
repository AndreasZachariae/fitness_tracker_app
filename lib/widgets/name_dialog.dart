import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';
import '../domain/names.dart';

/// Asks for a name. [onSubmit] saves it and returns an error text to show
/// (dialog stays open) or `null` on success (dialog closes, returns name).
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Future<String?> Function(String name) onSubmit,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(
      title: title,
      confirmLabel: confirmLabel,
      onSubmit: onSubmit,
      initialValue: initialValue,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.onSubmit,
    required this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final Future<String?> Function(String name) onSubmit;
  final String initialValue;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = cleanName(_controller.text);
    if (name.isEmpty) return setState(() => _error = S.errorNameRequired);
    if (name.length > maxNameLength) {
      return setState(() => _error = S.errorNameTooLong);
    }
    setState(() => _busy = true);
    final error = await widget.onSubmit(name);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(name);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: maxNameLength,
        decoration: InputDecoration(
          labelText: S.fieldName,
          errorText: _error,
          counterText: '',
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
