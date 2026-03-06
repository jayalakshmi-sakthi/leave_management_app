import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../utils/universal_file_saver.dart';

class ExcelService {
  /// Generates a highly sophisticated 12-sheet Excel report.
  /// Each sheet represents a month in a calendar grid format.
  /// Summary of leave balances is included on the right side.
  static Future<void> generateAdvancedLeaveReport({
    required String userName,
    required String employeeId,
    required String academicYear,
    required List<Map<String, dynamic>> leaves,
    required List<Map<String, dynamic>> leaveTypes,
  }) async {
    final excel = Excel.createExcel();
    
    // Remove default sheet
    excel.rename('Sheet1', 'Placeholder');
    
    // Academic Year sequence: June to May
    final startYearStr = academicYear.split('-')[0];
    final startYear = int.parse(startYearStr);
    
    final months = [
      {'name': 'June', 'month': 6, 'year': startYear},
      {'name': 'July', 'month': 7, 'year': startYear},
      {'name': 'August', 'month': 8, 'year': startYear},
      {'name': 'September', 'month': 9, 'year': startYear},
      {'name': 'October', 'month': 10, 'year': startYear},
      {'name': 'November', 'month': 11, 'year': startYear},
      {'name': 'December', 'month': 12, 'year': startYear},
      {'name': 'January', 'month': 1, 'year': startYear + 1},
      {'name': 'February', 'month': 2, 'year': startYear + 1},
      {'name': 'March', 'month': 3, 'year': startYear + 1},
      {'name': 'April', 'month': 4, 'year': startYear + 1},
      {'name': 'May', 'month': 5, 'year': startYear + 1},
    ];

    // Approved leaves only for the report
    final approvedLeaves = leaves.where((l) => l['status'] == 'Approved').toList();

    for (var m in months) {
      final sheetName = m['name'] as String;
      final month = m['month'] as int;
      final year = m['year'] as int;
      
      Sheet sheet = excel[sheetName];

      // --- 1. HEADER SECTION ---
      sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("G1"));
      var headerCell = sheet.cell(CellIndex.indexByString("A1"));
      headerCell.value = TextCellValue("LEAVE REPORT - $sheetName $year");
      
      sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("G2"));
      var subHeaderCell = sheet.cell(CellIndex.indexByString("A2"));
      subHeaderCell.value = TextCellValue("Employee: $userName ($employeeId)");

      // --- 2. CALENDAR GRID ---
      final weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
      for (int i = 0; i < 7; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = TextCellValue(weekdays[i]);
      }

      final firstDayOfMonth = DateTime(year, month, 1);
      final lastDayOfMonth = DateTime(year, month + 1, 0);
      final daysInMonth = lastDayOfMonth.day;
      
      // weekday in Dart is 1 (Mon) to 7 (Sun)
      int currentColumn = firstDayOfMonth.weekday - 1; 
      int currentRow = 5;

      for (int day = 1; day <= daysInMonth; day++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: currentColumn, rowIndex: currentRow));
        
        // Find if any leave falls on this day
        final today = DateTime(year, month, day);
        final leaveOnFocus = approvedLeaves.firstWhere(
          (l) {
            final fromObj = l['fromDate'];
            final toObj = l['toDate'];
            
            DateTime from;
            DateTime to;
            
            if (fromObj is DateTime) {
              from = fromObj;
            } else {
              from = (fromObj as dynamic).toDate();
            }
            
            if (toObj is DateTime) {
              to = toObj;
            } else {
              to = (toObj as dynamic).toDate();
            }

            // Normalized dates
            final start = DateTime(from.year, from.month, from.day);
            final end = DateTime(to.year, to.month, to.day);
            return (today.isAtSameMomentAs(start) || today.isAfter(start)) && 
                   (today.isAtSameMomentAs(end) || today.isBefore(end));
          },
          orElse: () => {},
        );

        String cellText = day.toString();
        if (leaveOnFocus.isNotEmpty) {
           final type = leaveOnFocus['leaveType'] as String;
           cellText += " ($type)";
        }
        cell.value = TextCellValue(cellText);

        currentColumn++;
        if (currentColumn > 6) {
          currentColumn = 0;
          currentRow++;
        }
      }

      // --- 3. SUMMARY SECTION (RIGHT SIDE) ---
      int summaryCol = 9; // Column J
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol, rowIndex: 1)).value = TextCellValue("SUMMARY (YTD)");
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol, rowIndex: 3)).value = TextCellValue("TYPE");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 1, rowIndex: 3)).value = TextCellValue("TOTAL");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 2, rowIndex: 3)).value = TextCellValue("USED");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 3, rowIndex: 3)).value = TextCellValue("BALANCE");

      Map<String, double> usedMap = {};
      for (var l in approvedLeaves) {
        final type = l['leaveType'] as String;
        final days = (l['numberOfDays'] ?? 0).toDouble();
        usedMap[type] = (usedMap[type] ?? 0) + days;
      }

      int sRow = 4;
      for (var type in leaveTypes) {
        final name = type['name'] as String;
        final limit = (type['days'] as num).toDouble();
        final used = usedMap[name] ?? 0.0;
        final balance = limit - used;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol, rowIndex: sRow)).value = TextCellValue(name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 1, rowIndex: sRow)).value = DoubleCellValue(limit);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 2, rowIndex: sRow)).value = DoubleCellValue(used);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: summaryCol + 3, rowIndex: sRow)).value = DoubleCellValue(balance); 
        
        sRow++;
      }
    }

    // Remove placeholder
    excel.delete('Placeholder');

    // Save
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final safeId = employeeId.replaceAll(RegExp(r'[^\w]+'), '');
    final fileName = "LeaveReport_${safeId}_$academicYear.xlsx";
    
    await UniversalFileSaver.saveFile(
      bytes: fileBytes,
      fileName: fileName,
    );
  }
}

