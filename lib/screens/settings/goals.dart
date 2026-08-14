import 'package:flutter/material.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/notification_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // 1=Monday, ..., 7=Sunday
  final List<int> _selectedDays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goalDays = await UserUtils.getGoalDays();
    setState(() {
      _selectedDays.addAll(goalDays);
      _isLoading = false;
    });
  }

  Future<void> _saveGoals() async {
    await UserUtils.saveGoalDays(_selectedDays);
    await NotificationService().scheduleNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goals saved successfully')),
      );
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final daysMap = {
      1: 'M',
      2: 'T',
      3: 'W',
      4: 'T',
      5: 'F',
      6: 'S',
      7: 'S',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the days you plan to workout:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your streak will only reset if you miss one of these selected days.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: daysMap.entries.map((entry) {
                final dayNum = entry.key;
                final dayLabel = entry.value;
                final isSelected = _selectedDays.contains(dayNum);

                return GestureDetector(
                  onTap: () => _toggleDay(dayNum),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveGoals,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Save Goals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
