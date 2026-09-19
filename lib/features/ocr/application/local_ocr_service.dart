import 'package:flutter/services.dart';

class LocalOcrResult {
  const LocalOcrResult({required this.text, required this.blocks});
  final String text;
  final List<String> blocks;
}

class LocalOcrService {
  const LocalOcrService();

  static const _channel = MethodChannel('jizhang/local_ocr');

  Future<LocalOcrResult> recognize(String path) async {
    if (path.trim().isEmpty) throw ArgumentError('OCR 图片路径为空');
    final value = await _channel.invokeMapMethod<String, dynamic>(
      'recognize',
      {'path': path},
    );
    final text = value?['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const PlatformException(
        code: 'OCR_EMPTY',
        message: '未从图片中识别到文字',
      );
    }
    final blocks = (value?['blocks'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    return LocalOcrResult(text: text, blocks: blocks);
  }
}
