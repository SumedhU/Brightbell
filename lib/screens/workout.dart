import 'package:brightbell/screens/settings.dart';
import 'package:brightbell/utils/textfield_formatter.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/screens/add_sets.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'dart:async';
import 'package:brightbell/models/exercise.dart' as models;
import 'package:brightbell/models/workout.dart' as workout_model;

import 'package:brightbell/screens/analytics/analytics.dart';

class Workout extends StatefulWidget {
  const Workout({super.key});

  @override
  State<Workout> createState() => _WorkoutState();
}

class WorkoutTextController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    List<TextSpan> spans = [];
    final textStyle = style ?? const TextStyle();

    // Pattern matches something like [10, 135](W) or [10, 135](D) or [10, 135]
    text.splitMapJoin(
      RegExp(r'\[[0-9.]+, [0-9.]+\](?:\([WD]\))?'),
      onMatch: (m) {
        String match = m[0]!;
        TextStyle matchStyle = textStyle;
        if (match.endsWith('(W)')) {
          matchStyle = matchStyle.copyWith(color: Colors.blue);
        } else if (match.endsWith('(D)')) {
          matchStyle = matchStyle.copyWith(color: Colors.red);
        }
        spans.add(TextSpan(text: match, style: matchStyle));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(text: n, style: textStyle));
        return '';
      },
    );

    return TextSpan(style: textStyle, children: spans);
  }
}

class _WorkoutState extends State<Workout> {
  final WorkoutTextController _controller = WorkoutTextController();
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

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _loadStreak();

    _controller.addListener(() {
      if (_isLoading) return;
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
        _saveWorkout();
      });
    });

    _loadWorkoutForDate();
    _loadPastExercises();
  }

  Future<void> _loadPastExercises() async {
    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    try {
      final history = await WorkoutUtils.getLatestExercisesHistory(beforeDateStr: dateStr);
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
    _isLoading = true;
    _currentDocId = null;
    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';

    try {
      final workout = await WorkoutUtils.loadWorkoutForDate(dateStr);

      if (workout != null) {
        _currentDocId = workout.docId;
        _controller.text = workout.rawText;
      } else {
        _controller.text = '';
      }
    } catch (e) {
      print('Error loading workout: $e');
      _controller.text = '';
    }
    _isLoading = false;
  }

  Future<void> _saveWorkout() async {
    String dateStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}-${_currentDate.day.toString().padLeft(2, '0')}';
    final rawText = _controller.text;
    final exercises = _parseTextToExercises(rawText);

    try {
      final workout = workout_model.Workout(
        docId: _currentDocId,
        date: dateStr,
        userId: '',
        rawText: rawText,
        exercises: exercises,
      );
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
          r'\[([0-9.]+),\s*([0-9.]+)\](\([WD]\))?',
        ).allMatches(line);
        for (final match in matches) {
          int reps = double.parse(match.group(1)!).toInt();
          double weight = double.parse(match.group(2)!);
          String type = match.group(3) ?? '';
          bool isWarmUp = type == '(W)';
          bool isDropSet = type == '(D)';
          currentSets.add(
            models.Set(
              id: setIdCounter++,
              numberOfReps: reps,
              weight: weight,
              isWarmUp: isWarmUp,
              isDropSet: isDropSet,
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
    List<int> goalDays = savedDays != null ? savedDays.map((e) => int.parse(e)).toList() : [1, 2, 3, 4, 5, 6, 7];

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
    List<int> goalDays = savedDays != null ? savedDays.map((e) => int.parse(e)).toList() : [1, 2, 3, 4, 5, 6, 7];

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
    String? initialSetsText,
    int? replaceStart,
    int? replaceEnd,
    int? insertAt,
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
      final currentText = _controller.text;

      if (replaceStart != null && replaceEnd != null) {
        // Replacing an existing line
        String newText =
            currentText.substring(0, replaceStart) +
            result.trimRight() +
            currentText.substring(replaceEnd);
        _controller.value = _controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
            offset: replaceStart + result.trimRight().length,
          ),
        );
      } else if (insertAt != null) {
        if (result.trimRight().isEmpty) return;

        String toInsert = '\n' + result.trimRight();
        if (insertAt == currentText.length || currentText[insertAt] != '\n') {
          toInsert += '\n';
        }

        String newText =
            currentText.substring(0, insertAt) +
            toInsert +
            currentText.substring(insertAt);

        int newCursorOffset = insertAt + toInsert.length;
        if (insertAt < currentText.length && currentText[insertAt] == '\n') {
          newCursorOffset += 1;
        }

        _controller.value = _controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorOffset),
        );
      } else {
        // Appending
        _controller.value = _controller.value.copyWith(
          text: currentText + result,
          selection: TextSelection.collapsed(
            offset: (currentText + result).length,
          ),
        );
      }
    }
  }

  void _onLongPress() {
    int cursorPos = _controller.selection.baseOffset;
    String text = _controller.text;

    if (cursorPos >= 0 && cursorPos <= text.length) {
      int lineStart = text.lastIndexOf('\n', cursorPos - 1) + 1;
      int lineEnd = text.indexOf('\n', cursorPos);
      if (lineEnd == -1) lineEnd = text.length;

      String line = text.substring(lineStart, lineEnd);

      // If the line contains a set format like [reps, weight]
      if (line.contains('[') && line.contains(']')) {
        String exerciseName = "Exercise";
        if (lineStart > 0) {
          int prevLineStart = text.lastIndexOf('\n', lineStart - 2) + 1;
          exerciseName = text.substring(prevLineStart, lineStart - 1).trim();
        }

        _showAddSetsBottomSheet(
          exerciseName,
          initialSetsText: line,
          replaceStart: lineStart,
          replaceEnd: lineEnd,
        );
      } else if (line.trim().isNotEmpty && !line.trim().startsWith('-')) {
        String exerciseName = line.trim();
        String initialSetsText = '';
        int replaceStart = lineEnd;
        int replaceEnd = lineEnd;

        if (lineEnd < text.length) {
          int nextLineEnd = text.indexOf('\n', lineEnd + 1);
          if (nextLineEnd == -1) nextLineEnd = text.length;
          String nextLine = text.substring(lineEnd + 1, nextLineEnd);
          if (nextLine.contains('[') && nextLine.contains(']')) {
            initialSetsText = nextLine;
            replaceStart = lineEnd + 1;
            replaceEnd = nextLineEnd;
          }
        }

        if (initialSetsText.isNotEmpty) {
          _showAddSetsBottomSheet(
            exerciseName,
            initialSetsText: initialSetsText,
            replaceStart: replaceStart,
            replaceEnd: replaceEnd,
          );
        } else {
          _showAddSetsBottomSheet(exerciseName, insertAt: lineEnd);
        }
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
    _controller.dispose();
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

  List<Widget> _buildHistoryIcons(double maxWidth) {
    List<Widget> icons = [];
    final text = _controller.text;
    final lines = text.split('\n');
    int currentIndex = 0;

    final textStyle = const TextStyle(fontSize: 18, height: 1.5);
    final painter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.trim().isNotEmpty && !line.trim().startsWith('-') && !line.trim().startsWith('[')) {
        String exerciseName = line.trim().toLowerCase();
        if (_pastExercises.containsKey(exerciseName)) {
          // Layout text up to this line
          painter.text = TextSpan(text: text, style: textStyle);
          painter.layout(maxWidth: maxWidth);
          
          final offset = painter.getOffsetForCaret(TextPosition(offset: currentIndex), Rect.zero);
          double y = offset.dy;
          if (_scrollController.hasClients && _scrollController.positions.length == 1) {
            y -= _scrollController.offset;
          } else if (_scrollController.hasClients && _scrollController.positions.length > 1) {
            y -= _scrollController.positions.last.pixels;
          }

          // Only add if visible (roughly)
          if (y > -50 && y < 1000) {
            bool isShowingHistory = _historyTimers.containsKey(exerciseName);
            icons.add(
              Positioned(
                right: 0,
                top: isShowingHistory ? y : y - 8, // Adjust for IconButton padding
                child: isShowingHistory
                    ? GestureDetector(
                        onTap: () {
                          final dateStr = _pastExercises[exerciseName]?['date'];
                          if (dateStr != null && dateStr.isNotEmpty) {
                            try {
                              final targetDate = DateTime.parse(dateStr);
                              
                              DateTime today = DateTime.now();
                              DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);
                              DateTime targetUtc = DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
                              int offset = targetUtc.difference(todayUtc).inDays;
                        
                              int targetPage = 10000 + offset;
                              
                              if (_pageController.page?.round() != targetPage) {
                                _pageController.animateToPage(
                                  targetPage,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            } catch (e) {
                              // Ignore parse errors
                            }
                          }
                          setState(() {
                            _historyTimers[exerciseName]?.cancel();
                            _historyTimers.remove(exerciseName);
                          });
                        },
                        child: Container(
                          constraints: BoxConstraints(maxWidth: maxWidth * 0.7),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _pastExercises[exerciseName]?['text']?.replaceAll('\n', '  ') ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.history, size: 20, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _historyTimers[exerciseName]?.cancel();
                            _historyTimers[exerciseName] = Timer(const Duration(seconds: 10), () {
                              if (mounted) {
                                setState(() {
                                  _historyTimers.remove(exerciseName);
                                });
                              }
                            });
                          });
                        },
                      ),
              ),
            );
          }
        }
      }
      currentIndex += line.length + 1; // +1 for newline
    }
    return icons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: Colors.white,
        elevation: 0,
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
              child: const Icon(Icons.settings_outlined, color: Colors.black, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: const Icon(Icons.edit),
          fabSize: ExpandableFabSize.regular,
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: const Icon(Icons.close),
          fabSize: ExpandableFabSize.small,
          foregroundColor: Colors.redAccent,
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        children: [
          FloatingActionButton.small(
            heroTag: null,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Analytics(scrollToWeights: true)),
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.monitor_weight_outlined),
          ),
          FloatingActionButton.small(
            heroTag: null,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Analytics(scrollToWeights: false)),
              );
            },
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            GestureDetector(
                              onDoubleTap: _onLongPress,
                              child: TextField(
                                controller: _controller,
                                scrollController: isActivePage ? _scrollController : null,
                                focusNode: _focusNode,
                                maxLines: null,
                                expands: true,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [WorkoutFormattingFormatter()],
                                onSubmitted: (value) {
                                  _updateStreak(); // Increment/manage streak when submitting
                                  
                                  int cursorPos = _controller.selection.baseOffset;
                                  if (cursorPos < 0 || cursorPos > value.length)
                                    cursorPos = value.length;
                                  
                                  String exerciseName = '';
                                  int insertPosition = cursorPos;
                                  bool isSetLine = false;
                                  int setLineEnd = -1;
                                  
                                  // Find the line containing the cursor or the closest non-empty line before it
                                  int searchPos = cursorPos;
                                  while (searchPos >= 0) {
                                    int lineStart = value.lastIndexOf('\n', searchPos - 1) + 1;
                                    int lineEnd = value.indexOf('\n', searchPos);
                                    if (lineEnd == -1) lineEnd = value.length;
                                    
                                    String line = value.substring(lineStart, lineEnd).trim();
                                    if (line.isNotEmpty) {
                                      if (!line.startsWith('[') && !line.startsWith('-')) {
                                        exerciseName = line;
                                        insertPosition = lineEnd;
                                      } else if (line.startsWith('[')) {
                                        isSetLine = true;
                                        setLineEnd = lineEnd;
                                      }
                                      break;
                                    }
                                    searchPos = lineStart - 1;
                                    if (searchPos < 0) break;
                                  }
                                  
                                  if (exerciseName.isNotEmpty) {
                                    String initialSetsText = '';
                                    int? replaceStart;
                                    int? replaceEnd;
                                    
                                    if (insertPosition < value.length) {
                                      int nextLineEnd = value.indexOf('\n', insertPosition + 1);
                                      if (nextLineEnd == -1) nextLineEnd = value.length;
                                      String nextLine = value.substring(insertPosition + 1, nextLineEnd);
                                      if (nextLine.contains('[') && nextLine.contains(']')) {
                                        initialSetsText = nextLine;
                                        replaceStart = insertPosition + 1;
                                        replaceEnd = nextLineEnd;
                                      }
                                    }
                                    
                                    if (initialSetsText.isNotEmpty) {
                                      _showAddSetsBottomSheet(
                                        exerciseName,
                                        initialSetsText: initialSetsText,
                                        replaceStart: replaceStart,
                                        replaceEnd: replaceEnd,
                                      );
                                    } else {
                                      _showAddSetsBottomSheet(
                                        exerciseName,
                                        insertAt: insertPosition,
                                      );
                                    }
                                  } else if (isSetLine) {
                                    if (setLineEnd == value.length) {
                                      _controller.value = _controller.value.copyWith(
                                        text: value + '\n',
                                        selection: TextSelection.collapsed(offset: value.length + 1),
                                      );
                                    } else {
                                      _controller.selection = TextSelection.collapsed(offset: setLineEnd + 1);
                                    }
                                    Future.delayed(Duration.zero, () {
                                      _focusNode.requestFocus();
                                    });
                                  }
                                },
                                style: const TextStyle(fontSize: 18, height: 1.5),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Bench Press\n...',
                                  hintStyle: TextStyle(color: Colors.black38),
                                ),
                              ),
                            ),
                            if (isActivePage)
                              AnimatedBuilder(
                                animation: Listenable.merge([_controller, _scrollController]),
                                builder: (context, child) {
                                  return Stack(
                                    children: _buildHistoryIcons(constraints.maxWidth),
                                  );
                                },
                              ),
                          ],
                        );
                      }
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
