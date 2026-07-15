import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/reference_model.dart';
import '../../../core/services/supabase_service.dart';
import 'download_helper/download_helper.dart';

class ExcelService {
  Future<void> downloadTemplate() async {
    try {
      final data = await rootBundle.load('assets/templates/reference_template.xlsx');
      final bytes = data.buffer.asUint8List();
      await triggerDownload(bytes, 'reference_template.xlsx');
    } catch (e) {
      throw Exception('Could not download template: $e');
    }
  }

  Future<List<ReferenceModel>> parseExcelFile(Uint8List bytes, String filename, String currentUserId) async {
    if (filename.toLowerCase().endsWith('.csv')) {
      return _parseCsv(bytes, currentUserId);
    }
    
    var excel = Excel.decodeBytes(bytes);
    List<ReferenceModel> references = [];
    final uuid = const Uuid();

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table];
      if (sheet == null) continue;

      bool isFirstRow = true;
      for (var row in sheet.rows) {
        if (isFirstRow) {
          isFirstRow = false; // Skip header
          continue;
        }

        // Check if row is completely empty
        if (row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        // Columns:
        // 0: Title (Required)
        // 1: Title AR
        // 2: Organization (Required)
        // 3: Reference Type (Required)
        // 4: Publication Year (Required)
        // 5: Language (ar/en)
        // 6: Summary
        // 7: Source URL
        // 8: Vancouver Reference

        String title = _getString(row, 0);
        String organization = _getString(row, 2);
        String type = _getString(row, 3);
        int year = int.tryParse(_getString(row, 4)) ?? DateTime.now().year;

        if (title.isEmpty || organization.isEmpty || type.isEmpty) {
          // Skip invalid rows
          continue;
        }

        references.add(ReferenceModel(
          id: uuid.v4(),
          title: title,
          titleAr: _getOptionalString(row, 1),
          organization: organization,
          referenceType: type,
          publicationYear: year,
          language: _getOptionalString(row, 5) ?? 'en',
          summary: _getOptionalString(row, 6),
          sourceUrl: _getOptionalString(row, 7),
          vancouverReference: _getOptionalString(row, 8),
          isActive: true,
          addedBy: currentUserId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }

    return references;
  }

  Future<List<ReferenceModel>> _parseCsv(Uint8List bytes, String currentUserId) async {
    final csvString = utf8.decode(bytes);
    final fields = const CsvToListConverter().convert(csvString);
    List<ReferenceModel> references = [];
    final uuid = const Uuid();

    bool isFirstRow = true;
    for (var row in fields) {
      if (isFirstRow) {
        isFirstRow = false;
        continue;
      }
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      String title = _getCsvString(row, 0);
      String organization = _getCsvString(row, 2);
      String type = _getCsvString(row, 3);
      int year = int.tryParse(_getCsvString(row, 4)) ?? DateTime.now().year;

      if (title.isEmpty || organization.isEmpty || type.isEmpty) {
        continue;
      }

      references.add(ReferenceModel(
        id: uuid.v4(),
        title: title,
        titleAr: _getOptionalCsvString(row, 1),
        organization: organization,
        referenceType: type,
        publicationYear: year,
        language: _getOptionalCsvString(row, 5) ?? 'en',
        summary: _getOptionalCsvString(row, 6),
        sourceUrl: _getOptionalCsvString(row, 7),
        vancouverReference: _getOptionalCsvString(row, 8),
        isActive: true,
        addedBy: currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    return references;
  }

  String _getString(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    return row[index]!.value.toString().trim();
  }

  String? _getOptionalString(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return null;
    final val = row[index]!.value.toString().trim();
    return val.isEmpty ? null : val;
  }

  String _getCsvString(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index].toString().trim();
  }

  String? _getOptionalCsvString(List<dynamic> row, int index) {
    if (index >= row.length) return null;
    final val = row[index].toString().trim();
    return val.isEmpty ? null : val;
  }
}

final excelServiceProvider = Provider<ExcelService>((ref) {
  return ExcelService();
});
