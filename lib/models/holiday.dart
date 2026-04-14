class Holiday {
  final int? id;
  final String date;
  final String name;
  final String type; // 'national', 'local', 'school'
  final bool isRecurring;
  final DateTime createdAt;

  Holiday({
    this.id,
    required this.date,
    required this.name,
    required this.type,
    this.isRecurring = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'name': name,
      'type': type,
      'is_recurring': isRecurring ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      id: map['id'],
      date: map['date'],
      name: map['name'],
      type: map['type'],
      isRecurring: map['is_recurring'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  bool appliesToDate(String checkDate) {
    if (date == checkDate) return true;
    if (isRecurring) {
      final holidayParts = date.split('-');
      final checkParts = checkDate.split('-');
      if (holidayParts.length >= 2 && checkParts.length >= 2) {
        return holidayParts[0] == checkParts[0] && holidayParts[1] == checkParts[1];
      }
    }
    return false;
  }

  String get typeEmoji {
    switch (type) {
      case 'national':
        return '🇮🇳';
      case 'local':
        return '🏘️';
      case 'school':
        return '🏫';
      default:
        return '📅';
    }
  }
}
