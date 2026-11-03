import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';

/// Asks for a number with the numeric keyboard. [parse] turns the text into
/// a value or `null` (invalid → error shown, dialog stays open).
Future<T?> showNumberInputDialog<T>(
  BuildContext context, {
  required String title,
  required String initialText,
  required T? Function(String text) parse,
  bool decimal = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => _NumberInputDialog<T>(
      title: title,
      initialText: initialText,
      parse: parse,
      decimal: decimal,
    ),
  );
}

class _NumberInputDialog<T> extends StatefulWidget {
  const _NumberInputDialog({
    required this.title,
    required this.initialText,
    required this.parse,
    required this.decimal,
  });

  final String title;
  final String initialText;
  final T? Function(String text) parse;
  final bool decimal;

  @override
  State<_NumberInputDialog<T>> createState() => _NumberInputDialogState<T>();
}

class _NumberInputDialogState<T> extends State<_NumberInputDialog<T>> {
  late final _controller = TextEditingController(text: widget.initialText)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialText.length,
    );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.parse(_controller.text);
    if (value == null) {
      setState(() => _error = S.errorNumber);
    } else {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.decimal,
          signed: true,
        ),
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(onPressed: _submit, child: const Text(S.ok)),
      ],
    );
  }
}
