import 'package:flutter/services.dart';

class OcrRect {
  const OcrRect({required this.left, required this.top, required this.right, required this.bottom});
  final double left, top, right, bottom;
  double get centerY => (top + bottom) / 2;
  factory OcrRect.fromMap(Map<Object?, Object?> value) => OcrRect(
    left: (value['left'] as num?)?.toDouble() ?? 0,
    top: (value['top'] as num?)?.toDouble() ?? 0,
    right: (value['right'] as num?)?.toDouble() ?? 0,
    bottom: (value['bottom'] as num?)?.toDouble() ?? 0,
  );
}

class OcrElement {
  const OcrElement({required this.text, required this.rect});
  final String text;
  final OcrRect rect;
}

class LocalOcrResult {
  const LocalOcrResult({required this.text, required this.blocks, this.elements = const []});
  final String text;
  final List<String> blocks;
  final List<OcrElement> elements;
}

class LocalOcrService {
  const LocalOcrService();
  static const _channel = MethodChannel('jizhang/local_ocr');

  Future<LocalOcrResult> recognize(String path) async {
    if (path.trim().isEmpty) throw ArgumentError('OCR 图片路径为空');
    final value = await _channel.invokeMapMethod<String, dynamic>('recognize', {'path': path});
    final text = value?['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw PlatformException(code: 'OCR_EMPTY', message: '未从图片中识别到文字');
    }
    final blocks = (value?['blocks'] as List? ?? const [])
        .map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList(growable: false);
    final elements = <OcrElement>[];
    for (final raw in (value?['elements'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final t = raw['text']?.toString().trim() ?? '';
      final box = raw['box'];
      if (t.isEmpty || box is! Map) continue;
      elements.add(OcrElement(text: t, rect: OcrRect.fromMap(box)));
    }
    return LocalOcrResult(text: text, blocks: blocks, elements: elements);
  }
}
