class StockManagement {
  final int? id;
  final double gehuStock;
  final double chawalStock;
  final DateTime lastUpdated;

  StockManagement({
    this.id,
    required this.gehuStock,
    required this.chawalStock,
    DateTime? lastUpdated,
    bool skipValidation = false,
  }) : lastUpdated = lastUpdated ?? DateTime.now() {
    if (!skipValidation) {
      _validateStock();
    }
  }

  void _validateStock() {
    if (gehuStock < 0) throw ArgumentError('गेहूँ का स्टॉक ऋणात्मक नहीं हो सकता');
    if (chawalStock < 0) throw ArgumentError('चावल का स्टॉक ऋणात्मक नहीं हो सकता');
    if (gehuStock > 10000) throw ArgumentError('गेहूँ का स्टॉक 10,000 किलो से अधिक असामान्य है');
    if (chawalStock > 10000) throw ArgumentError('चावल का स्टॉक 10,000 किलो से अधिक असामान्य है');
  }

  static Map<String, String> validateStockInput(String gehu, String chawal) {
    Map<String, String> errors = {};
    final gehuValue = double.tryParse(gehu);
    if (gehuValue == null && gehu.isNotEmpty) {
      errors['gehu'] = 'गेहूँ की मात्रा संख्या में होनी चाहिए';
    } else if (gehuValue != null && gehuValue < 0) {
      errors['gehu'] = 'गेहूँ का स्टॉक ऋणात्मक नहीं हो सकता';
    } else if (gehuValue != null && gehuValue > 10000) {
      errors['gehu'] = 'गेहूँ का स्टॉक 10,000 किलो से अधिक असामान्य है';
    }

    final chawalValue = double.tryParse(chawal);
    if (chawalValue == null && chawal.isNotEmpty) {
      errors['chawal'] = 'चावल की मात्रा संख्या में होनी चाहिए';
    } else if (chawalValue != null && chawalValue < 0) {
      errors['chawal'] = 'चावल का स्टॉक ऋणात्मक नहीं हो सकता';
    } else if (chawalValue != null && chawalValue > 10000) {
      errors['chawal'] = 'चावल का स्टॉक 10,000 किलो से अधिक असामान्य है';
    }

    return errors;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gehu_stock': gehuStock,
      'chawal_stock': chawalStock,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory StockManagement.fromMap(Map<String, dynamic> map) {
    return StockManagement(
      id: map['id'],
      gehuStock: map['gehu_stock'],
      chawalStock: map['chawal_stock'],
      lastUpdated: DateTime.parse(map['last_updated']),
      skipValidation: true,
    );
  }
}
