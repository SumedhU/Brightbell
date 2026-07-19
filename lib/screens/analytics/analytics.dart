import 'package:flutter/material.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/screens/analytics/consistency_heatmap.dart';
import 'package:brightbell/screens/analytics/weights.dart';

class Analytics extends StatefulWidget {
  final bool scrollToWeights;
  const Analytics({super.key, this.scrollToWeights = false});

  @override
  State<Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<Analytics> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToWeights) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait a bit to let FutureBuilder build content before scrolling
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        // backgroundColor: Colors.white,
        surfaceTintColor: Colors.red,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consistency',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FutureBuilder<List<DateTime>>(
                    future: WorkoutUtils.getAllWorkoutDates(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.amber),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const SizedBox(
                          height: 100,
                          child: Center(
                            child: Text('Failed to load data'),
                          ),
                        );
                      }

                      final dates = snapshot.data ?? [];
                      return ConsistencyHeatmap(workoutDates: dates);
                    },
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Weight Tracker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const WeightsScreen(),
                const SizedBox(height: 32), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}
