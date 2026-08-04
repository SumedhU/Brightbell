import 'package:brightbell/screens/settings.dart';
import 'package:brightbell/screens/workout_list.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/components/add_sets.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'dart:async';
import 'dart:convert';
import 'package:brightbell/models/exercise.dart' as models;
import 'package:brightbell/models/workout.dart' as workout_model;
import 'package:brightbell/components/exercise_card.dart';

import 'package:brightbell/screens/analytics/analytics.dart';

class Workout extends StatefulWidget {
  const Workout({super.key});

  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  final TextEditingController _addExerciseController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 10000);
  final FocusNode _focusNode = FocusNode();
  late DateTime _currentDate;
  int _streak = 0;
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _currentDocId;
  Map<String, Map<String, String>> _pastExercises = {};
  Map<String, Timer> _historyTimers = {};
  final ScrollController _scrollController = ScrollController();
  int _currentPageIndex = 10000;
  List<models.Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _loadStreak();

    _loadWorkoutForDate();
    _loadPastExercises();
  }

  Future<void> _loadPastExercises() async {
    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    try {
      final history = await WorkoutUtils.getLatestExercisesHistory(
        beforeDateStr: dateStr,
      );
      if (mounted) {
        setState(() {
          _pastExercises = history;
        });
      }
    } catch (e) {
      print('Error loading past exercises: $e');
    }
  }

  Future<void> _loadWorkoutForDate() async {
    setState(() {
      _isLoading = true;
      _currentDocId = null;
      _exercises = [];
    });

    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';

    DateTime now = DateTime.now();
    String todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Try to load from local SharedPreferences cache first if it's today's date
    if (dateStr == todayStr) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedWorkout = prefs.getString('workout_$dateStr');
        if (cachedWorkout != null) {
          final decoded = jsonDecode(cachedWorkout);
          final workout = workout_model.Workout.fromMap(decoded);
          if (mounted) {
            setState(() {
              _currentDocId = workout.docId;
              _exercises = workout.exercises;
            });
          }
        }
      } catch (e) {
        print('Error loading from local cache: $e');
      }
    }

    // 2. Fetch from Firestore for the latest updates
    try {
      final workout = await WorkoutUtils.loadWorkoutForDate(dateStr);

      if (mounted) {
        setState(() {
          if (workout != null) {
            _currentDocId = workout.docId;
            _exercises = workout.exercises;

            // Update local cache only if it's today's date
            if (dateStr == todayStr) {
              SharedPreferences.getInstance().then((prefs) {
                final toSave = workout.toMap();
                toSave['docId'] = workout.docId;
                prefs.setString('workout_$dateStr', jsonEncode(toSave));
              });
            }
          }
        });
      }
    } catch (e) {
      print('Error loading workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error loading data. If you are offline, some data may not appear until reconnected.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _setsToText(List<models.Set> sets) {
    List<String> setStrings = [];
    for (var s in sets) {
      String type = '';
      if (s.isWarmUp) type = '(W)';
      if (s.isDropSet) type = '(D)';
      if (s.isFailure) type = '(F)';
      String weightStr = s.weight == s.weight.toInt()
          ? s.weight.toInt().toString()
          : s.weight.toString();
      setStrings.add('[${s.numberOfReps}, $weightStr]$type');
    }
    return setStrings.join(' ');
  }

  String _exercisesToText() {
    StringBuffer sb = StringBuffer();
    for (var ex in _exercises) {
      sb.writeln(ex.name);
      String setsStr = _setsToText(ex.sets);
      if (setsStr.isNotEmpty) {
        sb.writeln(setsStr);
      }
    }
    return sb.toString().trimRight();
  }

  Future<void> _saveWorkout() async {
    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    final rawText = _exercisesToText();

    final workout = workout_model.Workout(
      docId: _currentDocId,
      date: dateStr,
      userId: '', // WorkoutUtils will set this
      rawText: rawText,
      exercises: List.from(_exercises),
    );

    // Save to local cache immediately ONLY if it's today's date
    DateTime now = DateTime.now();
    String todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (dateStr == todayStr) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final toSave = workout.toMap();
        toSave['docId'] = _currentDocId;
        await prefs.setString('workout_$dateStr', jsonEncode(toSave));
      } catch (e) {
        print('Error saving to local cache: $e');
      }
    }

    // Submit to Firebase
    try {
      _currentDocId = await WorkoutUtils.saveWorkout(workout);
    } catch (e) {
      print('Error saving workout: $e');
    }
  }

  List<models.Exercise> _parseTextToExercises(String text) {
    List<models.Exercise> exercises = [];
    final lines = text.split('\n');
    String currentExerciseName = '';
    List<models.Set> currentSets = [];
    int setIdCounter = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.contains(']')) {
        final matches = RegExp(
          r'\[([0-9.]+),\s*([0-9.]+)\](\([WDF]\))?',
        ).allMatches(line);
        for (final match in matches) {
          int reps = double.parse(match.group(1)!).toInt();
          double weight = double.parse(match.group(2)!);
          String type = match.group(3) ?? '';
          bool isWarmUp = type == '(W)';
          bool isDropSet = type == '(D)';
          bool isFail = type == '(F)';
          currentSets.add(
            models.Set(
              id: setIdCounter++,
              numberOfReps: reps,
              weight: weight,
              isWarmUp: isWarmUp,
              isDropSet: isDropSet,
              isFailure: isFail
            ),
          );
        }
      } else {
        if (currentExerciseName.isNotEmpty || currentSets.isNotEmpty) {
          exercises.add(
            models.Exercise(
              name: currentExerciseName.isNotEmpty
                  ? currentExerciseName
                  : 'Unknown',
              numberOfSets: currentSets.length,
              sets: List.from(currentSets),
            ),
          );
          currentSets.clear();
        }
        currentExerciseName = line;
      }
    }
    if (currentExerciseName.isNotEmpty || currentSets.isNotEmpty) {
      exercises.add(
        models.Exercise(
          name: currentExerciseName.isNotEmpty
              ? currentExerciseName
              : 'Unknown',
          numberOfSets: currentSets.length,
          sets: List.from(currentSets),
        ),
      );
    }
    return exercises;
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    int savedStreak = prefs.getInt('streak') ?? 0;

    final savedDays = prefs.getStringList('goal_days');
    List<int> goalDays = savedDays != null
        ? savedDays.map((e) => int.parse(e)).toList()
        : [1, 2, 3, 4, 5, 6, 7];

    String? lastUpdatedStr = prefs.getString('last_updated');
    if (lastUpdatedStr != null) {
      DateTime lastUpdated = DateTime.parse(lastUpdatedStr);
      DateTime now = DateTime.now();
      DateTime lastDate = DateTime(
        lastUpdated.year,
        lastUpdated.month,
        lastUpdated.day,
      );
      DateTime today = DateTime(now.year, now.month, now.day);

      DateTime lastDateUtc = DateTime.utc(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      );
      DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);

      int diff = todayUtc.difference(lastDateUtc).inDays;
      if (diff > 1) {
        bool streakBroken = false;
        for (int i = 1; i < diff; i++) {
          DateTime missedDate = lastDateUtc.add(Duration(days: i));
          if (goalDays.contains(missedDate.weekday)) {
            streakBroken = true;
            break;
          }
        }
        if (streakBroken) {
          savedStreak = 0;
          await prefs.setInt('streak', 0);
        }
      }
    }
    setState(() {
      _streak = savedStreak;
    });
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    String? lastUpdatedStr = prefs.getString('last_updated');
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    final savedDays = prefs.getStringList('goal_days');
    List<int> goalDays = savedDays != null
        ? savedDays.map((e) => int.parse(e)).toList()
        : [1, 2, 3, 4, 5, 6, 7];

    int newStreak = _streak;

    if (lastUpdatedStr != null) {
      DateTime lastUpdated = DateTime.parse(lastUpdatedStr);
      DateTime lastDate = DateTime(
        lastUpdated.year,
        lastUpdated.month,
        lastUpdated.day,
      );

      DateTime lastDateUtc = DateTime.utc(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      );
      DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);

      int diff = todayUtc.difference(lastDateUtc).inDays;
      if (diff == 0) {
        // Already updated today, do nothing
        return;
      } else if (diff == 1) {
        // Updated yesterday, increment
        newStreak++;
      } else {
        bool streakBroken = false;
        for (int i = 1; i < diff; i++) {
          DateTime missedDate = lastDateUtc.add(Duration(days: i));
          if (goalDays.contains(missedDate.weekday)) {
            streakBroken = true;
            break;
          }
        }
        if (streakBroken) {
          newStreak = 1; // broken, start over
        } else {
          newStreak++; // continued!
        }
      }
    } else {
      // First time
      newStreak = 1;
    }

    await prefs.setInt('streak', newStreak);
    await prefs.setString('last_updated', now.toIso8601String());
    setState(() {
      _streak = newStreak;
    });
  }

  Future<void> _showAddSetsBottomSheet(
    String exerciseName, {
    int? exerciseIndex,
    String? initialSetsText,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          AddSets(exerciseName: exerciseName, initialSetsText: initialSetsText),
    );

    if (result != null) {
      final parsedExercises = _parseTextToExercises(result);
      if (parsedExercises.isNotEmpty) {
        final newExercise = parsedExercises.first;
        final newName = newExercise.name;
        final newSets = newExercise.sets;
        setState(() {
          if (exerciseIndex != null &&
              exerciseIndex >= 0 &&
              exerciseIndex < _exercises.length) {
            _exercises[exerciseIndex] = models.Exercise(
              name: newName,
              numberOfSets: newSets.length,
              sets: newSets,
            );
          } else {
            _exercises.add(
              models.Exercise(
                name: newName,
                numberOfSets: newSets.length,
                sets: newSets,
              ),
            );
          }
        });
        await _saveWorkout();
      }
    }
  }

  @override
  void dispose() {
    for (var timer in _historyTimers.values) {
      timer.cancel();
    }
    _historyTimers.clear();
    _debounceTimer?.cancel();
    _addExerciseController.dispose();
    _pageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Swiping right goes to lower index (e.g. 9999).
    // The user wants "Swiping right to go back on the date".
    // So lower index = older date (negative offset).
    final offset = index - 10000;
    setState(() {
      _currentPageIndex = index;
      _currentDate = DateTime.now().add(Duration(days: offset));
    });
    _loadWorkoutForDate();
    _loadPastExercises();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      DateTime today = DateTime.now();
      DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);
      DateTime pickedUtc = DateTime.utc(picked.year, picked.month, picked.day);
      int offset = pickedUtc.difference(todayUtc).inDays;

      int targetPage = 10000 + offset;

      if (_pageController.page?.round() != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildDynamicIsland({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  String _getFormattedDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showHistoryBottomSheet(
    BuildContext context,
    String exerciseName,
    Map<String, String> historyData,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Previous Entry',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (historyData['date'] != null)
                    Text(
                      historyData['date']!,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  historyData['text'] ?? 'No data',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateStreak();
                        _showAddSetsBottomSheet(
                          exerciseName,
                          initialSetsText: historyData['text'],
                        );
                        _addExerciseController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Copy sets'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.list, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutListScreen()),
            );
          },
        ),
        elevation: 0,
        toolbarHeight: 100,
        titleSpacing: 16,
        title: GestureDetector(
          onTap: _selectDate,
          child: SizedBox(
            width: 110,
            child: _buildDynamicIsland(
              child: Row(
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    _getFormattedDate(_currentDate),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          _buildDynamicIsland(
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '$_streak',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Settings()),
              );
            },
            child: _buildDynamicIsland(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // floatingActionButtonLocation: ExpandableFab.location,
      // floatingActionButton: ExpandableFab(
      //   openButtonBuilder: RotateFloatingActionButtonBuilder(
      //     child: const Icon(Icons.edit),
      //     fabSize: ExpandableFabSize.regular,
      //     foregroundColor: Colors.black,
      //     backgroundColor: Colors.white,
      //     shape: const CircleBorder(),
      //   ),
      //   closeButtonBuilder: DefaultFloatingActionButtonBuilder(
      //     child: const Icon(Icons.close),
      //     fabSize: ExpandableFabSize.small,
      //     foregroundColor: Colors.redAccent,
      //     backgroundColor: Colors.white,
      //     shape: const CircleBorder(),
      //   ),
      //   children: [
      //     FloatingActionButton.small(
      //       heroTag: null,
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (context) => const Analytics(scrollToWeights: true)),
      //         );
      //       },
      //       backgroundColor: Colors.white,
      //       foregroundColor: Colors.black,
      //       child: const Icon(Icons.monitor_weight_outlined),
      //     ),
      //     FloatingActionButton.small(
      //       heroTag: null,
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (context) => const Analytics(scrollToWeights: false)),
      //         );
      //       },
      //       backgroundColor: Colors.white,
      //       foregroundColor: Colors.black,
      //       child: const Icon(Icons.analytics_outlined),
      //     ),
      //   ],
      // ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final bool isActivePage = index == _currentPageIndex;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _exercises.length,
                      itemBuilder: (context, exIndex) {
                        final ex = _exercises[exIndex];
                        return ExerciseCard(
                          exercise: ex,
                          setsText: _setsToText(ex.sets),
                          onEdit: () {
                            _showAddSetsBottomSheet(
                              ex.name,
                              exerciseIndex: exIndex,
                              initialSetsText: _setsToText(ex.sets),
                            );
                          },
                          onDelete: () {
                            setState(() {
                              _exercises.removeAt(exIndex);
                            });
                            _saveWorkout();
                          },
                          onEditName: (newName) {
                            setState(() {
                              _exercises[exIndex].name = newName;
                            });
                            _saveWorkout();
                          },
                        );
                      },
                    ),
                  ),
                  if (isActivePage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _addExerciseController,
                        builder: (context, value, child) {
                          final currentText = value.text.trim().toLowerCase();
                          final hasHistory = _pastExercises.containsKey(
                            currentText,
                          );

                          List<String> suggestions = [];
                          if (currentText.isNotEmpty) {
                            suggestions = _pastExercises.keys
                                .where(
                                  (key) =>
                                      key.contains(currentText) &&
                                      key != currentText,
                                )
                                .take(5)
                                .toList();
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (suggestions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: suggestions.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final suggestion = suggestions[index];
                                          // Capitalize each word for display
                                          final displayText = suggestion
                                              .split(' ')
                                              .map((word) {
                                                if (word.isEmpty) return '';
                                                return word[0].toUpperCase() +
                                                    word.substring(1);
                                              })
                                              .join(' ');

                                          return ListTile(
                                            title: Text(displayText),
                                            onTap: () {
                                              _addExerciseController.text =
                                                  displayText;
                                              _addExerciseController.selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset:
                                                          displayText.length,
                                                    ),
                                                  );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              TextField(
                                controller: _addExerciseController,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: 'Add exercise...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(color: Colors.black),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  suffixIcon: hasHistory
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.history,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () {
                                            _showHistoryBottomSheet(
                                              context,
                                              _addExerciseController.text
                                                  .trim(),
                                              _pastExercises[currentText]!,
                                            );
                                          },
                                        )
                                      : null,
                                ),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    _updateStreak();
                                    _showAddSetsBottomSheet(value.trim());
                                    _addExerciseController.clear();
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
