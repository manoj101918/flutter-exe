import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const WaterTrackerApp());
}

class WaterTrackerApp extends StatelessWidget {
  const WaterTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue[50],
        useMaterial3: true,
      ),
      home: const WaterTrackerHome(),
    );
  }
}

class WaterTrackerHome extends StatefulWidget {
  const WaterTrackerHome({Key? key}) : super(key: key);

  @override
  State<WaterTrackerHome> createState() => _WaterTrackerHomeState();
}

class _WaterTrackerHomeState extends State<WaterTrackerHome> {
  int dailyGoal = 2000; // ml
  int totalConsumed = 0; // ml
  List<WaterEntry> entries = [];
  Timer? reminderTimer;
  int reminderInterval = 30; // minutes
  bool remindersEnabled = false;
  final TextEditingController customAmountController = TextEditingController();
  final TextEditingController goalController = TextEditingController();
  final TextEditingController intervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    reminderTimer?.cancel();
    customAmountController.dispose();
    goalController.dispose();
    intervalController.dispose();
    super.dispose();
  }

  // Simulate localStorage for DartPad
  final Map<String, String> _localStorage = {};

  void _saveData() {
    final data = {
      'dailyGoal': dailyGoal,
      'totalConsumed': totalConsumed,
      'entries': entries.map((e) => e.toJson()).toList(),
      'reminderInterval': reminderInterval,
      'remindersEnabled': remindersEnabled,
      'lastDate': DateTime.now().toIso8601String().split('T')[0],
    };
    _localStorage['waterTrackerData'] = jsonEncode(data);
  }

  void _loadData() {
    final storedData = _localStorage['waterTrackerData'];
    if (storedData != null) {
      final data = jsonDecode(storedData);
      final lastDate = data['lastDate'] as String;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Reset if it's a new day
      if (lastDate != today) {
        _resetDay();
        return;
      }

      setState(() {
        dailyGoal = data['dailyGoal'] ?? 2000;
        totalConsumed = data['totalConsumed'] ?? 0;
        reminderInterval = data['reminderInterval'] ?? 30;
        remindersEnabled = data['remindersEnabled'] ?? false;
        entries = (data['entries'] as List)
            .map((e) => WaterEntry.fromJson(e))
            .toList();
      });

      // Restart reminders if they were enabled
      if (remindersEnabled) {
        _startReminder();
      }
    }
  }

  void _addWater(int amount) {
    setState(() {
      totalConsumed += amount;
      entries.add(WaterEntry(amount: amount, timestamp: DateTime.now()));
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${amount}ml of water! 💧'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue[700],
      ),
    );
  }

  void _addCustomAmount() {
    final amount = int.tryParse(customAmountController.text);
    if (amount != null && amount > 0) {
      _addWater(amount);
      customAmountController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setDailyGoal() {
    final goal = int.tryParse(goalController.text);
    if (goal != null && goal > 0) {
      setState(() {
        dailyGoal = goal;
      });
      _saveData();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Daily goal set to ${goal}ml'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _updateReminderInterval(int newInterval) {
    setState(() {
      reminderInterval = newInterval;
    });
    _saveData();
    
    // Restart timer with new interval if reminders are enabled
    if (remindersEnabled) {
      _startReminder();
    }
  }

  void _resetDay() {
    setState(() {
      totalConsumed = 0;
      entries.clear();
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Day reset! Start fresh 🌊'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _startReminder() {
    reminderTimer?.cancel();
    reminderTimer = Timer.periodic(
      Duration(minutes: reminderInterval),
      (timer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('💧 Time to drink water! Stay hydrated! 💧'),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.blue[800],
              action: SnackBarAction(
                label: 'GOT IT',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      },
    );
  }

  void _stopReminder() {
    reminderTimer?.cancel();
  }

  void _toggleReminder(bool value) {
    setState(() {
      remindersEnabled = value;
    });
    _saveData();
    
    if (value) {
      _startReminder();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminders enabled (every $reminderInterval min)'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _stopReminder();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminders disabled'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  double get progress => dailyGoal > 0 ? (totalConsumed / dailyGoal).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💧 Water Tracker'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Daily Progress',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.blue[100],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.green : Colors.blue,
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$totalConsumed ml',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            Text(
                              'of $dailyGoal ml',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (progress >= 1.0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🎉 Goal achieved! Great job!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Add Buttons
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAddButton(
                    amount: 200,
                    onPressed: () => _addWater(200),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAddButton(
                    amount: 250,
                    onPressed: () => _addWater(250),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAddButton(
                    amount: 300,
                    onPressed: () => _addWater(300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Custom Amount
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Amount',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter ml',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addCustomAmount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reminder Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reminders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Switch(
                          value: remindersEnabled,
                          onChanged: _toggleReminder,
                          // FIX: 'activeColor' is deprecated. Use 'activeThumbColor' instead.
                          activeThumbColor: Colors.blue[700],
                        ),
                      ],
                    ),
                    if (remindersEnabled) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Remind me every:',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _IntervalChip(
                            label: '15 min',
                            minutes: 15,
                            isSelected: reminderInterval == 15,
                            onSelected: () => _updateReminderInterval(15),
                          ),
                          _IntervalChip(
                            label: '30 min',
                            minutes: 30,
                            isSelected: reminderInterval == 30,
                            onSelected: () => _updateReminderInterval(30),
                          ),
                          _IntervalChip(
                            label: '45 min',
                            minutes: 45,
                            isSelected: reminderInterval == 45,
                            onSelected: () => _updateReminderInterval(45),
                          ),
                          _IntervalChip(
                            label: '60 min',
                            minutes: 60,
                            isSelected: reminderInterval == 60,
                            onSelected: () => _updateReminderInterval(60),
                          ),
                          _IntervalChip(
                            label: '90 min',
                            minutes: 90,
                            isSelected: reminderInterval == 90,
                            onSelected: () => _updateReminderInterval(90),
                          ),
                          _IntervalChip(
                            label: '120 min',
                            minutes: 120,
                            isSelected: reminderInterval == 120,
                            onSelected: () => _updateReminderInterval(120),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: intervalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: 'Custom (minutes)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final interval = int.tryParse(intervalController.text);
                              if (interval != null && interval > 0) {
                                _updateReminderInterval(interval);
                                intervalController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Reminder set to $interval minutes'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid number'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Today's Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Log',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: _showResetConfirmation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Day'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            entries.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No entries yet today',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[entries.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(
                              Icons.water_drop,
                              color: Colors.blue[700],
                            ),
                          ),
                          title: Text(
                            '${entry.amount} ml',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            entry.formattedTime,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Goal'),
        content: TextField(
          controller: goalController..text = dailyGoal.toString(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Goal (ml)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _setDailyGoal,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Day'),
        content: const Text(
          'Are you sure you want to reset today\'s data? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _resetDay();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int amount;
  final VoidCallback onPressed;

  const _QuickAddButton({
    required this.amount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Column(
        children: [
          const Icon(Icons.water_drop, size: 32),
          const SizedBox(height: 8),
          Text(
            '$amount ml',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final int minutes;
  final bool isSelected;
  final VoidCallback onSelected;

  const _IntervalChip({
    required this.label,
    required this.minutes,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.blue[700],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.blue[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class WaterEntry {
  final int amount;
  final DateTime timestamp;

  WaterEntry({
    required this.amount,
    required this.timestamp,
  });

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        amount: json['amount'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}