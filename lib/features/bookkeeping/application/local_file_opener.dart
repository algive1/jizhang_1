import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

enum LocalFileOpenResult { opened, missing, noHandler, unsupported }

/// Opens an attachment through the platform's registered file application.
///
/// The existence check is intentionally performed before the platform call so
/// a stale metadata path can never be reported as successfully opened.
class LocalFileOpener {
  LocalFileOpener({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'jizhang/file_opener';

  final MethodChannel _channel;

  Future<LocalFileOpenResult> open(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty || !await File(normalizedPath).exists()) {
      return LocalFileOpenResult.missing;
    }
    try {
      final opened = await _channel.invokeMethod<bool>('openFile', {
        'path': normalizedPath,
        'mimeType': _mimeType(normalizedPath),
      });
      return opened == true
          ? LocalFileOpenResult.opened
          : LocalFileOpenResult.noHandler;
    } on MissingPluginException {
      return LocalFileOpenResult.unsupported;
    } on PlatformException catch (error) {
      return switch (error.code) {
        'FILE_NOT_FOUND' => LocalFileOpenResult.missing,
        'NO_HANDLER' => LocalFileOpenResult.noHandler,
        'INVALID_FILE_PATH' => LocalFileOpenResult.unsupported,
        _ => throw StateError(error.message ?? '无法打开附件'),
      };
    }
  }

  String _mimeType(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.bmp' => 'image/bmp',
      '.gif' => 'image/gif',
      '.heic' || '.heif' => 'image/heic',
      '.jpeg' || '.jpg' => 'image/jpeg',
      '.pdf' => 'application/pdf',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.txt' => 'text/plain',
      '.csv' => 'text/csv',
      '.doc' => 'application/msword',
      '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }
}

final localFileOpenerProvider = Provider<LocalFileOpener>(
  (ref) => LocalFileOpener(),
);
