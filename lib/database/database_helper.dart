import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:poshahar_register/models/daily_entry.dart';
import 'package:poshahar_register/models/stock_management.dart';
import 'package:poshahar_register/models/holiday.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = p.join(dbPath, 'poshahar.db');

    return await openDatabase(
      dbFilePath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT UNIQUE,
            total_enrollment INTEGER,
            present_students INTEGER,
            students_ate INTEGER,
            dish_prepared TEXT,
            main_grain TEXT,
            grain_used_kg REAL,
            cooking_expense REAL,
            remarks TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE stock_management (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            gehu_stock REAL,
            chawal_stock REAL,
            last_updated TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE stock_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            grain_type TEXT,
            quantity REAL,
            transaction_type TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE holidays (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            name TEXT,
            type TEXT,
            is_recurring INTEGER DEFAULT 0,
            created_at TEXT
          )
        ''');

        await db.insert('stock_management', {
          'gehu_stock': 100.0,
          'chawal_stock': 50.0,
          'last_updated': DateTime.now().toIso8601String(),
        });

        final commonHolidays = [
          {'date': '26-01-2024', 'name': 'गणतंत्र दिवस', 'type': 'national', 'is_recurring': 1},
          {'date': '15-08-2024', 'name': 'स्वतंत्रता दिवस', 'type': 'national', 'is_recurring': 1},
          {'date': '02-10-2024', 'name': 'गांधी जयंती', 'type': 'national', 'is_recurring': 1},
        ];
        for (final holiday in commonHolidays) {
          await db.insert('holidays', {
            ...holiday,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE daily_entries_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT UNIQUE,
              total_enrollment INTEGER,
              present_students INTEGER,
              students_ate INTEGER,
              dish_prepared TEXT,
              main_grain TEXT,
              grain_used_kg REAL,
              cooking_expense REAL,
              remarks TEXT,
              created_at TEXT
            )
          ''');
          await db.execute('''
            INSERT INTO daily_entries_new
            SELECT id, date, total_enrollment, present_students, students_ate,
              dish_prepared, main_grain, grain_used_kg,
              CAST(cooking_expense AS REAL) as cooking_expense,
              remarks, created_at
            FROM daily_entries
          ''');
          await db.execute('DROP TABLE daily_entries');
          await db.execute('ALTER TABLE daily_entries_new RENAME TO daily_entries');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE holidays (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT,
              name TEXT,
              type TEXT,
              is_recurring INTEGER DEFAULT 0,
              created_at TEXT
            )
          ''');
          final commonHolidays = [
            {'date': '26-01-2024', 'name': 'गणतंत्र दिवस', 'type': 'national', 'is_recurring': 1},
            {'date': '15-08-2024', 'name': 'स्वतंत्रता दिवस', 'type': 'national', 'is_recurring': 1},
            {'date': '02-10-2024', 'name': 'गांधी जयंती', 'type': 'national', 'is_recurring': 1},
          ];
          for (final holiday in commonHolidays) {
            await db.insert('holidays', {
              ...holiday,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      },
    );
  }

  Future<int> insertDailyEntry(DailyEntry entry) async {
    final db = await database;
    return await db.insert('daily_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> saveEntryWithStockUpdate(
    DailyEntry entry,
    StockManagement updatedStock, {
    bool isEdit = false,
    double stockDifference = 0.0,
    String? oldGrainType,
    double? oldGrainUsage,
  }) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.insert('daily_entries', entry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        if (updatedStock.id != null) {
          await txn.update('stock_management', updatedStock.toMap(),
              where: 'id = ?', whereArgs: [updatedStock.id]);
        } else {
          await txn.insert('stock_management', updatedStock.toMap());
        }

        if (isEdit) {
          if (oldGrainType != null && oldGrainType != entry.mainGrain && oldGrainUsage != null) {
            await txn.insert('stock_transactions', {
              'date': entry.date,
              'grain_type': oldGrainType,
              'quantity': oldGrainUsage,
              'transaction_type': 'ENTRY_EDIT_RESTORE',
              'created_at': DateTime.now().toIso8601String(),
            });
            await txn.insert('stock_transactions', {
              'date': entry.date,
              'grain_type': entry.mainGrain,
              'quantity': -entry.grainUsedKg,
              'transaction_type': 'ENTRY_EDIT_NEW',
              'created_at': DateTime.now().toIso8601String(),
            });
          } else {
            await txn.insert('stock_transactions', {
              'date': entry.date,
              'grain_type': entry.mainGrain,
              'quantity': -stockDifference,
              'transaction_type': 'ENTRY_EDIT_ADJUSTMENT',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        } else {
          await txn.insert('stock_transactions', {
            'date': entry.date,
            'grain_type': entry.mainGrain,
            'quantity': -entry.grainUsedKg,
            'transaction_type': 'MEAL_PREPARATION',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      });
      return true;
    } catch (e) {
      print('Transaction failed: $e');
      return false;
    }
  }

  Future<bool> deleteEntryWithStockRestore(
      int entryId, DailyEntry entryToDelete, StockManagement restoredStock) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete('daily_entries', where: 'id = ?', whereArgs: [entryId]);
        await txn.update('stock_management', restoredStock.toMap(),
            where: 'id = ?', whereArgs: [restoredStock.id]);
        await txn.insert('stock_transactions', {
          'date': entryToDelete.date,
          'grain_type': entryToDelete.mainGrain,
          'quantity': entryToDelete.grainUsedKg,
          'transaction_type': 'ENTRY_DELETION_RESTORE',
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      return true;
    } catch (e) {
      print('Delete transaction failed: $e');
      return false;
    }
  }

  Future<List<DailyEntry>> getDailyEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('daily_entries', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => DailyEntry.fromMap(maps[i]));
  }

  Future<StockManagement?> getCurrentStock() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('stock_management', orderBy: 'last_updated DESC', limit: 1);
    if (maps.isNotEmpty) return StockManagement.fromMap(maps.first);
    return null;
  }

  Future<int> updateStock(StockManagement stock) async {
    final db = await database;
    if (stock.id != null) {
      return await db.update('stock_management', stock.toMap(),
          where: 'id = ?', whereArgs: [stock.id]);
    } else {
      return await db.insert('stock_management', stock.toMap());
    }
  }

  Future<void> deleteDailyEntry(int id) async {
    final db = await database;
    await db.delete('daily_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> validateEntry(DailyEntry entry) async {
    if (entry.date.isEmpty) return false;
    if (entry.totalEnrollment < 0) return false;
    if (entry.presentStudents < 0) return false;
    if (entry.studentsAte < 0) return false;
    if (entry.grainUsedKg < 0) return false;
    if (entry.cookingExpense < 0) return false;
    if (entry.presentStudents > entry.totalEnrollment) return false;
    if (entry.studentsAte > entry.presentStudents) return false;

    final db = await database;
    final existing = await db.query('daily_entries',
        where: 'date = ? AND id != ?', whereArgs: [entry.date, entry.id ?? -1]);
    return existing.isEmpty;
  }

  Future<Map<String, dynamic>> validateStockAvailability(
      String grainType, double required) async {
    final stock = await getCurrentStock();
    if (stock == null) return {'valid': false, 'message': 'स्टॉक डेटा उपलब्ध नहीं'};

    double available = 0;
    if (grainType == 'गेहूँ') {
      available = stock.gehuStock;
    } else if (grainType == 'चावल') {
      available = stock.chawalStock;
    } else {
      return {'valid': false, 'message': 'अमान्य अनाज प्रकार'};
    }

    if (available < required) {
      return {
        'valid': false,
        'message':
            'अपर्याप्त स्टॉक: $grainType (उपलब्ध: ${available.toStringAsFixed(1)} किलो, आवश्यक: ${required.toStringAsFixed(1)} किलो)'
      };
    }
    return {'valid': true, 'available': available, 'required': required};
  }

  Future<List<Map<String, dynamic>>> getStockTransactions({int limit = 50}) async {
    final db = await database;
    return await db.query('stock_transactions',
        orderBy: 'created_at DESC', limit: limit);
  }

  Future<int> insertHoliday(Holiday holiday) async {
    final db = await database;
    return await db.insert('holidays', holiday.toMap());
  }

  Future<List<Holiday>> getHolidays() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('holidays', orderBy: 'date ASC');
    return List.generate(maps.length, (i) => Holiday.fromMap(maps[i]));
  }

  Future<List<Holiday>> getHolidaysForDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('holidays', where: 'date = ?', whereArgs: [date]);
    final exactMatches = List.generate(maps.length, (i) => Holiday.fromMap(maps[i]));

    final allHolidays = await getHolidays();
    final recurringMatches = allHolidays
        .where((holiday) => holiday.isRecurring && holiday.appliesToDate(date))
        .toList();

    final Set<String> addedHolidays = {};
    final List<Holiday> result = [];
    for (final holiday in [...exactMatches, ...recurringMatches]) {
      final key = '${holiday.date}-${holiday.name}';
      if (!addedHolidays.contains(key)) {
        addedHolidays.add(key);
        result.add(holiday);
      }
    }
    return result;
  }

  Future<bool> isHoliday(String date) async {
    final holidays = await getHolidaysForDate(date);
    return holidays.isNotEmpty;
  }

  Future<void> deleteHoliday(int id) async {
    final db = await database;
    await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateHoliday(Holiday holiday) async {
    final db = await database;
    return await db.update('holidays', holiday.toMap(),
        where: 'id = ?', whereArgs: [holiday.id]);
  }

  bool isWeekend(String date) {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return false;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return false;
      final parsedDate = DateTime(year, month, day);
      return parsedDate.weekday == 7;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSchoolClosed(String date) async {
    return isWeekend(date) || await isHoliday(date);
  }
}
