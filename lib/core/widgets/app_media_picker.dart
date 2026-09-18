import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/bookkeeping/application/attachment_storage_service.dart';

/// Shared file entry point for business documents.
abstract final class AppFilePicker {
  static Future<StoredAttachment?> pick(AttachmentStorageService service) =>
      service.pickAndStore(type: FileType.any, dialogTitle: '选择账单附件');
}

/// Shared image entry point. The UI decides whether to pass gallery or camera.
abstract final class AppImagePicker {
  static Future<StoredAttachment?> gallery(AttachmentStorageService service) =>
      service.pickAndStore(
        type: FileType.image,
        imageSource: ImageSource.gallery,
      );

  static Future<StoredAttachment?> camera(AttachmentStorageService service) =>
      service.pickAndStore(
        type: FileType.image,
        imageSource: ImageSource.camera,
      );
}
