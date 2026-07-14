import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  var sheet = excel['Sheet1'];

  // Add Headers
  List<TextCellValue> headers = [
    TextCellValue('Title (Required)'),
    TextCellValue('Title AR'),
    TextCellValue('Organization (Required)'),
    TextCellValue('Reference Type (Required)'),
    TextCellValue('Publication Year (Required)'),
    TextCellValue('Language (ar/en)'),
    TextCellValue('Summary'),
    TextCellValue('Source URL'),
    TextCellValue('Vancouver Reference')
  ];

  sheet.appendRow(headers);

  // Add dummy row for example
  List<TextCellValue> exampleRow = [
    TextCellValue('Example Title'),
    TextCellValue('عنوان تجريبي'),
    TextCellValue('World Health Organization'),
    TextCellValue('guideline'),
    TextCellValue('2023'),
    TextCellValue('en'),
    TextCellValue('This is a summary of the reference'),
    TextCellValue('https://example.com'),
    TextCellValue('Author. Title. Journal. 2023;1(1):1-10.')
  ];
  sheet.appendRow(exampleRow);

  var fileBytes = excel.save();
  if (fileBytes != null) {
    File('assets/templates/reference_template.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    print('Template generated successfully.');
  }
}
