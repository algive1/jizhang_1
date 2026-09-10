import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GoalCoverStorageService {
  Future<String?> pickAndStore() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: '选择目标封面',
      type: FileType.image,
    );
    if (selected == null) return null;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'goal_covers'));
    await directory.create(recursive: true);
    final extension = p.extension(selected.name);
    final destination = p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await selected.xFile.saveTo(destination);
    return destination;
  }
}

final goalCoverStorageServiceProvider = Provider<GoalCoverStorageService>(
  (ref) => GoalCoverStorageService(),
);
