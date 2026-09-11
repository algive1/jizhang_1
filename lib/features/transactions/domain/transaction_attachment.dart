import 'dart:convert';

import 'package:path/path.dart' as p;

/// The attachment shape written by the current bookkeeping flow.
///
/// The legacy metadata parser is retained for import and backward-compatible
/// route snapshots; persisted attachments now use independent records.
class TransactionAttachment {
  const TransactionAttachment({
    required this.path,
    this.id,
    this.bookId,
    this.transactionId,
    this.displayName,
    this.mimeType,
    this.sortOrder,
    this.sizeInBytes,
    this.checksum,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? bookId;
  final String? transactionId;
  final String path;
  final String? displayName;
  final String? mimeType;
  final int? sortOrder;
  final int? sizeInBytes;
  final String? checksum;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get name {
    final storedName = displayName?.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;
    final value = p.basename(path).trim();
    return value.isEmpty || value == '.' ? '未命名附件' : value;
  }

  String get extension {
    final value = p.extension(name).toLowerCase();
    return value.startsWith('.') ? value.substring(1) : value;
  }

  bool get isImage => const {
    'bmp',
    'gif',
    'heic',
    'heif',
    'jpeg',
    'jpg',
    'png',
    'webp',
  }.contains(extension);

  bool get isPdf => extension == 'pdf';

  String get resolvedMimeType => mimeType?.trim().isNotEmpty == true
      ? mimeType!.trim()
      : attachmentMimeType(path);
}

String attachmentMimeType(String path) {
  final extension = p.extension(path).toLowerCase();
  return switch (extension) {
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
    '.docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls' => 'application/vnd.ms-excel',
    '.xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}

class TransactionAttachmentMetadata {
  const TransactionAttachmentMetadata({
    required this.attachments,
    this.hasMalformedAttachments = false,
  });

  final List<TransactionAttachment> attachments;
  final bool hasMalformedAttachments;

  factory TransactionAttachmentMetadata.fromJson(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return const TransactionAttachmentMetadata(attachments: []);
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is! Map) {
        return const TransactionAttachmentMetadata(
          attachments: [],
          hasMalformedAttachments: true,
        );
      }
      final rawAttachments = decoded['attachments'];
      if (rawAttachments == null) {
        return const TransactionAttachmentMetadata(attachments: []);
      }
      if (rawAttachments is! List) {
        return const TransactionAttachmentMetadata(
          attachments: [],
          hasMalformedAttachments: true,
        );
      }

      final attachments = <TransactionAttachment>[];
      var malformed = false;
      for (final raw in rawAttachments) {
        final path = switch (raw) {
          String value => value.trim(),
          Map value =>
            value['path'] is String ? (value['path'] as String).trim() : '',
          _ => '',
        };
        if (path.isEmpty) {
          malformed = true;
          continue;
        }
        attachments.add(TransactionAttachment(path: path));
      }
      return TransactionAttachmentMetadata(
        attachments: List.unmodifiable(attachments),
        hasMalformedAttachments: malformed,
      );
    } on FormatException {
      return const TransactionAttachmentMetadata(
        attachments: [],
        hasMalformedAttachments: true,
      );
    }
  }
}
