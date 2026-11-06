import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/models/workout.dart';
import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

class WorkoutListScreen extends StatefulWidget {
  final ValueChanged<DateTime> onSelectDate;

  /// Called after a workout is deleted or renamed.
  final VoidCallback onWorkoutsChanged;

  /// Shown at the end of the app bar.
  final Widget appBarAction;

  const WorkoutListScreen({
    super.key,
    required this.onSelectDate,
    required this.onWorkoutsChanged,
    required this.appBarAction,
  });

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  static const int _pageSize = 15;

  final List<Workout> _workouts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialWorkouts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreWorkouts();
    }
  }

  Future<void> _loadInitialWorkouts() async {
    setState(() {
      _isLoading = true;
      _workouts.clear();
      _hasMore = true;
    });

    final newWorkouts = await WorkoutUtils.getWorkoutsPaginated(
      limit: _pageSize,
    );

    if (mounted) {
      setState(() {
        _workouts.addAll(newWorkouts);
        _isLoading = false;
        _hasMore = newWorkouts.length == _pageSize;
      });
    }
  }

  Future<void> _loadMoreWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    final lastDate = _workouts.isNotEmpty ? _workouts.last.date : null;
    final newWorkouts = await WorkoutUtils.getWorkoutsPaginated(
      lastDate: lastDate,
      limit: _pageSize,
    );

    if (mounted) {
      setState(() {
        _workouts.addAll(newWorkouts);
        _isLoading = false;
        _hasMore = newWorkouts.length == _pageSize;
      });
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    return date != null ? formatLongDate(date) : dateStr;
  }

  Future<void> _editTitle(Workout workout) async {
    final controller = TextEditingController(text: workout.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Workout Title'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new title'),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newTitle != null &&
        newTitle.isNotEmpty &&
        newTitle != workout.title &&
        workout.docId != null) {
      await WorkoutUtils.updateTitle(workout.docId!, newTitle);
      _loadInitialWorkouts();
      widget.onWorkoutsChanged();
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          'This removes ${workout.title} on ${_formatDate(workout.date)} and all its exercises.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.cream,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await WorkoutUtils.deleteWorkout(workout.date);
    _loadInitialWorkouts();
    widget.onWorkoutsChanged();
  }

  void _shareWorkout(Workout workout) {
    String text = '${workout.title} - ${_formatDate(workout.date)}\n\n';
    if (workout.exercises.isNotEmpty) {
      for (var ex in workout.exercises) {
        text += '${ex.name}:\n';
        for (var set in ex.sets) {
          text += '  - ${set.toText()}\n';
        }
      }
    } else {
      text += workout.rawText;
    }

    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          'Brightbell',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.orange,
          ),
        ),
        actions: [widget.appBarAction],
        elevation: 0,
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "Recent Workouts",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          Expanded(
            child: _workouts.isEmpty && _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.navy),
                  )
                : _workouts.isEmpty
                ? const Center(child: Text('No workouts logged yet.'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _workouts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _workouts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.navy,
                            ),
                          ),
                        );
                      }
                      final workout = _workouts[index];
                      return InkWell(
                        onTap: () {
                          widget.onSelectDate(DateTime.parse(workout.date));
                        },
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            backgroundColor: AppColors.cream,
                            builder: (context) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),

                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Icon(LucideIcons.share2300),
                                      title: Text('Share'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _shareWorkout(workout);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('Edit Title'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _editTitle(workout);
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(LucideIcons.trash300),
                                      title: const Text('Delete'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _deleteWorkout(workout);
                                      },
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workout.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(workout.date),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
