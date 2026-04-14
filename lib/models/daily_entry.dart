import 'package:intl/intl.dart';

class DailyEntry {
  final int? id;
  final String date;
  final int totalEnrollment;
  final int presentStudents;
  final int studentsAte;
  final String dishPrepared;
  final String mainGrain;
  final double grainUsedKg;
  final double cookingExpense;
  final String remarks;
  final DateTime createdAt;

  DailyEntry({
    this.id,
    required this.date,
    required this.totalEnrollment,
    required this.presentStudents,
    required this.studentsAte,
    required this.dishPrepared,
    required this.mainGrain,
    required this.grainUsedKg,
    required this.cookingExpense,
    this.remarks = '',
    DateTime? createdAt,
    bool skipValidation = false,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (!skipValidation) {
      _validateInputs();
    }
  }

  void _validateInputs() {
    if (totalEnrollment < 0) throw ArgumentError('कुल नामांकन ऋणात्मक नहीं हो सकता');
    if (presentStudents < 0) throw ArgumentError('उपस्थित छात्र ऋणात्मक नहीं हो सकते');
    if (studentsAte < 0) throw ArgumentError('भोजन करने वाले छात्र ऋणात्मक नहीं हो सकते');
    if (presentStudents > totalEnrollment) throw ArgumentError('उपस्थित छात्र कुल नामांकन से अधिक नहीं हो सकते');
    if (studentsAte > presentStudents) throw ArgumentError('भोजन करने वाले छात्र उपस्थित छात्रों से अधिक नहीं हो सकते');
    if (grainUsedKg < 0) throw ArgumentError('अनाज की मात्रा ऋणात्मक नहीं हो सकती');
    if (cookingExpense < 0) throw ArgumentError('पकाने का खर्च ऋणात्मक नहीं हो सकता');
    if (date.isEmpty) throw ArgumentError('दिनांक आवश्यक है');
    if (dishPrepared.isEmpty) throw ArgumentError('भोजन का विवरण आवश्यक है');
    if (mainGrain.isEmpty && dishPrepared != 'अवकाश') throw ArgumentError('मुख्य अनाज आवश्यक है');
  }

  static bool isValidDate(String dateString) {
    try {
      final formatter = DateFormat('dd-MM-yyyy');
      formatter.parseStrict(dateString);
      return true;
    } catch (e) {
      return false;
    }
  }

  static DateTime? parseDate(String dateString) {
    if (dateString.isEmpty) return null;
    try {
      if (!isValidDate(dateString)) return null;
      final parts = dateString.split('-');
      if (parts.length != 3) return null;
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day == null || month == null || year == null) return null;
      if (day < 1 || day > 31) return null;
      if (month < 1 || month > 12) return null;
      if (year < 1900 || year > 2100) return null;
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  static Map<String, String> validateFormData({
    required String date,
    required String totalEnrollment,
    required String presentStudents,
    required String studentsAte,
    required String dishPrepared,
    required String mainGrain,
    required double grainUsedKg,
    required double cookingExpense,
  }) {
    Map<String, String> errors = {};

    if (date.isEmpty) {
      errors['date'] = 'दिनांक आवश्यक है';
    } else if (!isValidDate(date)) {
      errors['date'] = 'अमान्य दिनांक प्रारूप (DD-MM-YYYY)';
    } else {
      final parsedDate = parseDate(date);
      if (parsedDate == null) {
        errors['date'] = 'दिनांक प्रसंस्करण में त्रुटि';
      } else {
        final today = DateTime.now();
        final todayMidnight = DateTime(today.year, today.month, today.day);
        if (parsedDate.isAfter(todayMidnight)) {
          errors['date'] = 'भविष्य की तारीख नहीं हो सकती';
        }
      }
    }

    final enrollment = int.tryParse(totalEnrollment);
    if (enrollment == null) {
      errors['totalEnrollment'] = 'कुल नामांकन संख्या में होना चाहिए';
    } else if (enrollment < 0) {
      errors['totalEnrollment'] = 'कुल नामांकन ऋणात्मक नहीं हो सकता';
    } else if (enrollment > 1000) {
      errors['totalEnrollment'] = 'कुल नामांकन 1000 से अधिक नहीं हो सकता';
    }

    final present = int.tryParse(presentStudents);
    if (present == null) {
      errors['presentStudents'] = 'उपस्थित छात्र संख्या में होना चाहिए';
    } else if (present < 0) {
      errors['presentStudents'] = 'उपस्थित छात्र ऋणात्मक नहीं हो सकते';
    } else if (enrollment != null && present > enrollment) {
      errors['presentStudents'] = 'उपस्थित छात्र कुल नामांकन से अधिक नहीं हो सकते';
    }

    final ate = int.tryParse(studentsAte);
    if (ate == null) {
      errors['studentsAte'] = 'भोजन करने वाले छात्र संख्या में होना चाहिए';
    } else if (ate < 0) {
      errors['studentsAte'] = 'भोजन करने वाले छात्र ऋणात्मक नहीं हो सकते';
    } else if (present != null && ate > present) {
      errors['studentsAte'] = 'भोजन करने वाले छात्र उपस्थित छात्रों से अधिक नहीं हो सकते';
    }

    if (dishPrepared.isEmpty) {
      errors['dishPrepared'] = 'भोजन का चयन आवश्यक है';
    }

    if (mainGrain.isEmpty && dishPrepared != 'अवकाश') {
      errors['mainGrain'] = 'मुख्य अनाज आवश्यक है';
    }

    if (grainUsedKg < 0) {
      errors['grainUsedKg'] = 'अनाज की मात्रा ऋणात्मक नहीं हो सकती';
    } else if (grainUsedKg > 100) {
      errors['grainUsedKg'] = 'अनाज की मात्रा 100 किलो से अधिक असामान्य है';
    }

    if (cookingExpense < 0) {
      errors['cookingExpense'] = 'पकाने का खर्च ऋणात्मक नहीं हो सकता';
    } else if (cookingExpense > 10000) {
      errors['cookingExpense'] = 'पकाने का खर्च ₹10,000 से अधिक असामान्य है';
    }

    return errors;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total_enrollment': totalEnrollment,
      'present_students': presentStudents,
      'students_ate': studentsAte,
      'dish_prepared': dishPrepared,
      'main_grain': mainGrain,
      'grain_used_kg': grainUsedKg,
      'cooking_expense': cookingExpense,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DailyEntry.fromMap(Map<String, dynamic> map) {
    return DailyEntry(
      id: map['id'],
      date: map['date'],
      totalEnrollment: map['total_enrollment'],
      presentStudents: map['present_students'],
      studentsAte: map['students_ate'],
      dishPrepared: map['dish_prepared'],
      mainGrain: map['main_grain'],
      grainUsedKg: map['grain_used_kg'],
      cookingExpense: map['cooking_expense'],
      remarks: map['remarks'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      skipValidation: true,
    );
  }
}
