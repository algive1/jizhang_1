import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lightweight XLSX reader used by bill imports.
///
/// It intentionally reads tabular cell text only, but supports shared strings,
/// inline strings, multiple worksheets and Excel numeric date/time cells.
class XlsxTableReader {
  const XlsxTableReader();

  static const _mainNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  List<List<String>> readFirstSheet(List<int> bytes) {
    final sheets = readSheets(bytes);
    if (sheets.isEmpty) {
      throw const FormatException('Excel 文件中没有可读取的工作表');
    }
    return sheets.first;
  }

  List<List<List<String>>> readSheets(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final sheetFiles = archive.files
        .where(
          (file) =>
              file.isFile &&
              file.name.startsWith('xl/worksheets/sheet') &&
              file.name.endsWith('.xml'),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => _worksheetNumber(a.name).compareTo(_worksheetNumber(b.name)),
      );
    if (sheetFiles.isEmpty) {
      throw const FormatException('Excel 文件中没有可读取的工作表');
    }

    final sharedStrings = _readSharedStrings(archive);
    final dateStyleIndexes = _readDateStyleIndexes(archive);
    final uses1904Dates = _uses1904DateSystem(archive);

    return [
      for (final sheetFile in sheetFiles)
        _readSheet(
          sheetFile,
          sharedStrings: sharedStrings,
          dateStyleIndexes: dateStyleIndexes,
          uses1904Dates: uses1904Dates,
        ),
    ];
  }

  List<List<String>> _readSheet(
    ArchiveFile sheetFile, {
    required List<String> sharedStrings,
    required Set<int> dateStyleIndexes,
    required bool uses1904Dates,
  }) {
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
        values[column] = _cellValue(
          cell,
          sharedStrings,
          dateStyleIndexes,
          uses1904Dates,
        );
      }
      if (maxColumn < 0) continue;
      rows.add([
        for (var column = 0; column <= maxColumn; column++)
          values[column] ?? '',
      ]);
    }

    return rows;
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

  Set<int> _readDateStyleIndexes(Archive archive) {
    final file = archive.findFile('xl/styles.xml');
    if (file == null) return const {};

    final document = XmlDocument.parse(utf8.decode(file.content));
    final customFormats = <int, String>{};
    for (final format
        in document.findAllElements('numFmt', namespaceUri: _mainNs)) {
      final id = int.tryParse(format.getAttribute('numFmtId') ?? '');
      final code = format.getAttribute('formatCode');
      if (id != null && code != null) customFormats[id] = code;
    }

    const builtInDateFormatIds = <int>{
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      45,
      46,
      47,
      50,
      51,
      52,
      53,
      54,
      55,
      56,
      57,
      58,
    };

    final cellXfs = document
        .findAllElements('cellXfs', namespaceUri: _mainNs)
        .firstOrNull;
    if (cellXfs == null) return const {};

    final indexes = <int>{};
    final xfs = cellXfs.findElements('xf', namespaceUri: _mainNs).toList();
    for (var index = 0; index < xfs.length; index++) {
      final numFmtId = int.tryParse(xfs[index].getAttribute('numFmtId') ?? '');
      if (numFmtId == null) continue;
      if (builtInDateFormatIds.contains(numFmtId) ||
          _looksLikeDateFormat(customFormats[numFmtId])) {
        indexes.add(index);
      }
    }
    return indexes;
  }

  bool _uses1904DateSystem(Archive archive) {
    final file = archive.findFile('xl/workbook.xml');
    if (file == null) return false;
    final document = XmlDocument.parse(utf8.decode(file.content));
    final workbookPr = document
        .findAllElements('workbookPr', namespaceUri: _mainNs)
        .firstOrNull;
    final value = workbookPr?.getAttribute('date1904')?.toLowerCase();
    return value == '1' || value == 'true';
  }

  bool _looksLikeDateFormat(String? value) {
    if (value == null || value.isEmpty) return false;
    var format = value.toLowerCase();
    format = format.replaceAll(RegExp(r'"[^"]*"'), '');
    format = format.replaceAll(RegExp(r'\\.'), '');
    format = format.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    return RegExp(r'[ydhs]').hasMatch(format);
  }

  String _cellValue(
    XmlElement cell,
    List<String> sharedStrings,
    Set<int> dateStyleIndexes,
    bool uses1904Dates,
  ) {
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
    if (type == 'b') return value == '1' ? 'TRUE' : 'FALSE';

    final styleIndex = int.tryParse(cell.getAttribute('s') ?? '');
    if (styleIndex != null && dateStyleIndexes.contains(styleIndex)) {
      final serial = double.tryParse(value);
      if (serial != null) {
        return _formatExcelDate(serial, uses1904Dates);
      }
    }
    return value;
  }

  String _formatExcelDate(double serial, bool uses1904Dates) {
    final epoch = uses1904Dates
        ? DateTime(1904, 1, 1)
        : DateTime(1899, 12, 30);
    final microseconds =
        (serial * Duration.microsecondsPerDay).round();
    final value = epoch.add(Duration(microseconds: microseconds));
    String two(int number) => number.toString().padLeft(2, '0');
    if (value.hour == 0 && value.minute == 0 && value.second == 0) {
      return '${value.year}-${two(value.month)}-${two(value.day)}';
    }
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  int _worksheetNumber(String name) {
    final match = RegExp(r'sheet(\d+)\.xml$').firstMatch(name);
    return int.tryParse(match?.group(1) ?? '') ?? 1 << 30;
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
