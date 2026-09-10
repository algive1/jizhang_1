import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredAttachment {
  const StoredAttachment({required this.name, required this.path});

  final String name;
  final String path;
}

class AttachmentStorageService {
  Future<StoredAttachment?> pickAndStore() async {
    final selected = await FilePicker.pickFile(dialogTitle: '选择账单附件');
    if (selected == null) return null;

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
    await selected.xFile.saveTo(storedPath);
    return StoredAttachment(name: selected.name, path: storedPath);
  }
}

final attachmentStorageServiceProvider = Provider<AttachmentStorageService>(
  (ref) => AttachmentStorageService(),
);
