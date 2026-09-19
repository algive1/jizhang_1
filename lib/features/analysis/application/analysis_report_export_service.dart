import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class AnalysisReportExportService {
  const AnalysisReportExportService();

  Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.5,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final context = boundaryKey.currentContext;
    final boundary = context?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('报表还没有完成渲染');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('报表图片生成失败');
    return bytes.buffer.asUint8List();
  }

  Future<Uint8List> buildPdf(Uint8List pngBytes) async {
    final document = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return document.save();
  }

  Future<void> shareImage(
    BuildContext context,
    GlobalKey boundaryKey, {
    required String fileName,
    String? text,
  }) async {
    final png = await capturePng(boundaryKey);
    await _share(
      context,
      bytes: png,
      mimeType: 'image/png',
      fileName: fileName.endsWith('.png') ? fileName : '$fileName.png',
      text: text,
    );
  }

  Future<void> sharePdf(
    BuildContext context,
    GlobalKey boundaryKey, {
    required String fileName,
    String? text,
  }) async {
    final png = await capturePng(boundaryKey);
    final pdf = await buildPdf(png);
    await _share(
      context,
      bytes: pdf,
      mimeType: 'application/pdf',
      fileName: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
      text: text,
    );
  }

  Future<void> _share(
    BuildContext context, {
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    String? text,
  }) async {
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: mimeType, name: fileName),
        ],
        fileNameOverrides: [fileName],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
  }
}

final analysisReportExportServiceProvider = Provider(
  (ref) => const AnalysisReportExportService(),
);
