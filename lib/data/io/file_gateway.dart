import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Platform file operations behind an interface, so tests can fake them.
abstract interface class FileGateway {
  /// Opens the share menu. Returns `true` unless the user dismissed it.
  Future<bool> share(Uint8List bytes, String fileName, String mimeType);

  /// Saves straight into Download/GymLog, without a dialog (1.6.1).
  /// Returns where the file lies, e.g. "Download/GymLog/gymlog-….json".
  Future<String> saveToDownloads(
    Uint8List bytes,
    String fileName,
    String mimeType,
  );

  /// "Speichern unter …" via the system file dialog. `true` if saved.
  Future<bool> saveAs(Uint8List bytes, String fileName, String mimeType);

  /// Lets the user pick a file and returns its bytes, `null` if cancelled.
  Future<Uint8List?> pickFile();

  /// App documents directory (for safety copies before an import).
  Future<Directory> documentsDirectory();
}

final class PlatformFileGateway implements FileGateway {
  const PlatformFileGateway();

  @override
  Future<bool> share(Uint8List bytes, String fileName, String mimeType) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
    // Android often cannot tell whether an app was chosen ("unavailable").
    return result.status != ShareResultStatus.dismissed;
  }

  static const _channel = MethodChannel('de.gymlog.app/files');

  @override
  Future<String> saveToDownloads(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async => (await _channel.invokeMethod<String>('saveToDownloads', {
    'name': fileName,
    'mimeType': mimeType,
    'bytes': bytes,
  }))!;

  @override
  Future<bool> saveAs(Uint8List bytes, String fileName, String mimeType) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> pickFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }

  @override
  Future<Directory> documentsDirectory() => getApplicationDocumentsDirectory();
}
