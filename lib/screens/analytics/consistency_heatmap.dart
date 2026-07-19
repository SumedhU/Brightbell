import 'package:flutter/material.dart';
import 'package:fl_heatmap/fl_heatmap.dart';

class ConsistencyHeatmap extends StatefulWidget {
  final List<DateTime> workoutDates;

  const ConsistencyHeatmap({super.key, required this.workoutDates});

  @override
  State<ConsistencyHeatmap> createState() => _ConsistencyHeatmapState();
}

class _ConsistencyHeatmapState extends State<ConsistencyHeatmap> {
  late DateTime _endDate;
  
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
  }
  
  void _goBack() {
    setState(() {
      _endDate = _endDate.subtract(const Duration(days: 30));
    });
  }
  
  void _goForward() {
    setState(() {
      final next = _endDate.add(const Duration(days: 30));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (next.isAfter(today)) {
        _endDate = today;
      } else {
        _endDate = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final startDate = _endDate.subtract(const Duration(days: 29)); // 30 days total
    
    final Set<String> loggedDates = widget.workoutDates.map((d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }).toSet();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canGoForward = _endDate.isBefore(today);
    
    final monthFormat = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateRangeText = '${monthFormat[startDate.month - 1]} ${startDate.day} - ${monthFormat[_endDate.month - 1]} ${_endDate.day}';

    int workoutsInPeriod = 0;
    
    // Create a 10x3 grid for exactly 30 days
    final columns = List.generate(10, (i) => 'C$i');
    final rows = List.generate(3, (i) => 'R$i');
    List<HeatmapItem> items = [];

    for (int i = 0; i < 30; i++) {
      final int col = i % 10;
      final int row = i ~/ 10;
      
      final cellDate = startDate.add(Duration(days: i));
      final dateStr = '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';
      final bool hasWorkout = loggedDates.contains(dateStr);
      
      if (hasWorkout) workoutsInPeriod++;
      
      items.add(HeatmapItem(
        value: hasWorkout ? 1.0 : 0.0,
        xAxisLabel: columns[col],
        yAxisLabel: rows[row],
      ));
    }

    final heatmapData = HeatmapData(
      rows: rows,
      columns: columns,
      radius: 4.0,
      colorPalette: [
        Colors.grey.shade200,
        Colors.green.shade200,
        Colors.green.shade300,
        Colors.green.shade400,
        Colors.green,
      ],
      items: items,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: _goBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Column(
                children: [
                  Text(
                    dateRangeText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$workoutsInPeriod workouts',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                onPressed: canGoForward ? _goForward : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Heatmap(
            heatmapData: heatmapData,
            showXAxisLabels: false,
            showYAxisLabels: false,
          ),
        ],
      ),
    );
  }
}
