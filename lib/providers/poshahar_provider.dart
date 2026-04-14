import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poshahar_register/models/daily_entry.dart';
import 'package:poshahar_register/models/stock_management.dart';
import 'package:poshahar_register/models/holiday.dart';
import 'package:poshahar_register/database/database_helper.dart';
import 'package:poshahar_register/excel_export_service.dart';

class PoshaharProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  double _cookingRate = 6.0;
  double get cookingRate => _cookingRate;

  List<DailyEntry> _entries = [];
  StockManagement? _currentStock;
  List<Holiday> _holidays = [];
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, Map<String, dynamic>> _menuToGrain = {
    'सब्जी रोटी': {'grain': 'गेहूँ', 'portion': 100},
    'दाल चावल': {'grain': 'चावल', 'portion': 100},
    'दाल रोटी': {'grain': 'गेहूँ', 'portion': 100},
    'खिचड़ी चावल': {'grain': 'चावल', 'portion': 100},
    'अवकाश': {'grain': '', 'portion': 0},
  };

  static const Map<int, String> _weekdayMenu = {
    1: 'सब्जी रोटी',
    2: 'दाल चावल',
    3: 'दाल रोटी',
    4: 'खिचड़ी चावल',
    5: 'दाल रोटी',
    6: 'सब्जी रोटी',
    7: 'अवकाश',
  };

  List<DailyEntry> get entries => _entries;
  StockManagement? get currentStock => _currentStock;
  List<Holiday> get holidays => _holidays;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get availableDishes => _menuToGrain.keys.toList();
  Map<String, Map<String, dynamic>> get menuToGrain => _menuToGrain;

  PoshaharProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCookingRate();
    _isLoading = true;
    notifyListeners();
    try {
      _entries = await _dbHelper.getDailyEntries();
      _currentStock = await _dbHelper.getCurrentStock();
      _holidays = await _dbHelper.getHolidays();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'डेटा लोड करने में त्रुटि: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  String getSuggestedDish(DateTime date) {
    return _weekdayMenu[date.weekday] ?? 'दाल चावल';
  }

  Map<String, dynamic> calculateGrainUsage(String dish, int studentsAte) {
    final menuInfo = _menuToGrain[dish];
    if (menuInfo == null) return {'grain': '', 'usage': 0.0, 'expense': 0.0};

    final grainType = menuInfo['grain'] as String;
    final portionGrams = menuInfo['portion'] as int;

    if (dish == 'अवकाश' || grainType.isEmpty) {
      return {'grain': '', 'usage': 0.0, 'expense': 0.0};
    }

    final usageKg = (studentsAte * portionGrams) / 1000.0;
    final cookingExpense = studentsAte * _cookingRate;

    return {'grain': grainType, 'usage': usageKg, 'expense': cookingExpense};
  }

  bool validateStockAvailability(String grain, double required) {
    if (_currentStock == null) return false;
    if (grain == 'गेहूँ') return _currentStock!.gehuStock >= required;
    if (grain == 'चावल') return _currentStock!.chawalStock >= required;
    return false;
  }

  Future<bool> saveDailyEntry(DailyEntry entry) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (entry.studentsAte > entry.presentStudents) {
        _errorMessage = 'भोजन करने वाले छात्र उपस्थित छात्रों से अधिक नहीं हो सकते';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (entry.presentStudents > entry.totalEnrollment) {
        _errorMessage = 'उपस्थित छात्र कुल नामांकन से अधिक नहीं हो सकते';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final entryDate = DailyEntry.parseDate(entry.date);
      if (entryDate == null) {
        _errorMessage = 'अमान्य दिनांक प्रारूप';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      if (entryDate.isAfter(todayMidnight)) {
        _errorMessage = 'भविष्य की तारीख की प्रविष्टि नहीं हो सकती';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final menuInfo = _menuToGrain[entry.dishPrepared];
      if (menuInfo == null) {
        _errorMessage = 'अमान्य भोजन विकल्प';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (entry.dishPrepared != 'अवकाश' && menuInfo['grain'] != entry.mainGrain) {
        _errorMessage = 'भोजन और अनाज का मेल नहीं खाता';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final existingEntry = _entries.where((e) => e.date == entry.date).firstOrNull;

      final calculation = calculateGrainUsage(entry.dishPrepared, entry.studentsAte);
      final grainType = calculation['grain'] as String;
      final newGrainUsage = calculation['usage'] as double;

      double stockDifference = newGrainUsage;
      if (existingEntry != null) {
        final oldCalculation =
            calculateGrainUsage(existingEntry.dishPrepared, existingEntry.studentsAte);
        final oldGrainUsage = oldCalculation['usage'] as double;
        stockDifference = newGrainUsage - oldGrainUsage;

        if (existingEntry.mainGrain != grainType) {
          stockDifference = newGrainUsage;
        }
      }

      if (stockDifference > 0 && grainType.isNotEmpty) {
        final stockValidation =
            await _dbHelper.validateStockAvailability(grainType, stockDifference);
        if (!stockValidation['valid']) {
          _errorMessage = stockValidation['message'];
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (_currentStock != null) {
        double newGehuStock = _currentStock!.gehuStock;
        double newChawalStock = _currentStock!.chawalStock;

        if (existingEntry != null &&
            existingEntry.mainGrain != grainType &&
            grainType.isNotEmpty) {
          if (existingEntry.mainGrain == 'गेहूँ') {
            newGehuStock += existingEntry.grainUsedKg;
          } else if (existingEntry.mainGrain == 'चावल') {
            newChawalStock += existingEntry.grainUsedKg;
          }
          if (grainType == 'गेहूँ') {
            newGehuStock -= newGrainUsage;
          } else if (grainType == 'चावल') {
            newChawalStock -= newGrainUsage;
          }
        } else if (grainType.isNotEmpty) {
          if (grainType == 'गेहूँ') {
            newGehuStock -= stockDifference;
          } else if (grainType == 'चावल') {
            newChawalStock -= stockDifference;
          }
        }

        final updatedStock = StockManagement(
          id: _currentStock!.id,
          gehuStock: newGehuStock,
          chawalStock: newChawalStock,
        );

        final success = await _dbHelper.saveEntryWithStockUpdate(
          entry,
          updatedStock,
          isEdit: existingEntry != null,
          stockDifference: stockDifference,
          oldGrainType: existingEntry?.mainGrain,
          oldGrainUsage: existingEntry?.grainUsedKg,
        );

        if (!success) {
          _errorMessage = 'डेटाबेस ट्रांजैक्शन विफल';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        _errorMessage = 'स्टॉक डेटा उपलब्ध नहीं';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _loadData();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'सेव करने में त्रुटि: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadCookingRate() async {
    final prefs = await SharedPreferences.getInstance();
    _cookingRate = prefs.getDouble('cookingRate') ?? 7.0;
  }

  Future<void> setCookingRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cookingRate', rate);
    _cookingRate = rate;
    notifyListeners();
  }

  Future<bool> setStock(double gehu, double chawal) async {
    try {
      final validation =
          StockManagement.validateStockInput(gehu.toString(), chawal.toString());
      if (validation.isNotEmpty) {
        _errorMessage = validation.values.first;
        notifyListeners();
        return false;
      }

      if (_currentStock == null) {
        final newStock = StockManagement(gehuStock: gehu, chawalStock: chawal);
        await _dbHelper.updateStock(newStock);
      } else {
        final updatedStock = StockManagement(
            id: _currentStock!.id, gehuStock: gehu, chawalStock: chawal);
        await _dbHelper.updateStock(updatedStock);

        final db = await _dbHelper.database;
        await db.insert('stock_transactions', {
          'date': DateTime.now().toIso8601String().split('T')[0],
          'grain_type': 'BOTH',
          'quantity': 0,
          'transaction_type': 'MANUAL_ADJUSTMENT',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _errorMessage = null;
      await _loadData();
      return true;
    } catch (e) {
      _errorMessage = 'स्टॉक सेट करने में त्रुटि: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addStock(double gehu, double chawal) async {
    try {
      if (gehu < 0 || chawal < 0) {
        _errorMessage = 'स्टॉक की मात्रा ऋणात्मक नहीं हो सकती';
        notifyListeners();
        return false;
      }

      if (_currentStock == null) {
        final newStock = StockManagement(gehuStock: gehu, chawalStock: chawal);
        await _dbHelper.updateStock(newStock);
      } else {
        final newGehuStock = _currentStock!.gehuStock + gehu;
        final newChawalStock = _currentStock!.chawalStock + chawal;

        final validation = StockManagement.validateStockInput(
            newGehuStock.toString(), newChawalStock.toString());
        if (validation.isNotEmpty) {
          _errorMessage = 'स्टॉक जोड़ने के बाद: ${validation.values.first}';
          notifyListeners();
          return false;
        }

        final updatedStock = StockManagement(
            id: _currentStock!.id,
            gehuStock: newGehuStock,
            chawalStock: newChawalStock);
        await _dbHelper.updateStock(updatedStock);

        final db = await _dbHelper.database;
        if (gehu > 0) {
          await db.insert('stock_transactions', {
            'date': DateTime.now().toIso8601String().split('T')[0],
            'grain_type': 'गेहूँ',
            'quantity': gehu,
            'transaction_type': 'STOCK_ADDITION',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (chawal > 0) {
          await db.insert('stock_transactions', {
            'date': DateTime.now().toIso8601String().split('T')[0],
            'grain_type': 'चावल',
            'quantity': chawal,
            'transaction_type': 'STOCK_ADDITION',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      _errorMessage = null;
      await _loadData();
      return true;
    } catch (e) {
      _errorMessage = 'स्टॉक अपडेट करने में त्रुटि: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteEntry(int id) async {
    try {
      _isLoading = true;
      notifyListeners();

      final entryToDelete = _entries.firstWhere((entry) => entry.id == id);

      if (_currentStock == null) {
        _errorMessage = 'स्टॉक डेटा उपलब्ध नहीं';
        _isLoading = false;
        notifyListeners();
        return;
      }

      double newGehuStock = _currentStock!.gehuStock;
      double newChawalStock = _currentStock!.chawalStock;

      if (entryToDelete.mainGrain == 'गेहूँ') {
        newGehuStock += entryToDelete.grainUsedKg;
      } else if (entryToDelete.mainGrain == 'चावल') {
        newChawalStock += entryToDelete.grainUsedKg;
      }

      if (newGehuStock > 10000 || newChawalStock > 10000) {
        _errorMessage = 'स्टॉक रिस्टोर करने से असामान्य मात्रा हो जाएगी';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final restoredStock = StockManagement(
          id: _currentStock!.id,
          gehuStock: newGehuStock,
          chawalStock: newChawalStock);

      final success = await _dbHelper.deleteEntryWithStockRestore(
          id, entryToDelete, restoredStock);
      if (!success) {
        _errorMessage = 'डिलीट ट्रांजैक्शन विफल';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _loadData();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'डिलीट करने में त्रुटि: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> exportToExcel() async {
    try {
      final excel.Excel workbook = excel.Excel.createExcel();
      final excel.Sheet sheet = workbook['पोषाहार रजिस्टर'];

      sheet.cell(excel.CellIndex.indexByString('A1')).value = excel.TextCellValue('दिनांक');
      sheet.cell(excel.CellIndex.indexByString('B1')).value = excel.TextCellValue('नामांकन');
      sheet.cell(excel.CellIndex.indexByString('C1')).value = excel.TextCellValue('उपस्थित');
      sheet.cell(excel.CellIndex.indexByString('D1')).value = excel.TextCellValue('भोजन करने वाले');
      sheet.cell(excel.CellIndex.indexByString('E1')).value = excel.TextCellValue('बनाया गया भोजन');
      sheet.cell(excel.CellIndex.indexByString('F1')).value = excel.TextCellValue('मुख्य अनाज');
      sheet.cell(excel.CellIndex.indexByString('G1')).value = excel.TextCellValue('अनाज (किलो)');
      sheet.cell(excel.CellIndex.indexByString('H1')).value = excel.TextCellValue('पकाने की राशि (₹)');
      sheet.cell(excel.CellIndex.indexByString('I1')).value = excel.TextCellValue('टिप्पणी');

      for (int i = 0; i < _entries.length; i++) {
        final entry = _entries[i];
        final row = i + 2;
        sheet.cell(excel.CellIndex.indexByString('A$row')).value = excel.TextCellValue(entry.date);
        sheet.cell(excel.CellIndex.indexByString('B$row')).value = excel.IntCellValue(entry.totalEnrollment);
        sheet.cell(excel.CellIndex.indexByString('C$row')).value = excel.IntCellValue(entry.presentStudents);
        sheet.cell(excel.CellIndex.indexByString('D$row')).value = excel.IntCellValue(entry.studentsAte);
        sheet.cell(excel.CellIndex.indexByString('E$row')).value = excel.TextCellValue(entry.dishPrepared);
        sheet.cell(excel.CellIndex.indexByString('F$row')).value = excel.TextCellValue(entry.mainGrain);
        sheet.cell(excel.CellIndex.indexByString('G$row')).value = excel.DoubleCellValue(entry.grainUsedKg);
        sheet.cell(excel.CellIndex.indexByString('H$row')).value = excel.DoubleCellValue(entry.cookingExpense);
        sheet.cell(excel.CellIndex.indexByString('I$row')).value = excel.TextCellValue(entry.remarks);
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/poshahar_register.xlsx';
      final file = File(path);
      await file.writeAsBytes(workbook.save()!);
      await Share.shareXFiles([XFile(path)], text: 'पोषाहार रजिस्टर Excel रिपोर्ट');
    } catch (e) {
      _errorMessage = 'Excel निर्यात में त्रुटि: $e';
      notifyListeners();
    }
  }

  Future<void> exportMonthlyExcel(BuildContext context) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('Starting monthly Excel export...');

      final monthYear = await MonthlyExcelExportService.showMonthYearPicker(context);
      if (monthYear == null) {
        print('User cancelled month/year selection');
        _isLoading = false;
        notifyListeners();
        return;
      }

      print('Selected month: ${monthYear['month']}, year: ${monthYear['year']}');

      final success = await MonthlyExcelExportService.exportMonthlyData(
        year: monthYear['year']!,
        month: monthYear['month']!,
        dbHelper: _dbHelper,
        provider: this,
      );

      print('Export success: $success');

      if (success) {
        _errorMessage = null;
        print('Monthly Excel export completed successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Excel फाइल Downloads फोल्डर में सेव हो गई!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _errorMessage = 'मासिक Excel निर्यात में त्रुटि हुई - कृपया फिर से कोशिश करें';
        print('Monthly Excel export failed');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'मासिक Excel निर्यात में त्रुटि: $e';
      print('Monthly Excel export error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> exportToPdf() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('पोषाहार रजिस्टर',
                      style: const pw.TextStyle(fontSize: 24)),
                ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: [
                    [
                      'दिनांक', 'नामांकन', 'उपस्थित', 'भोजन करने वाले',
                      'बनाया गया भोजन', 'अनाज (किलो)', 'पकाने की राशि (₹)'
                    ],
                    ..._entries.map((entry) => [
                          entry.date,
                          entry.totalEnrollment.toString(),
                          entry.presentStudents.toString(),
                          entry.studentsAte.toString(),
                          entry.dishPrepared,
                          entry.grainUsedKg.toStringAsFixed(2),
                          entry.cookingExpense.toString(),
                        ]),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/poshahar_register.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(path)], text: 'पोषाहार रजिस्टर PDF रिपोर्ट');
    } catch (e) {
      _errorMessage = 'PDF निर्यात में त्रुटि: $e';
      notifyListeners();
    }
  }

  Future<bool> addHoliday(Holiday holiday) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (isWeekend(holiday.date)) {
        _errorMessage = 'रविवार पहले से ही सप्ताहांत है। अलग से छुट्टी की आवश्यकता नहीं।';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final existingEntries = _entries.where((entry) => entry.date == holiday.date).toList();
      if (existingEntries.isNotEmpty) {
        for (final entry in existingEntries) {
          if (entry.id != null) await deleteEntry(entry.id!);
        }
      }

      await _dbHelper.insertHoliday(holiday);
      await _loadData();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'छुट्टी जोड़ने में त्रुटि: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteHoliday(int id) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _dbHelper.deleteHoliday(id);
      await _loadData();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'छुट्टी हटाने में त्रुटि: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<Holiday>> getHolidaysForDate(String date) async {
    return await _dbHelper.getHolidaysForDate(date);
  }

  Future<bool> isHoliday(String date) async {
    return await _dbHelper.isHoliday(date);
  }

  bool isWeekend(String date) {
    return _dbHelper.isWeekend(date);
  }

  Future<bool> isSchoolClosed(String date) async {
    return await _dbHelper.isSchoolClosed(date);
  }

  Future<Map<String, dynamic>> getDateStatus(String date) async {
    final isWeekendDay = isWeekend(date);
    final holidays = await getHolidaysForDate(date);
    return {
      'isWeekend': isWeekendDay,
      'isHoliday': holidays.isNotEmpty,
      'holidays': holidays,
      'isSchoolClosed': isWeekendDay || holidays.isNotEmpty,
      'reason': isWeekendDay
          ? 'सप्ताहांत'
          : holidays.isNotEmpty
              ? holidays.map((h) => h.name).join(', ')
              : null,
    };
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAuditTrail() async {
    return await _dbHelper.getStockTransactions();
  }
}
