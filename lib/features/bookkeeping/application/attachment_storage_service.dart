import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AttachmentUploadStatus { uploading, uploaded, failed }

class StoredAttachment {
  const StoredAttachment({
    required this.name,
    required this.path,
    this.status = AttachmentUploadStatus.uploaded,
    this.errorMessage,
    this.sourceFile,
  });

  final String name;
  final String path;
  final AttachmentUploadStatus status;
  final String? errorMessage;
  final PlatformFile? sourceFile;
}

class AttachmentStorageService {
  /// Picks one file and copies it into the app document directory.
  ///
  /// [type] selects the picker kind, so the quick-add "图片" shortcut can open
  /// an image-only picker while "附件" keeps the unrestricted file picker.
  Future<StoredAttachment?> pickAndStore({
    FileType type = FileType.any,
    String dialogTitle = '选择账单附件',
  }) async {
    final selected = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: type,
    );
    if (selected == null) return null;

    try {
      return await _storeSelected(selected);
    } on Object catch (error) {
      return StoredAttachment(
        name: selected.name,
        path: '',
        status: AttachmentUploadStatus.failed,
        errorMessage: _message(error),
        sourceFile: selected,
      );
    }
  }

  Future<StoredAttachment?> retry(StoredAttachment failed) async {
    final source = failed.sourceFile;
    if (source == null) return null;
    try {
      return await _storeSelected(source);
    } on Object catch (error) {
      return StoredAttachment(
        name: source.name,
        path: '',
        status: AttachmentUploadStatus.failed,
        errorMessage: _message(error),
        sourceFile: source,
      );
    }
  }

  Future<StoredAttachment> _storeSelected(PlatformFile selected) async {
    final documents = await getApplicationDocumentsDirectory();
    final attachmentDirectory = Directory(
      p.join(documents.path, 'bookkeeping_attachments'),
    );
    await attachmentDirectory.create(recursive: true);
    final safeName = selected.name.replaceAll(
      RegExp(r'[^\w.\-\u4e00-\u9fa5]'),
      '_',
    );
    final storedPath = p.join(
      attachmentDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}-$safeName',
    );
    try {
      await selected.xFile.saveTo(storedPath);
    } on Object {
      final partial = File(storedPath);
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    return StoredAttachment(
      name: selected.name,
      path: storedPath,
      status: AttachmentUploadStatus.uploaded,
    );
  }

  String _message(Object error) {
    final value = error.toString().trim();
    return value.isEmpty ? '附件保存失败' : value;
  }
}

final attachmentStorageServiceProvider = Provider<AttachmentStorageService>(
  (ref) => AttachmentStorageService(),
);
