import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brightbell/models/exercise.dart' as models;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddSets extends StatefulWidget {
  final String exerciseName;
  final List<models.Set> initialSets;

  const AddSets({
    super.key,
    required this.exerciseName,
    this.initialSets = const [],
  });

  /// Slides the editor up from the bottom of the screen. Resolves to the
  /// edited exercise, or null if it was discarded.
  static Future<models.Exercise?> show(
    BuildContext context, {
    required String exerciseName,
    List<models.Set> initialSets = const [],
  }) {
    return showGeneralDialog<models.Exercise>(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (context, animation, secondaryAnimation) =>
          AddSets(exerciseName: exerciseName, initialSets: initialSets),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<AddSets> createState() => _AddSetsState();
}

class _AddSetsState extends State<AddSets> {
  late TextEditingController _exerciseNameController;
  final List<models.Set> _addedSets = [];
  final List<TextEditingController> _repsControllers = [];
  final List<TextEditingController> _weightControllers = [];
  final ScrollController _scrollController = ScrollController();
  // The editor has its own messenger so its snackbars show above the route.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _exerciseNameController = TextEditingController(text: widget.exerciseName);
    // Copy so that cancelling doesn't modify the caller's sets.
    for (final set in widget.initialSets) {
      _addSetToState(set.copy());
    }

    if (_addedSets.isEmpty) {
      _addNewSet();
    }
  }

  void _addSetToState(models.Set set) {
    _addedSets.add(set);
    _repsControllers.add(
      TextEditingController(
        text: set.numberOfReps > 0 ? set.numberOfReps.toString() : '',
      ),
    );
    _weightControllers.add(
      TextEditingController(
        text: set.weight > 0
            ? (set.weight == set.weight.roundToDouble()
                  ? set.weight.toInt().toString()
                  : set.weight.toString())
            : '',
      ),
    );
  }

  void _addNewSet() {
    setState(() {
      double lastWeight = 0;
      int lastReps = 0;
      if (_addedSets.isNotEmpty) {
        lastWeight = double.tryParse(_weightControllers.last.text) ?? 0;
        lastReps = int.tryParse(_repsControllers.last.text) ?? 0;
      }

      _addSetToState(
        models.Set(
          id: DateTime.now().millisecondsSinceEpoch,
          numberOfReps: lastReps,
          weight: lastWeight,
          isWarmUp: false,
          isDropSet: false,
          isFailure: false,
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeSet(int index) {
    setState(() {
      _addedSets.removeAt(index);
      _repsControllers[index].dispose();
      _repsControllers.removeAt(index);
      _weightControllers[index].dispose();
      _weightControllers.removeAt(index);
    });
  }

  void _syncControllersToSets() {
    for (int i = 0; i < _addedSets.length; i++) {
      _addedSets[i].numberOfReps = int.tryParse(_repsControllers[i].text) ?? 0;
      _addedSets[i].weight = double.tryParse(_weightControllers[i].text) ?? 0.0;
    }
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    for (var c in _repsControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// The edited exercise, or null if no set has any reps.
  models.Exercise? _buildResult() {
    _syncControllersToSets();
    if (!_addedSets.any((s) => s.numberOfReps > 0)) return null;
    final name = _exerciseNameController.text.trim();
    return models.Exercise(
      name: name.isNotEmpty ? name : widget.exerciseName,
      numberOfSets: _addedSets.length,
      sets: List.of(_addedSets),
    );
  }

  void _handleDone() {
    final result = _buildResult();
    if (result == null) {
      _messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Add reps to at least one set'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Going back saves the exercise if it has a valid set.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _buildResult());
      },
      // Leave a strip of the screen above the sheet so it reads as a sheet.
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ScaffoldMessenger(
              key: _messengerKey,
              child: Scaffold(
                backgroundColor: AppColors.cream,
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < _addedSets.length; i++)
                                _buildSetCard(i),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: _addNewSet,
                                icon: const Icon(LucideIcons.plus, size: 18),
                                label: const Text('Add Set'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.navy,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x),
            tooltip: 'Discard',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _exerciseNameController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Exercise name',
              ),
            ),
          ),
          FilledButton(
            onPressed: _handleDone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.cream,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCard(int index) {
    final set = _addedSets[index];
    // Fades and rises in when a set is added. Keyed by the set object so
    // removing a set doesn't replay the animation on the others.
    return TweenAnimationBuilder<double>(
      key: ObjectKey(set),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSetBadge(index, set),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    _weightControllers[index],
                    'lbs',
                    decimal: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNumberField(_repsControllers[index], 'reps'),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.trash300,
                    color: AppColors.navy,
                    size: 20,
                  ),
                  tooltip: 'Remove set',
                  onPressed: () => _removeSet(index),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              // Line the chips up with the input fields.
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip(
                    'Warm-up',
                    set.isWarmUp,
                    (value) => set.isWarmUp = value,
                  ),
                  _buildTypeChip(
                    'Drop set',
                    set.isDropSet,
                    (value) => set.isDropSet = value,
                  ),
                  _buildTypeChip(
                    'Failure',
                    set.isFailure,
                    (value) => set.isFailure = value,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The set number, or W / D / F (same priority as [models.Set.toText]).
  Widget _buildSetBadge(int index, models.Set set) {
    final label = set.isWarmUp
        ? 'W'
        : set.isDropSet
        ? 'D'
        : set.isFailure
        ? 'F'
        : '${index + 1}';
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.cream,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String unit, {
    bool decimal = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimal ? r'[0-9.]' : r'[0-9]'),
        ),
      ],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '0',
        suffixText: unit,
        suffixStyle: TextStyle(fontSize: 13, color: AppColors.navy),
        filled: true,
        fillColor: AppColors.cream,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (value) => setState(() => onChanged(value)),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.cream : AppColors.navy,
      ),
      backgroundColor: AppColors.cream,
      selectedColor: AppColors.navy,
      side: BorderSide(color: selected ? AppColors.navy : AppColors.border),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
