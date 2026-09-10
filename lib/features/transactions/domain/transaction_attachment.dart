import 'dart:convert';

import 'package:path/path.dart' as p;

/// The attachment shape written by the current bookkeeping flow.
///
/// Attachments deliberately remain metadata-backed in stage one. Stage two
/// will migrate them to their own records without changing the detail page's
/// rendering contract.
class TransactionAttachment {
  const TransactionAttachment({required this.path});

  final String path;

  String get name {
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
