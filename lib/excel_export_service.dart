import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column;
import 'package:poshahar_register/database/database_helper.dart';
import 'package:poshahar_register/providers/poshahar_provider.dart';
import 'package:poshahar_register/models/daily_entry.dart';
import 'package:poshahar_register/models/stock_management.dart';
import 'package:poshahar_register/utils/extensions.dart';

class MonthlyExcelExportService {
  static const Map<int, String> _weekdayMenu = {
    1: 'सब्जी रोटी',   // Monday - Wheat
    2: 'दाल चावल',     // Tuesday - Rice
    3: 'दाल रोटी',     // Wednesday - Wheat
    4: 'खिचड़ी चावल',  // Thursday - Rice
    5: 'दाल रोटी',     // Friday - Wheat
    6: 'सब्जी रोटी',   // Saturday - Wheat
    7: 'अवकाश',        // Sunday - Holiday
  };

  /// Export monthly data to government Excel format
  static Future<bool> exportMonthlyData({
    required int year,
    required int month,
    required DatabaseHelper dbHelper,
    required PoshaharProvider provider,
  }) async {
    try {
      print('Creating Excel workbook...');
      final Workbook workbook = Workbook();
      final Worksheet worksheet = workbook.worksheets[0];

      print('Setting up Excel headers...');
      await _setupExcelHeaders(worksheet);

      print('Getting monthly data for $month/$year...');
      final monthlyData = await _getMonthlyData(year, month, dbHelper, provider);

      print('Found ${monthlyData.entries.length} entries for the month');

      await _fillExcelData(worksheet, monthlyData, year, month);

      print('Styling Excel...');
      _styleExcel(worksheet);

      print('Saving Excel file to Downloads folder...');
      final success = await _saveAndShareExcel(workbook, year, month);
      print('Save and share result: $success');

      workbook.dispose();
      return success;
    } catch (e, stackTrace) {
      print('Excel export error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Set up Excel headers according to government format
  static Future<void> _setupExcelHeaders(Worksheet worksheet) async {
    worksheet.getRangeByName('A1').setText('दिनांक');
    worksheet.getRangeByName('B1').setText('प्रारंभिक शेष गेहूँ');
    worksheet.getRangeByName('C1').setText('प्रारंभिक शेष चावल');
    worksheet.getRangeByName('D1').setText('सप्लायर से प्राप्त गेहूँ');
    worksheet.getRangeByName('E1').setText('सप्लायर से प्राप्त चावल');
    worksheet.getRangeByName('F1').setText('उपयोग गेहूँ (किलो)');
    worksheet.getRangeByName('G1').setText('उपयोग चावल (किलो)');
    worksheet.getRangeByName('H1').setText('शेष गेहूँ');
    worksheet.getRangeByName('I1').setText('शेष चावल');
    worksheet.getRangeByName('J1').setText('बनाये गये भोजन का विवरण');
    worksheet.getRangeByName('K1').setText('कुल नामांकन');
    worksheet.getRangeByName('L1').setText('उपस्थित छात्र');
    worksheet.getRangeByName('M1').setText('लाभान्वित छात्र');
    worksheet.getRangeByName('N1').setText('पकाने की लागत (₹)');
  }

  /// Get all data needed for the monthly report
  static Future<MonthlyReportData> _getMonthlyData(
    int year,
    int month,
    DatabaseHelper dbHelper,
    PoshaharProvider provider,
  ) async {
    // Get all entries for the month
    final allEntries = await dbHelper.getDailyEntries();
    final monthEntries = allEntries.where((entry) {
      final entryDate = DailyEntry.parseDate(entry.date);
      return entryDate != null &&
          entryDate.year == year &&
          entryDate.month == month;
    }).toList();

    // Sort by date
    monthEntries.sort((a, b) {
      final dateA = DailyEntry.parseDate(a.date);
      final dateB = DailyEntry.parseDate(b.date);
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    // Get stock transactions for the month to calculate additions
    final stockTransactions = await dbHelper.getStockTransactions(limit: 500);
    final monthStockAdditions = stockTransactions.where((transaction) {
      final transactionDate = transaction['date'] as String?;
      if (transactionDate == null) return false;
      final parsedDate = DailyEntry.parseDate(transactionDate) ??
          DateTime.tryParse(transactionDate);
      return parsedDate != null &&
          parsedDate.year == year &&
          parsedDate.month == month &&
          transaction['transaction_type'] == 'STOCK_ADDITION';
    }).toList();

    // Calculate starting stock (stock on first day of month)
    final firstDayOfMonth = DateTime(year, month, 1);
    final startingStock = await _calculateStartingStock(
      firstDayOfMonth,
      dbHelper,
      stockTransactions,
    );

    return MonthlyReportData(
      year: year,
      month: month,
      entries: monthEntries,
      stockAdditions: monthStockAdditions,
      startingStock: startingStock,
      cookingRate: provider.cookingRate,
    );
  }

  /// Calculate starting stock for the month
  static Future<StockManagement> _calculateStartingStock(
    DateTime firstDay,
    DatabaseHelper dbHelper,
    List<Map<String, dynamic>> allTransactions,
  ) async {
    final currentStock = await dbHelper.getCurrentStock();

    if (currentStock == null) {
      return StockManagement(
        gehuStock: 100.0,
        chawalStock: 100.0,
        skipValidation: true,
      );
    }

    // Work backwards from current stock to first day of month
    double gehuStock = currentStock.gehuStock;
    double chawalStock = currentStock.chawalStock;

    // Get all entries after the first day and add back their consumption
    final allEntries = await dbHelper.getDailyEntries();
    final entriesAfterFirstDay = allEntries.where((entry) {
      final entryDate = DailyEntry.parseDate(entry.date);
      return entryDate != null &&
          entryDate.isAfter(firstDay.subtract(const Duration(days: 1)));
    }).toList();

    // Add back the grain consumption from entries after the first day
    for (final entry in entriesAfterFirstDay) {
      if (entry.mainGrain == 'गेहूँ') {
        gehuStock += entry.grainUsedKg;
      } else if (entry.mainGrain == 'चावल') {
        chawalStock += entry.grainUsedKg;
      }
    }

    // Subtract any stock additions that happened after the first day
    final stockAdditionsAfterFirstDay = allTransactions.where((transaction) {
      final transactionDate = transaction['date'] as String?;
      if (transactionDate == null) return false;
      final parsedDate = DailyEntry.parseDate(transactionDate) ??
          DateTime.tryParse(transactionDate);
      return parsedDate != null &&
          parsedDate.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          transaction['transaction_type'] == 'STOCK_ADDITION';
    }).toList();

    for (final transaction in stockAdditionsAfterFirstDay) {
      final grainType = transaction['grain_type'] as String? ?? '';
      final quantity = (transaction['quantity'] as num?)?.toDouble() ?? 0.0;
      if (grainType == 'गेहूँ') {
        gehuStock -= quantity;
      } else if (grainType == 'चावल') {
        chawalStock -= quantity;
      }
    }

    return StockManagement(
      gehuStock: gehuStock.clamp(0, double.infinity),
      chawalStock: chawalStock.clamp(0, double.infinity),
      skipValidation: true,
    );
  }

  /// Fill Excel with monthly data
  static Future<void> _fillExcelData(
    Worksheet worksheet,
    MonthlyReportData data,
    int year,
    int month,
  ) async {
    int row = 2; // Start from row 2 (after single header row)

    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Running stock calculation
    double runningGehuStock = data.startingStock.gehuStock;
    double runningChawalStock = data.startingStock.chawalStock;

    // Calculate total stock additions for the month
    double totalGehuAddition = 0;
    double totalChawalAddition = 0;
    for (final addition in data.stockAdditions) {
      final grainType = addition['grain_type'] as String? ?? '';
      final quantity = (addition['quantity'] as num?)?.toDouble() ?? 0.0;
      if (grainType == 'GEHU' || grainType == 'गेहूँ') {
        totalGehuAddition += quantity;
      } else if (grainType == 'CHAWAL' || grainType == 'चावल') {
        totalChawalAddition += quantity;
      }
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(year, month, day);
      final dateString = DailyEntry.formatDate(currentDate);

      // Find entry for this date
      final dayEntry =
          data.entries.firstWhereOrNull((entry) => entry.date == dateString);

      // Get weekday menu
      final weekday = currentDate.weekday;
      final suggestedDish = _weekdayMenu[weekday] ?? 'अवकाश';
      final actualDish = dayEntry?.dishPrepared ?? suggestedDish;

      // Calculate consumption for this day using actual data from entry
      double gehuConsumption = 0;
      double chawalConsumption = 0;
      if (dayEntry != null && dayEntry.studentsAte > 0) {
        if (dayEntry.mainGrain == 'गेहूँ') {
          gehuConsumption = dayEntry.grainUsedKg;
        } else if (dayEntry.mainGrain == 'चावल') {
          chawalConsumption = dayEntry.grainUsedKg;
        }
      }

      // Update running stock (deduct consumption first)
      runningGehuStock -= gehuConsumption;
      runningChawalStock -= chawalConsumption;

      // If there is a stock addition for this day, apply it
      final dayAddition = data.stockAdditions.firstWhereOrNull((addition) {
        final additionDate = addition['date'] as String?;
        return additionDate == dateString;
      });

      if (dayAddition != null) {
        final grainType = dayAddition['grain_type'] as String? ?? '';
        final quantity = (dayAddition['quantity'] as num?)?.toDouble() ?? 0.0;
        if (grainType == 'GEHU' || grainType == 'गेहूँ') {
          runningGehuStock += quantity;
        } else if (grainType == 'CHAWAL' || grainType == 'चावल') {
          runningChawalStock += quantity;
        }
      }

      // ── Fill the row ──────────────────────────────────────────────

      // Date
      worksheet.getRangeByName('A$row').setText(dateString);

      // Starting stock — only on day 1, blank otherwise
      if (day == 1) {
        worksheet.getRangeByName('B$row').setNumber(data.startingStock.gehuStock);
        worksheet.getRangeByName('C$row').setNumber(data.startingStock.chawalStock);
      } else {
        worksheet.getRangeByName('B$row').setText('');
        worksheet.getRangeByName('C$row').setText('');
      }

      // Stock received from supplier
      if (day == 1) {
        // Show month total on first row
        worksheet.getRangeByName('D$row').setNumber(totalGehuAddition);
        worksheet.getRangeByName('E$row').setNumber(totalChawalAddition);
      } else if (dayAddition != null) {
        // Show per-day addition on the day it was received
        final grainType = dayAddition['grain_type'] as String? ?? '';
        final quantity = (dayAddition['quantity'] as num?)?.toDouble() ?? 0.0;
        if (grainType == 'GEHU' || grainType == 'गेहूँ') {
          worksheet.getRangeByName('D$row').setNumber(quantity);
          worksheet.getRangeByName('E$row').setNumber(0);
        } else if (grainType == 'CHAWAL' || grainType == 'चावल') {
          worksheet.getRangeByName('D$row').setNumber(0);
          worksheet.getRangeByName('E$row').setNumber(quantity);
        } else {
          worksheet.getRangeByName('D$row').setNumber(0);
          worksheet.getRangeByName('E$row').setNumber(0);
        }
      } else {
        worksheet.getRangeByName('D$row').setNumber(0);
        worksheet.getRangeByName('E$row').setNumber(0);
      }

      // Daily consumption
      worksheet.getRangeByName('F$row').setNumber(gehuConsumption);
      worksheet.getRangeByName('G$row').setNumber(chawalConsumption);

      // Remaining stock after consumption
      worksheet.getRangeByName('H$row').setNumber(
          runningGehuStock.clamp(0, double.infinity));
      worksheet.getRangeByName('I$row').setNumber(
          runningChawalStock.clamp(0, double.infinity));

      // Dish prepared
      worksheet.getRangeByName('J$row').setText(actualDish);

      // Student numbers
      worksheet.getRangeByName('K$row')
          .setNumber((dayEntry?.totalEnrollment ?? 0).toDouble());
      worksheet.getRangeByName('L$row')
          .setNumber((dayEntry?.presentStudents ?? 0).toDouble());
      worksheet.getRangeByName('M$row')
          .setNumber((dayEntry?.studentsAte ?? 0).toDouble());

      // Cooking cost
      final cookingCost = (dayEntry?.studentsAte ?? 0) * data.cookingRate;
      worksheet.getRangeByName('N$row').setNumber(cookingCost);

      row++;
    }
  }

  /// Apply styling to the Excel
  static void _styleExcel(Worksheet worksheet) {
    // Header styling
    final headerRange = worksheet.getRangeByName('A1:N1');
    headerRange.cellStyle.bold = true;
    headerRange.cellStyle.fontSize = 11;
    headerRange.cellStyle.hAlign = HAlignType.center;
    headerRange.cellStyle.vAlign = VAlignType.center;
    headerRange.cellStyle.borders.all.lineStyle = LineStyle.thin;

    // Data range styling (max 31 days + header = row 35)
    final dataRange = worksheet.getRangeByName('A2:N35');
    dataRange.cellStyle.borders.all.lineStyle = LineStyle.thin;
    dataRange.cellStyle.fontSize = 10;
    dataRange.cellStyle.hAlign = HAlignType.center;

    // Date column alignment
    final dateColumn = worksheet.getRangeByName('A1:A35');
    dateColumn.cellStyle.hAlign = HAlignType.center;

    // Number formatting for stock columns (B through I)
    final stockColumns = worksheet.getRangeByName('B1:I35');
    stockColumns.numberFormat = '#,##0.0';

    // Currency formatting for cost column
    final costColumn = worksheet.getRangeByName('N1:N35');
    costColumn.numberFormat = '₹#,##0.00';

    // Auto-fit all 14 columns
    for (int i = 1; i <= 14; i++) {
      worksheet.autoFitColumn(i);
    }
  }

  /// Save Excel file to Downloads folder
  static Future<bool> _saveAndShareExcel(
      Workbook workbook, int year, int month) async {
    try {
      print('Converting workbook to bytes...');
      final List<int> bytes = workbook.saveAsStream();
      print('Bytes length: ${bytes.length}');

      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          final externalDir = await getExternalStorageDirectory();
          directory =
              externalDir ?? await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      print('Saving to directory: ${directory.path}');

      const monthNames = [
        '',
        'जनवरी',
        'फरवरी',
        'मार्च',
        'अप्रैल',
        'मई',
        'जून',
        'जुलाई',
        'अगस्त',
        'सितंबर',
        'अक्टूबर',
        'नवंबर',
        'दिसंबर',
      ];

      final monthName = monthNames[month];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename =
          'पोषाहार_रजिस्टर_${monthName}_${year}_$timestamp.xlsx';

      print('Creating file: $filename');
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      print('File written successfully, size: ${await file.length()} bytes');
      print('File saved at: ${file.path}');

      if (!await file.exists()) {
        print('Error: File was not created successfully');
        return false;
      }

      print('Excel file saved successfully to Downloads folder');
      return true;
    } catch (e, stackTrace) {
      print('Error saving Excel: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Show month/year picker dialog
  static Future<Map<String, int>?> showMonthYearPicker(
      BuildContext context) async {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    return await showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('📅 माह चुनें'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('कौन सा महीना और साल निर्यात करना है?'),
              const SizedBox(height: 20),
              // Year selection
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'साल चुनें',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(5, (index) {
                  final year = DateTime.now().year - index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  if (value != null) setState(() => selectedYear = value);
                },
              ),
              const SizedBox(height: 16),
              // Month selection
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'महीना चुनें',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1,  child: Text('जनवरी')),
                  DropdownMenuItem(value: 2,  child: Text('फरवरी')),
                  DropdownMenuItem(value: 3,  child: Text('मार्च')),
                  DropdownMenuItem(value: 4,  child: Text('अप्रैल')),
                  DropdownMenuItem(value: 5,  child: Text('मई')),
                  DropdownMenuItem(value: 6,  child: Text('जून')),
                  DropdownMenuItem(value: 7,  child: Text('जुलाई')),
                  DropdownMenuItem(value: 8,  child: Text('अगस्त')),
                  DropdownMenuItem(value: 9,  child: Text('सितंबर')),
                  DropdownMenuItem(value: 10, child: Text('अक्टूबर')),
                  DropdownMenuItem(value: 11, child: Text('नवंबर')),
                  DropdownMenuItem(value: 12, child: Text('दिसंबर')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedMonth = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'year': selectedYear,
                'month': selectedMonth,
              }),
              child: const Text('निर्यात करें'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

/// Holds all data needed to generate the monthly report
class MonthlyReportData {
  final int year;
  final int month;
  final List<DailyEntry> entries;
  final List<Map<String, dynamic>> stockAdditions;
  final StockManagement startingStock;
  final double cookingRate;

  MonthlyReportData({
    required this.year,
    required this.month,
    required this.entries,
    required this.stockAdditions,
    required this.startingStock,
    required this.cookingRate,
  });
}
