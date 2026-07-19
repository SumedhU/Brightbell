import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:brightbell/utils/weight_utils.dart';
import 'package:brightbell/models/weight.dart';

class WeightsScreen extends StatefulWidget {
  const WeightsScreen({super.key});

  @override
  State<WeightsScreen> createState() => _WeightsScreenState();
}

class _WeightsScreenState extends State<WeightsScreen> {
  final TextEditingController _weightController = TextEditingController();
  bool _isLbs = true;
  bool _isLoading = true;
  List<Weight> _weightsData = [];

  @override
  void initState() {
    super.initState();
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    setState(() => _isLoading = true);
    final data = await WeightUtils.getWeights();
    setState(() {
      _weightsData = data;
      _isLoading = false;
    });
  }

  Future<void> _saveWeight() async {
    final text = _weightController.text.trim();
    if (text.isEmpty) return;

    final double? parsedWeight = double.tryParse(text);
    if (parsedWeight == null) return;

    double weightLbs = _isLbs ? parsedWeight : (parsedWeight * 2.20462);

    setState(() => _isLoading = true);
    final date = DateTime.now();
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final weight = Weight(date: dateStr, weightLbs: weightLbs);
    await WeightUtils.saveWeight(weight);
    _weightController.clear();
    await _loadWeights(); // Reload data
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputSection(),
              const SizedBox(height: 32),
              const Text(
                'Weight History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 300, child: _buildGraphSection()),
            ],
          );
  }

  Widget _buildInputSection() {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ToggleButtons(
              isSelected: [_isLbs, !_isLbs],
              onPressed: (index) {
                setState(() {
                  _isLbs = index == 0;
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('lbs'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('kg'),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saveWeight,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphSection() {
    if (_weightsData.isEmpty) {
      return const Center(child: Text('No weight history yet.'));
    }

    List<FlSpot> spots = [];
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < _weightsData.length; i++) {
      final data = _weightsData[i];
      final dateStr = data.date;
      final date = DateTime.parse(dateStr);
      final x = date.millisecondsSinceEpoch.toDouble();
      final y = data.weightLbs;

      final yDisplay = _isLbs ? y : (y / 2.20462);

      spots.add(FlSpot(x, yDisplay));

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (yDisplay < minY) minY = yDisplay;
      if (yDisplay > maxY) maxY = yDisplay;
    }

    // Add some padding to Y axis
    minY = (minY - 5).floorToDouble();
    maxY = (maxY + 5).ceilToDouble();

    // If only one data point, make fake x range
    if (minX == maxX) {
      minX -= 86400000; // 1 day
      maxX += 86400000;
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).primaryColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      value.toInt(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${date.month}/${date.day}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
        ),
      ),
    );
  }
}
