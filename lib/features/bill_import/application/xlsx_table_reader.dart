import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Minimal XLSX reader for tabular imports.
///
/// We intentionally keep this reader narrow: it reads the first worksheet and
/// returns displayed cell text. That is enough for exported bookkeeping files
/// while avoiding a heavyweight spreadsheet dependency in the app.
class XlsxTableReader {
  const XlsxTableReader();

  static const _mainNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  List<List<String>> readFirstSheet(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final sheetFile =
        archive.findFile('xl/worksheets/sheet1.xml') ??
        _firstWorksheetFile(archive);
    if (sheetFile == null) {
      throw const FormatException('Excel 文件中没有可读取的工作表');
    }

    final sharedStrings = _readSharedStrings(archive);
    final document = XmlDocument.parse(utf8.decode(sheetFile.content));
    final rows = <List<String>>[];

    for (final row in document.findAllElements('row', namespaceUri: _mainNs)) {
      final values = <int, String>{};
      var maxColumn = -1;
      for (final cell in row.findElements('c', namespaceUri: _mainNs)) {
        final reference = cell.getAttribute('r') ?? '';
        final column = _columnIndex(reference);
        if (column < 0) continue;
        maxColumn = column > maxColumn ? column : maxColumn;
        values[column] = _cellValue(cell, sharedStrings);
      }
      if (maxColumn < 0) continue;
      rows.add([
        for (var column = 0; column <= maxColumn; column++)
          values[column] ?? '',
      ]);
    }

    return rows;
  }

  ArchiveFile? _firstWorksheetFile(Archive archive) {
    final candidates = archive.files
        .where(
          (file) =>
              file.isFile &&
              file.name.startsWith('xl/worksheets/sheet') &&
              file.name.endsWith('.xml'),
        )
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    return candidates.firstOrNull;
  }

  List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];
    final document = XmlDocument.parse(utf8.decode(file.content));
    return [
      for (final item in document.findAllElements('si', namespaceUri: _mainNs))
        item
            .findAllElements('t', namespaceUri: _mainNs)
            .map((node) => node.innerText)
            .join(),
    ];
  }

  String _cellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell
          .findAllElements('t', namespaceUri: _mainNs)
          .map((node) => node.innerText)
          .join();
    }

    final value = cell
        .findElements('v', namespaceUri: _mainNs)
        .map((node) => node.innerText)
        .firstOrNull;
    if (value == null) return '';

    if (type == 's') {
      final index = int.tryParse(value);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }
    return value;
  }

  int _columnIndex(String reference) {
    if (reference.isEmpty) return -1;
    var result = 0;
    var foundLetter = false;
    for (final codeUnit in reference.codeUnits) {
      final upper = codeUnit >= 97 && codeUnit <= 122 ? codeUnit - 32 : codeUnit;
      if (upper < 65 || upper > 90) break;
      foundLetter = true;
      result = result * 26 + upper - 64;
    }
    return foundLetter ? result - 1 : -1;
  }
}
