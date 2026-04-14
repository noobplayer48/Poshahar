import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poshahar_register/models/daily_entry.dart';
import 'package:poshahar_register/models/stock_management.dart';
import 'package:poshahar_register/models/holiday.dart';
import 'package:poshahar_register/providers/poshahar_provider.dart';

class PoshaharScreen extends StatefulWidget {
  const PoshaharScreen({super.key});

  @override
  State<PoshaharScreen> createState() => _PoshaharScreenState();
}

class _PoshaharScreenState extends State<PoshaharScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _enrollmentController = TextEditingController();
  final _presentController = TextEditingController();
  final _eatersController = TextEditingController();
  final _remarksController = TextEditingController();

  String _selectedDish = '';
  DateTime _selectedDate = DateTime.now();
  String _activeField = '';

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PoshaharProvider>(context, listen: false);
      _selectedDish = provider.getSuggestedDish(_selectedDate);
      _fillFormForDate(_formatDate(_selectedDate));
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _enrollmentController.dispose();
    _presentController.dispose();
    _eatersController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _getActiveFieldLabel() {
    switch (_activeField) {
      case 'enrollment':
        return '🏫 कुल नामांकित छात्र';
      case 'present':
        return '✋ उपस्थित छात्र';
      case 'eaters':
        return '🍽️ भोजन करने वाले छात्र';
      default:
        return '👨‍🎓 छात्र संख्या भरें';
    }
  }

  String _formatDate(DateTime date) => DailyEntry.formatDate(date);

  String _getWeekdayName(int weekday) {
    const weekdays = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    return weekdays[weekday - 1];
  }

  void _showDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = _formatDate(pickedDate);
        _selectedDish = Provider.of<PoshaharProvider>(context, listen: false)
            .getSuggestedDish(pickedDate);
      });
      _fillFormForDate(_formatDate(pickedDate));
    }
  }

  void _fillFormForDate(String dateString) async {
    final provider = Provider.of<PoshaharProvider>(context, listen: false);

    DailyEntry? existingEntry;
    try {
      existingEntry = provider.entries.firstWhere((entry) => entry.date == dateString);
    } catch (e) {
      existingEntry = null;
    }

    final dateStatus = await provider.getDateStatus(dateString);

    if (existingEntry != null) {
      setState(() {
        _enrollmentController.text = existingEntry!.totalEnrollment.toString();
        _presentController.text = existingEntry.presentStudents.toString();
        _eatersController.text = existingEntry.studentsAte.toString();
        _selectedDish = existingEntry.dishPrepared;
        _remarksController.text = existingEntry.remarks;
      });
    } else {
      setState(() {
        _presentController.clear();
        _eatersController.clear();
        _remarksController.clear();
        if (provider.entries.isNotEmpty) {
          _enrollmentController.text = provider.entries.first.totalEnrollment.toString();
        } else {
          _enrollmentController.clear();
        }
        if (dateStatus['isSchoolClosed'] || _selectedDate.weekday == 7) {
          _presentController.text = '0';
          _eatersController.text = '0';
          _selectedDish = 'अवकाश';
          if (_selectedDate.weekday == 7) {
            _remarksController.text = 'रविवार - साप्ताहिक अवकाश';
          } else {
            _remarksController.text = 'छुट्टी - ${dateStatus['reason']}';
          }
        }
      });
    }
  }

  void _showAddStockDialog() {
    final gehuController = TextEditingController();
    final chawalController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('स्टॉक जोड़ें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gehuController,
              decoration: const InputDecoration(
                labelText: 'गेहूँ (किलो)',
                border: OutlineInputBorder(),
                helperText: '0 या धनात्मक संख्या डालें (दशमलव भी हो सकता है)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chawalController,
              decoration: const InputDecoration(
                labelText: 'चावल (किलो)',
                border: OutlineInputBorder(),
                helperText: '0 या धनात्मक संख्या डालें (दशमलव भी हो सकता है)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () async {
              final gehuText = gehuController.text.isEmpty ? '0' : gehuController.text;
              final chawalText = chawalController.text.isEmpty ? '0' : chawalController.text;
              final gehu = double.tryParse(gehuText) ?? 0;
              final chawal = double.tryParse(chawalText) ?? 0;

              if (gehu < 0 || chawal < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ ऋणात्मक मात्रा नहीं हो सकती'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (gehu > 0 || chawal > 0) {
                final success = await Provider.of<PoshaharProvider>(context, listen: false)
                    .addStock(gehu, chawal);
                if (success) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ स्टॉक जोड़ा गया!')),
                  );
                } else {
                  final errorMsg =
                      Provider.of<PoshaharProvider>(context, listen: false).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ स्टॉक जोड़ने में त्रुटि: ${errorMsg ?? "अज्ञात त्रुटि"}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('कम से कम एक अनाज की मात्रा डालें'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('जोड़ें'),
          ),
        ],
      ),
    );
  }

  void _showEditStockDialog(PoshaharProvider provider) {
    final gehuController = TextEditingController(
        text: provider.currentStock?.gehuStock.toString() ?? '0');
    final chawalController = TextEditingController(
        text: provider.currentStock?.chawalStock.toString() ?? '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700], size: 24),
            const SizedBox(width: 8),
            const Text('⚠️ स्टॉक सेट करें'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Text(
                '⚠️ सावधान: स्टॉक बदलने से पहले दोबारा चेक करें!\nगलत डेटा से रिपोर्ट में समस्या हो सकती है।',
                style: TextStyle(fontSize: 12, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gehuController,
              decoration: const InputDecoration(
                labelText: '🌾 गेहूँ (किलो)',
                border: OutlineInputBorder(),
                helperText: 'कुल मात्रा सेट करें (0-10000, दशमलव भी हो सकता है)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chawalController,
              decoration: const InputDecoration(
                labelText: '🍚 चावल (किलो)',
                border: OutlineInputBorder(),
                helperText: 'कुल मात्रा सेट करें (0-10000, दशमलव भी हो सकता है)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () async {
              final gehuText = gehuController.text;
              final chawalText = chawalController.text;

              final validation = StockManagement.validateStockInput(gehuText, chawalText);
              if (validation.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(validation.values.first),
                    backgroundColor: Colors.red[600],
                  ),
                );
                return;
              }

              final gehu = double.tryParse(gehuText) ?? 0;
              final chawal = double.tryParse(chawalText) ?? 0;

              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (BuildContext confirmContext) => AlertDialog(
                  title: const Text('⚠️ पुष्टि करें'),
                  content: const Text(
                      'क्या आप वाकई स्टॉक बदलना चाहते हैं?\n\nयह एक्शन को अंडू नहीं किया जा सकता।'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('नहीं, रद्द करें'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('हाँ, बदलें'),
                    ),
                  ],
                ),
              ) ?? false;

              if (confirmed) {
                final success = await provider.setStock(gehu, chawal);
                if (success) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ स्टॉक अपडेट हो गया!')),
                  );
                } else {
                  final errorMsg = provider.errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ स्टॉक अपडेट करने में त्रुटि: ${errorMsg ?? "अज्ञात त्रुटि"}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('सेट करें'),
          ),
        ],
      ),
    );
  }

  void _showCommentsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('💬 टिप्पणी'),
        content: TextFormField(
          controller: _remarksController,
          decoration: const InputDecoration(
            labelText: 'टिप्पणी (वैकल्पिक)',
            border: OutlineInputBorder(),
            hintText: 'कोई विशेष बात हो तो यहाँ लिखें...',
          ),
          maxLines: 3,
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('सेव करें'),
          ),
        ],
      ),
    );
  }

  void _showEditCookingRateDialog(PoshaharProvider provider) {
    final rateController =
        TextEditingController(text: provider.cookingRate.toString());

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('🍳 पकाने की दर बदलें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rateController,
              decoration: const InputDecoration(
                labelText: '₹ प्रति छात्र',
                border: OutlineInputBorder(),
                helperText: 'प्रति छात्र पकाने का खर्च (दशमलव भी हो सकता है)',
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            const Text(
              'यह दर सभी भविष्य की गणनाओं में उपयोग होगी',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () {
              final rate = double.tryParse(rateController.text) ?? 6.0;
              provider.setCookingRate(rate);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('पकाने की दर ₹${rate.toStringAsFixed(2)} सेट हो गई!')),
              );
            },
            child: const Text('सेट करें'),
          ),
        ],
      ),
    );
  }

  void _showAuditTrail() async {
    final provider = Provider.of<PoshaharProvider>(context, listen: false);
    final transactions = await provider.getAuditTrail();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('📋 स्टॉक लेन-देन इतिहास'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: transactions.isEmpty
              ? const Center(child: Text('कोई लेन-देन नहीं मिला'))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final date = transaction['date'] ?? '';
                    final grainType = transaction['grain_type'] ?? '';
                    final quantity = (transaction['quantity'] ?? 0.0) as num;
                    final type = transaction['transaction_type'] ?? '';

                    String typeText = '';
                    Color typeColor = Colors.blue;
                    IconData typeIcon = Icons.info;

                    switch (type) {
                      case 'MEAL_PREPARATION':
                        typeText = 'भोजन तैयारी';
                        typeColor = Colors.red;
                        typeIcon = Icons.restaurant;
                        break;
                      case 'ENTRY_DELETION_RESTORE':
                        typeText = 'प्रविष्टि हटाकर स्टॉक वापसी';
                        typeColor = Colors.green;
                        typeIcon = Icons.restore;
                        break;
                      case 'STOCK_ADDITION':
                        typeText = 'स्टॉक जोड़ा गया';
                        typeColor = Colors.blue;
                        typeIcon = Icons.add;
                        break;
                      case 'MANUAL_ADJUSTMENT':
                        typeText = 'मैन्युअल समायोजन';
                        typeColor = Colors.orange;
                        typeIcon = Icons.edit;
                        break;
                      default:
                        typeText = type;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(typeIcon, color: typeColor),
                        title: Text(typeText),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('दिनांक: $date'),
                            if (grainType != 'BOTH') Text('अनाज: $grainType'),
                            if (quantity != 0)
                              Text(
                                'मात्रा: ${quantity > 0 ? '+' : ''}${quantity.toStringAsFixed(1)} किलो',
                              ),
                          ],
                        ),
                        trailing: quantity > 0
                            ? const Icon(Icons.arrow_upward, color: Colors.green)
                            : quantity < 0
                                ? const Icon(Icons.arrow_downward, color: Colors.red)
                                : const Icon(Icons.edit, color: Colors.orange),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateValues() {
    final provider = Provider.of<PoshaharProvider>(context, listen: false);
    final eaters = int.tryParse(_eatersController.text) ?? 0;

    if (_selectedDish.isEmpty || eaters == 0) {
      return {'grain': '', 'usage': 0.0, 'expense': 0.0, 'remaining': 0.0};
    }

    final calculation = provider.calculateGrainUsage(_selectedDish, eaters);
    final grainType = calculation['grain'] as String;
    final usage = calculation['usage'] as double;
    final expense = calculation['expense'] as double;

    double remaining = 0.0;
    if (provider.currentStock != null) {
      if (grainType == 'गेहूँ') {
        remaining = provider.currentStock!.gehuStock - usage;
      } else if (grainType == 'चावल') {
        remaining = provider.currentStock!.chawalStock - usage;
      }
    }

    return {'grain': grainType, 'usage': usage, 'expense': expense, 'remaining': remaining};
  }

  void _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<PoshaharProvider>(context, listen: false);
    final dateStatus = await provider.getDateStatus(_formatDate(_selectedDate));

    if (dateStatus['isSchoolClosed']) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext confirmContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(dateStatus['isWeekend'] ? '🏖️ सप्ताहांत' : '📅 छुट्टी का दिन'),
            ],
          ),
          content: Text(
            'यह दिनांक ${dateStatus['reason']} है।\n'
            'क्या आप वाकई इस दिन की प्रविष्टि सेव करना चाहते हैं?\n\n'
            'आमतौर पर इस दिन स्कूल बंद रहता है।',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmContext, false),
              child: const Text('नहीं, रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(confirmContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('हाँ, सेव करें'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmed) return;
    }

    final selectedDateString = _formatDate(_selectedDate);
    final existingEntry =
        provider.entries.where((entry) => entry.date == selectedDateString).firstOrNull;

    if (existingEntry != null) {
      final overwriteConfirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext confirmContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.red),
              const SizedBox(width: 8),
              const Text('⚠️ डेटा अपडेट करें'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'इस तारीख ($selectedDateString) की प्रविष्टि पहले से मौजूद है।\n',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('मौजूदा डेटा:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('• छात्र संख्या: ${existingEntry.studentsAte}'),
              Text('• भोजन: ${existingEntry.dishPrepared}'),
              Text('• अनाज उपयोग: ${existingEntry.grainUsedKg.toStringAsFixed(1)} किलो'),
              const SizedBox(height: 12),
              const Text(
                'क्या आप इसे नए डेटा से अपडेट करना चाहते हैं?',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmContext, false),
              child: const Text('नहीं, रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(confirmContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
              child: const Text('हाँ, अपडेट करें'),
            ),
          ],
        ),
      ) ?? false;

      if (!overwriteConfirmed) return;
    }

    final providerInstance = Provider.of<PoshaharProvider>(context, listen: false);
    final mainGrain = _selectedDish.isNotEmpty
        ? (providerInstance.menuToGrain[_selectedDish]?['grain'] ?? '')
        : '';

    final formErrors = DailyEntry.validateFormData(
      date: _formatDate(_selectedDate),
      totalEnrollment: _enrollmentController.text,
      presentStudents: _presentController.text,
      studentsAte: _eatersController.text,
      dishPrepared: _selectedDish,
      mainGrain: mainGrain as String,
      grainUsedKg: _calculateValues()['usage'] ?? 0.0,
      cookingExpense: (_calculateValues()['expense'] ?? 0).toDouble(),
    );

    if (formErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formErrors.values.first),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final calculation = _calculateValues();

    try {
      final entry = DailyEntry(
        date: _formatDate(_selectedDate),
        totalEnrollment: int.parse(_enrollmentController.text),
        presentStudents: int.parse(_presentController.text),
        studentsAte: int.parse(_eatersController.text),
        dishPrepared: _selectedDish,
        mainGrain: calculation['grain'],
        grainUsedKg: calculation['usage'],
        cookingExpense: calculation['expense'],
        remarks: _remarksController.text,
      );

      final success = await provider.saveDailyEntry(entry);
      if (success && mounted) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingEntry != null
                ? '✅ सफलतापूर्वक अपडेट हुआ!'
                : '✅ सफलतापूर्वक सेव हुआ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ प्रविष्टि त्रुटि: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _clearForm() {
    _enrollmentController.clear();
    _presentController.clear();
    _eatersController.clear();
    _remarksController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _dateController.text = _formatDate(_selectedDate);
      _selectedDish =
          Provider.of<PoshaharProvider>(context, listen: false).getSuggestedDish(_selectedDate);
      _activeField = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'पोषाहार रजिस्टर',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.history_outlined),
              tooltip: 'स्टॉक लेन-देन इतिहास',
              onPressed: _showAuditTrail,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'स्टॉक जोड़ें',
              onPressed: _showAddStockDialog,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<PoshaharProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('पोषाहार रजिस्टर'),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'डेटा लोड हो रहा है...',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStockCard(provider),
                const SizedBox(height: 16),
                if (provider.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(provider.errorMessage!,
                              style: TextStyle(color: Colors.red[700])),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: provider.clearError,
                        ),
                      ],
                    ),
                  ),
                _buildEntryForm(),
                const SizedBox(height: 16),
                _buildExportButtons(provider),
                const SizedBox(height: 16),
                _buildEntriesList(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockCard(PoshaharProvider provider) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.blue[100], borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.inventory_2, color: Colors.blue[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'वर्तमान स्टॉक',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStockStatusColor(provider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStockStatusText(provider),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showEditStockDialog(provider),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber[200]!, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.amber[100]!,
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text('🌾', style: TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(
                              provider.currentStock?.gehuStock.toStringAsFixed(1) ?? '0.0',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[700]),
                            ),
                            Text('किलो',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[600],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('टैप करके एडिट करें',
                                  style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showEditStockDialog(provider),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.green[100]!,
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text('🍚', style: TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(
                              provider.currentStock?.chawalStock.toStringAsFixed(1) ?? '0.0',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700]),
                            ),
                            Text('किलो',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('टैप करके एडिट करें',
                                  style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockStatusColor(PoshaharProvider provider) {
    final gehu = provider.currentStock?.gehuStock ?? 0;
    final chawal = provider.currentStock?.chawalStock ?? 0;
    if (gehu < 10 || chawal < 10) return Colors.red;
    if (gehu < 25 || chawal < 25) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatusText(PoshaharProvider provider) {
    final gehu = provider.currentStock?.gehuStock ?? 0;
    final chawal = provider.currentStock?.chawalStock ?? 0;
    if (gehu < 10 || chawal < 10) return 'कम स्टॉक';
    if (gehu < 25 || chawal < 25) return 'सावधान';
    return 'पर्याप्त';
  }

  Widget _buildEntryForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('आज की प्रविष्टि',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  FutureBuilder<Map<String, dynamic>>(
                    future: Provider.of<PoshaharProvider>(context, listen: false)
                        .getDateStatus(_formatDate(_selectedDate)),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final status = snapshot.data!;
                        if (status['isSchoolClosed']) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: status['isWeekend']
                                  ? Colors.orange[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status['isWeekend'] ? '🏖️' : '📅',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  SizedBox(
                    width: 120,
                    height: 40,
                    child: TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'दिनांक',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        labelStyle: TextStyle(fontSize: 11),
                      ),
                      style: const TextStyle(fontSize: 11),
                      readOnly: true,
                      onTap: _showDatePicker,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'दिनांक आवश्यक है';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date Row
              SizedBox(
                height: 90,
                child: Consumer<PoshaharProvider>(
                  builder: (context, provider, child) {
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final date = DateTime.now().subtract(Duration(days: index));
                        final dateString = _formatDate(date);
                        final isSelected = dateString == _formatDate(_selectedDate);
                        final hasData =
                            provider.entries.any((entry) => entry.date == dateString);
                        final isSunday = date.weekday == 7;
                        final isToday = index == 0;

                        return FutureBuilder<bool>(
                          future: provider.isHoliday(dateString),
                          builder: (context, snapshot) {
                            final isHoliday = snapshot.data ?? false;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = date;
                                  _dateController.text = dateString;
                                  _selectedDish = provider.getSuggestedDish(date);
                                });
                                _fillFormForDate(dateString);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 70,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue[600]
                                      : isHoliday
                                          ? Colors.purple[50]
                                          : isSunday
                                              ? Colors.orange[50]
                                              : hasData
                                                  ? Colors.green[50]
                                                  : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue[800]!
                                        : isHoliday
                                            ? Colors.purple[300]!
                                            : isSunday
                                                ? Colors.orange[300]!
                                                : hasData
                                                    ? Colors.green[300]!
                                                    : Colors.grey[300]!,
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color: Colors.blue[300]!,
                                              blurRadius: 8,
                                              offset: const Offset(0, 4))
                                        ]
                                      : [
                                          BoxShadow(
                                              color: Colors.grey[200]!,
                                              blurRadius: 2,
                                              offset: const Offset(0, 1))
                                        ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isToday)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.blue[600],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'आज',
                                          style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.blue[600]
                                                  : Colors.white),
                                        ),
                                      )
                                    else
                                      Text(
                                        _getWeekdayName(date.weekday),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? Colors.white
                                              : isHoliday
                                                  ? Colors.purple[700]
                                                  : isSunday
                                                      ? Colors.orange[700]
                                                      : Colors.grey[600],
                                          fontWeight: (isSunday || isHoliday)
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                          fontSize: isSelected ? 20 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (hasData)
                                          Icon(Icons.check_circle,
                                              size: 12,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.green[600]),
                                        if (isHoliday && !hasData)
                                          Icon(Icons.event_busy,
                                              size: 12,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.purple[600]),
                                        if (isSunday && !hasData && !isHoliday)
                                          Icon(Icons.weekend,
                                              size: 12,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.orange[600]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Legend
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(Colors.green[100]!, Colors.green[300]!, 'डेटा सेव है', Icons.check_circle),
                    _buildLegendItem(Colors.purple[50]!, Colors.purple[300]!, 'छुट्टी', Icons.event_busy),
                    _buildLegendItem(Colors.orange[50]!, Colors.orange[300]!, 'रविवार', Icons.weekend),
                    _buildLegendItem(Colors.grey[50]!, Colors.grey[300]!, 'कोई डेटा नहीं', Icons.radio_button_unchecked),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Student Numbers Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getActiveFieldLabel(),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87),
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: Provider.of<PoshaharProvider>(context, listen: false)
                              .isHoliday(_formatDate(_selectedDate)),
                          builder: (context, snapshot) {
                            final isHoliday = snapshot.data ?? false;
                            final isSunday = _selectedDate.weekday == 7;

                            return ElevatedButton.icon(
                              onPressed: isSunday
                                  ? null
                                  : () async {
                                      final provider = Provider.of<PoshaharProvider>(
                                          context,
                                          listen: false);
                                      final dateString = _formatDate(_selectedDate);

                                      if (isHoliday) {
                                        final holidays = await provider
                                            .getHolidaysForDate(dateString);
                                        for (final holiday in holidays) {
                                          if (holiday.id != null) {
                                            await provider.deleteHoliday(holiday.id!);
                                          }
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('छुट्टी हटाई गई!')),
                                        );
                                      } else {
                                        final hasExistingData = provider.entries
                                            .any((entry) => entry.date == dateString);
                                        if (hasExistingData) {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (BuildContext confirmContext) =>
                                                AlertDialog(
                                              title: const Row(
                                                children: [
                                                  Icon(Icons.warning, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('⚠️ चेतावनी'),
                                                ],
                                              ),
                                              content: const Text(
                                                'इस दिनांक की प्रविष्टि पहले से मौजूद है।\n\n'
                                                'छुट्टी मार्क करने पर यह डेटा स्वचालित रूप से डिलीट हो जाएगा।\n\n'
                                                'क्या आप वाकई इस दिन को छुट्टी मार्क करना चाहते हैं?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(confirmContext, false),
                                                  child: const Text('नहीं, रद्द करें'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(confirmContext, true),
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red[600]),
                                                  child: const Text('हाँ, छुट्टी मार्क करें'),
                                                ),
                                              ],
                                            ),
                                          ) ?? false;
                                          if (!confirmed) return;
                                        }

                                        final holiday = Holiday(
                                          date: dateString,
                                          name: 'स्कूल छुट्टी',
                                          type: 'school',
                                        );
                                        final success =
                                            await provider.addHoliday(holiday);
                                        if (success) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text('छुट्टी जोड़ी गई!')),
                                          );
                                        } else if (provider.errorMessage != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(provider.errorMessage!),
                                              backgroundColor: Colors.red[600],
                                            ),
                                          );
                                        }
                                      }
                                      setState(() {});
                                    },
                              icon: Icon(
                                isSunday
                                    ? Icons.weekend
                                    : isHoliday
                                        ? Icons.event_busy
                                        : Icons.event_available,
                                size: 14,
                              ),
                              label: Text(
                                isSunday
                                    ? 'रविवार'
                                    : isHoliday
                                        ? 'छुट्टी हटाएं'
                                        : 'छुट्टी',
                                style: const TextStyle(fontSize: 10),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSunday
                                    ? Colors.orange[300]
                                    : isHoliday
                                        ? Colors.red[600]
                                        : Colors.green[600],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(80, 30),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _enrollmentController,
                            decoration: const InputDecoration(
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('🏫', style: TextStyle(fontSize: 20)),
                              ),
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.number,
                            onTap: () => setState(() => _activeField = 'enrollment'),
                            onChanged: (value) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'आवश्यक है';
                              final number = int.tryParse(value);
                              if (number == null || number <= 0) return 'वैध संख्या दें';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _presentController,
                            decoration: const InputDecoration(
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('✋', style: TextStyle(fontSize: 20)),
                              ),
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.number,
                            onTap: () => setState(() => _activeField = 'present'),
                            onChanged: (value) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'आवश्यक है';
                              final present = int.tryParse(value);
                              final enrolled = int.tryParse(_enrollmentController.text);
                              if (present == null || present < 0) return 'वैध संख्या दें';
                              if (enrolled != null && present > enrolled) {
                                return 'नामांकन से अधिक नहीं';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _eatersController,
                            decoration: const InputDecoration(
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('🍽️', style: TextStyle(fontSize: 20)),
                              ),
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            keyboardType: TextInputType.number,
                            onTap: () => setState(() => _activeField = 'eaters'),
                            onChanged: (value) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'आवश्यक है';
                              final eaters = int.tryParse(value);
                              final present = int.tryParse(_presentController.text);
                              if (eaters == null || eaters < 0) return 'वैध संख्या दें';
                              if (present != null && eaters > present) {
                                return 'उपस्थित से अधिक नहीं';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: TextEditingController(text: _selectedDish),
                      decoration: InputDecoration(
                        labelText:
                            'बनाये गये भोजन का विवरण (${_getWeekdayName(_selectedDate.weekday)})',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        suffixIcon: const Icon(Icons.auto_awesome,
                            color: Colors.blue, size: 20),
                      ),
                      readOnly: true,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'भोजन का चयन आवश्यक है';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Consumer<PoshaharProvider>(
                      builder: (context, provider, child) {
                        return GestureDetector(
                          onTap: () => _showEditCookingRateDialog(provider),
                          child: Container(
                            height: 58,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${provider.cookingRate.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700]),
                                ),
                                const Text('🍳', style: TextStyle(fontSize: 8)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _saveEntry,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('सेव', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showCommentsDialog,
                    icon: Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                    label: Text(
                      _remarksController.text.isEmpty
                          ? 'टिप्पणी जोड़ें (वैकल्पिक)'
                          : 'टिप्पणी: ${_remarksController.text.length > 20 ? '${_remarksController.text.substring(0, 20)}...' : _remarksController.text}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildCalculatedFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatedFields() {
    final calculation = _calculateValues();
    final grainType = calculation['grain'] as String;
    final usage = calculation['usage'] as double;
    final expense = calculation['expense'] as double;
    final remaining = calculation['remaining'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.blue[100]!, blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue[100], borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.calculate, color: Colors.blue[700], size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'स्वचालित गणना',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCalculationCard('मुख्य अनाज',
                    grainType.isEmpty ? '--' : grainType, Colors.purple, Icons.grain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCalculationCard('अनाज उपयोग',
                    '${usage.toStringAsFixed(2)} किलो', Colors.red, Icons.trending_down),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCalculationCard(
                  'शेष अनाज',
                  '${remaining.toStringAsFixed(2)} किलो',
                  remaining < 0 ? Colors.red : Colors.green,
                  remaining < 0 ? Icons.warning : Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCalculationCard('पकाने का खर्च',
                    '₹${expense.toStringAsFixed(2)}', Colors.blue, Icons.currency_rupee),
              ),
            ],
          ),
          if (remaining < 0)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('अपर्याप्त स्टॉक!',
                            style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(
                          'कृपया स्टॉक जोड़ें या कम छात्रों के लिए भोजन तैयार करें।',
                          style: TextStyle(color: Colors.red[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalculationCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildExportButtons(PoshaharProvider provider) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: provider.entries.isEmpty
                ? null
                : () => provider.exportMonthlyExcel(context),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('📊 मासिक सरकारी रिपोर्ट',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: ElevatedButton.icon(
            onPressed: provider.entries.isEmpty ? null : provider.exportToExcel,
            icon: const Icon(Icons.table_chart, size: 16),
            label: const Text('Excel', style: TextStyle(fontSize: 10)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: ElevatedButton.icon(
            onPressed: provider.entries.isEmpty ? null : provider.exportToPdf,
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('PDF', style: TextStyle(fontSize: 10)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntriesList(PoshaharProvider provider) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('पिछली प्रविष्टियाँ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (provider.entries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('अभी तक कोई प्रविष्टि नहीं है',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      Text('पहली प्रविष्टि जोड़ने के लिए ऊपर फॉर्म भरें',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.entries.length,
                itemBuilder: (context, index) {
                  final entry = provider.entries[index];
                  return _buildEntryCard(entry, provider);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(DailyEntry entry, PoshaharProvider provider) {
    final isToday = entry.date == _formatDate(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isToday ? Colors.blue[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(entry.date,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          if (isToday)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('आज',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          FutureBuilder<Map<String, dynamic>>(
                            future: provider.getDateStatus(entry.date),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final status = snapshot.data!;
                                if (status['isSchoolClosed']) {
                                  return Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: status['isWeekend']
                                          ? Colors.orange[100]
                                          : Colors.red[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: status['isWeekend']
                                            ? Colors.orange
                                            : Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      status['isWeekend'] ? '🏖️' : '📅',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(entry.dishPrepared,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editEntry(entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(entry, provider),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      '${entry.studentsAte}', 'भोजन करने वाले', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('${entry.grainUsedKg.toStringAsFixed(1)} किलो',
                      '${entry.mainGrain} उपयोग', Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('₹${entry.cookingExpense.toStringAsFixed(2)}',
                      'पकाने का खर्च', Colors.green),
                ),
              ],
            ),
            if (entry.remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.remarks,
                          style: TextStyle(
                              color: Colors.grey[700], fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      Color bgColor, Color borderColor, String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 10, color: borderColor),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _editEntry(DailyEntry entry) {
    setState(() {
      final parsedDate = DailyEntry.parseDate(entry.date);
      _selectedDate = parsedDate ?? DateTime.now();
      _dateController.text = entry.date;
      _enrollmentController.text = entry.totalEnrollment.toString();
      _presentController.text = entry.presentStudents.toString();
      _eatersController.text = entry.studentsAte.toString();
      _selectedDish = entry.dishPrepared;
      _remarksController.text = entry.remarks;
    });

    Scrollable.ensureVisible(
      _formKey.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _confirmDelete(DailyEntry entry, PoshaharProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('प्रविष्टि हटाएं'),
        content: Text('क्या आप ${entry.date} की प्रविष्टि हटाना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () {
              if (entry.id != null) {
                provider.deleteEntry(entry.id!);
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
