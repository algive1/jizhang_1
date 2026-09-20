import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_service.dart';

void main() {
  test('generic XLSX scans later sheets and converts numeric Excel dates', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'xl/sharedStrings.xml',
          _sharedStrings([
            '说明',
            '请勿修改',
            '时间',
            '类型',
            '金额',
            '分类',
            '账户',
            '支出',
            '餐饮',
            '现金',
          ]),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/styles.xml',
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<numFmts count="1">'
          '<numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/>'
          '</numFmts>'
          '<cellXfs count="2">'
          '<xf numFmtId="0"/>'
          '<xf numFmtId="164" applyNumberFormat="1"/>'
          '</cellXfs>'
          '</styleSheet>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet1.xml',
          _worksheet([
            ['<c r="A1" t="s"><v>0</v></c>'],
            ['<c r="A2" t="s"><v>1</v></c>'],
          ]),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet2.xml',
          _worksheet([
            [
              '<c r="A1" t="s"><v>2</v></c>',
              '<c r="B1" t="s"><v>3</v></c>',
              '<c r="C1" t="s"><v>4</v></c>',
              '<c r="D1" t="s"><v>5</v></c>',
              '<c r="E1" t="s"><v>6</v></c>',
            ],
            [
              '<c r="A2" s="1"><v>46273.354166666664</v></c>',
              '<c r="B2" t="s"><v>7</v></c>',
              '<c r="C2"><v>-18.5</v></c>',
              '<c r="D2" t="s"><v>8</v></c>',
              '<c r="E2" t="s"><v>9</v></c>',
            ],
          ]),
        ),
      );

    final result = const BillImportService().parseXlsx(
      ZipEncoder().encode(archive),
    );

    expect(result.rows, hasLength(1));
    expect(result.rows.single.occurredAt, DateTime(2026, 9, 8, 8, 30));
    expect(result.rows.single.amount, 18.5);
    expect(result.rows.single.sourceAccount, '现金');
  });
}

String _sharedStrings(List<String> values) {
  final body = values.map((value) => '<si><t>$value</t></si>').join();
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'count="${values.length}" uniqueCount="${values.length}">'
      '$body'
      '</sst>';
}

String _worksheet(List<List<String>> rows) {
  final body = <String>[];
  for (var index = 0; index < rows.length; index++) {
    body.add('<row r="${index + 1}">${rows[index].join()}</row>');
  }
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>${body.join()}</sheetData>'
      '</worksheet>';
}
