import 'dart:io';
import 'dart:typed_data';

import 'package:gymlog/data/io/file_gateway.dart';

/// In-memory file gateway for tests.
final class FakeFileGateway implements FileGateway {
  FakeFileGateway(this.documents);

  final Directory documents;
  final shared = <(String, Uint8List)>[];
  final saved = <(String, Uint8List)>[];
  Uint8List? nextPick;
  bool dismissShare = false;

  @override
  Future<bool> share(Uint8List bytes, String fileName, String mimeType) async {
    if (dismissShare) return false;
    shared.add((fileName, bytes));
    return true;
  }

  @override
  Future<bool> saveAs(Uint8List bytes, String fileName, String mimeType) async {
    saved.add((fileName, bytes));
    return true;
  }

  @override
  Future<Uint8List?> pickFile() async => nextPick;

  @override
  Future<Directory> documentsDirectory() async => documents;
}
