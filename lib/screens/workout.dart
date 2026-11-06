import 'package:brightbell/theme/app_theme.dart';
import 'package:brightbell/screens/analytics/ai/chat.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/components/add_sets.dart';
import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:brightbell/models/exercise.dart' as models;
import 'package:brightbell/models/workout.dart' as workout_model;
import 'package:brightbell/components/exercise_card.dart';
import 'package:brightbell/utils/notification_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class Workout extends StatefulWidget {
  /// Shown at the end of the app bar.
  final Widget appBarAction;

  /// Called after the workout for a date is saved or removed.
  final VoidCallback onWorkoutSaved;

  const Workout({
    super.key,
    required this.appBarAction,
    required this.onWorkoutSaved,
  });

  @override
  State<Workout> createState() => WorkoutState();
}

class WorkoutState extends State<Workout> {
  // Page index of today. Lower indexes are earlier dates; there are no pages
  // after today, so workouts can't be logged in the future.
  static const int _todayPage = 10000;

  final TextEditingController _addExerciseController = TextEditingController();
  final PageController _pageController = PageController(
    initialPage: _todayPage,
  );
  late DateTime _currentDate;
  int _currentPageIndex = _todayPage;

  String? _currentDocId;
  List<models.Exercise> _exercises = [];
  bool _isLoadingWorkout = false;
  Map<String, ExerciseHistory> _pastExercises = {};

  // Saves run one at a time so that, e.g., a delete followed by an undo
  // can't reach Firestore in the wrong order.
  Future<void> _pendingSave = Future.value();

  String get _currentDateStr => dateKey(_currentDate);

  @override
  void initState() {
    super.initState();
    _currentDate = _dateForPage(_todayPage);
    _loadWorkoutForDate();
    _loadPastExercises();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPrompt();
      NotificationService().scheduleNotifications();
    });
  }

  @override
  void dispose() {
    _addExerciseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int index) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + (index - _todayPage));
  }

  Future<void> _checkNotificationPrompt() async {
    final notifications = NotificationService();
    if (await notifications.hasPrompted() || !mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications?'),
        content: const Text(
          'Would you like to receive reminders to log your workouts?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              notifications.setNotificationsEnabled(true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.cream,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    await notifications.markPrompted();
  }

  Future<void> _loadPastExercises() async {
    final dateStr = _currentDateStr;
    try {
      final history = await WorkoutUtils.getLatestExercisesHistory(
        beforeDateStr: dateStr,
      );
      if (mounted && dateStr == _currentDateStr) {
        setState(() {
          _pastExercises = history;
        });
      }
    } catch (e) {
      debugPrint('Error loading past exercises: $e');
    }
  }

  Future<void> _loadWorkoutForDate() async {
    final dateStr = _currentDateStr;
    setState(() {
      _currentDocId = null;
      _exercises = [];
      _isLoadingWorkout = true;
    });

    try {
      final workout = await WorkoutUtils.loadWorkoutForDate(dateStr);
      // Ignore results for a date the user has already swiped away from.
      if (!mounted || dateStr != _currentDateStr) return;
      setState(() {
        _currentDocId = workout?.docId;
        _exercises = workout?.exercises ?? [];
      });
    } catch (e) {
      debugPrint('Error loading workout: $e');
      if (mounted && dateStr == _currentDateStr) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error loading data. If you are offline, some data may not appear until reconnected.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && dateStr == _currentDateStr) {
        setState(() {
          _isLoadingWorkout = false;
        });
      }
    }
  }

  String _setsToText(List<models.Set> sets) {
    return sets.map((s) => s.toText()).join(' ');
  }

  String _exercisesToText(List<models.Exercise> exercises) {
    StringBuffer sb = StringBuffer();
    for (var ex in exercises) {
      sb.writeln(ex.name);
      String setsStr = _setsToText(ex.sets);
      if (setsStr.isNotEmpty) {
        sb.writeln(setsStr);
      }
    }
    return sb.toString().trimRight();
  }

  /// Saves the current date's exercises. A day with no exercises left is
  /// deleted so it no longer shows in the history or counts for the streak.
  Future<void> _saveWorkout() {
    final dateStr = _currentDateStr;
    final exercises = List<models.Exercise>.of(_exercises);

    return _pendingSave = _pendingSave.then((_) async {
      try {
        if (exercises.isEmpty) {
          await WorkoutUtils.deleteWorkout(dateStr);
          if (dateStr == _currentDateStr) _currentDocId = null;
        } else {
          final docId = await WorkoutUtils.saveWorkout(
            workout_model.Workout(
              docId: dateStr == _currentDateStr ? _currentDocId : null,
              date: dateStr,
              userId: '', // WorkoutUtils sets this
              rawText: _exercisesToText(exercises),
              exercises: exercises,
            ),
          );
          if (dateStr == _currentDateStr) _currentDocId = docId;
        }
      } catch (e) {
        debugPrint('Error saving workout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save workout.')),
          );
        }
      }
      widget.onWorkoutSaved();
      NotificationService().scheduleNotifications();
    });
  }

  /// Opens the set editor for a new exercise, or for the one at
  /// [exerciseIndex] when editing.
  Future<void> _showAddSetsDialog(
    String exerciseName, {
    int? exerciseIndex,
    List<models.Set> initialSets = const [],
  }) async {
    // Wait for the day to load, or saving would overwrite its exercises.
    if (_isLoadingWorkout) return;
    final dateStr = _currentDateStr;
    final result = await AddSets.show(
      context,
      exerciseName: exerciseName,
      initialSets: initialSets,
    );

    if (result == null || !mounted || dateStr != _currentDateStr) return;
    setState(() {
      if (exerciseIndex != null &&
          exerciseIndex >= 0 &&
          exerciseIndex < _exercises.length) {
        _exercises[exerciseIndex] = result;
      } else {
        _exercises.add(result);
      }
    });
    await _saveWorkout();
  }

  void _deleteExercise(int index) {
    final deletedExercise = _exercises[index];
    setState(() {
      _exercises.removeAt(index);
    });
    _saveWorkout();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.navy,
        content: Text('${deletedExercise.name} deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.cream,
          onPressed: () {
            setState(() {
              _exercises.insert(
                index.clamp(0, _exercises.length),
                deletedExercise,
              );
            });
            _saveWorkout();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onPageChanged(int index) {
    // The undo action of a delete snackbar belongs to the previous date.
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() {
      _currentPageIndex = index;
      _currentDate = _dateForPage(index);
    });
    _loadWorkoutForDate();
    _loadPastExercises();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy, // header background color
              onPrimary: AppColors.cream, // header text color
              onSurface: AppColors.navy, // body text color
              surface: AppColors.cream,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      jumpToDate(picked);
    }
  }

  void jumpToDate(DateTime picked) {
    final today = _dateForPage(_todayPage);
    final pickedDay = DateTime(picked.year, picked.month, picked.day);
    // Round to absorb the hour lost or gained across a DST change.
    final offset = (pickedDay.difference(today).inHours / 24).round();
    final targetPage = (_todayPage + offset).clamp(0, _todayPage);

    // Jump rather than animate, which would load every date in between.
    if (targetPage != _currentPageIndex) {
      _pageController.jumpToPage(targetPage);
    }
  }

  /// Reloads everything derived from the saved workouts, for when they were
  /// changed outside this screen.
  void reloadWorkouts() {
    _loadWorkoutForDate();
    _loadPastExercises();
    NotificationService().scheduleNotifications();
  }

  void _showHistoryBottomSheet(
    BuildContext context,
    String exerciseName,
    ExerciseHistory history,
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
                  Text(
                    history.date,
                    style: const TextStyle(fontSize: 14, color: AppColors.navy),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  history.text,
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
                        style: TextStyle(color: AppColors.navy),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddSetsDialog(
                          exerciseName,
                          initialSets: history.sets,
                        );
                        _addExerciseController.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: AppColors.cream,
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
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream.withValues(alpha: 0.5),
        elevation: 0,
        title: GestureDetector(
          onTap: _selectDate,
          child: Text(
            formatShortDate(_currentDate),
            style: const TextStyle(
              color: AppColors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        actions: [widget.appBarAction],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _todayPage + 1,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final bool isActivePage = index == _currentPageIndex;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                children: [
                  // Only the active page shows data; neighbouring pages
                  // would otherwise show this date's exercises mid-swipe.
                  if (isActivePage && _isLoadingWorkout)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.navy),
                    )
                  else if (!isActivePage || _exercises.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.dumbbell300,
                            size: 96,
                            color: AppColors.border,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Brightbell',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Positioned.fill(
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 120, bottom: 100),
                        itemCount: _exercises.length,
                        itemBuilder: (context, exIndex) {
                          final ex = _exercises[exIndex];
                          return ExerciseCard(
                            exercise: ex,
                            setsText: _setsToText(ex.sets),
                            onEdit: () {
                              _showAddSetsDialog(
                                ex.name,
                                exerciseIndex: exIndex,
                                initialSets: ex.sets,
                              );
                            },
                            onDelete: () => _deleteExercise(exIndex),
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
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
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
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: ListView.separated(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: suggestions.length,
                                          separatorBuilder: (context, index) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final suggestion =
                                                suggestions[index];
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
                                                _addExerciseController
                                                        .selection =
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
                                Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.navy,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        iconSize: 32,
                                        color: AppColors.cream,
                                        icon: const Icon(LucideIcons.brainCog),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ChatScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          left: 24,
                                          right: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _addExerciseController,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            hintText: 'Add Exercise',
                                            filled: true,
                                            fillColor: AppColors.surface,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              borderSide: BorderSide(
                                                color: AppColors.navy,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              borderSide: const BorderSide(
                                                color: AppColors.surface,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              borderSide: const BorderSide(
                                                color: AppColors.surface,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 24,
                                                ),
                                            suffixIcon: hasHistory
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8.0,
                                                        ),
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        LucideIcons.folderClock,
                                                        color: AppColors.navy,
                                                      ),
                                                      onPressed: () {
                                                        _showHistoryBottomSheet(
                                                          context,
                                                          _addExerciseController
                                                              .text
                                                              .trim(),
                                                          _pastExercises[currentText]!,
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          onSubmitted: (value) {
                                            if (value.trim().isEmpty) return;
                                            _showAddSetsDialog(value.trim());
                                            _addExerciseController.clear();
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
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
