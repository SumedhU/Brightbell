import 'package:flutter/material.dart';
import 'package:brightbell/models/exercise.dart' as models;

class AddSets extends StatefulWidget {
  final String exerciseName;
  final String? initialSetsText;

  const AddSets({super.key, required this.exerciseName, this.initialSetsText});

  @override
  State<AddSets> createState() => _AddSetsState();
}

class _AddSetsState extends State<AddSets> {
  late TextEditingController _exerciseNameController;
  final List<models.Set> _addedSets = [];
  final List<TextEditingController> _repsControllers = [];
  final List<TextEditingController> _weightControllers = [];

  @override
  void initState() {
    super.initState();
    _exerciseNameController = TextEditingController(text: widget.exerciseName);
    if (widget.initialSetsText != null) {
      Iterable<Match> matches = RegExp(
        r'\[([0-9.]+),\s*([0-9.]+)\](?:\(([WDF])\))?',
      ).allMatches(widget.initialSetsText!);
      for (Match m in matches) {
        int reps = int.tryParse(m.group(1)!) ?? 0;
        double weight = double.tryParse(m.group(2)!) ?? 0.0;
        bool isWarm = m.group(3) == 'W';
        bool isDrop = m.group(3) == 'D';
        bool isFail = m.group(3) == 'F';
        _addSetToState(
          models.Set(
            id: DateTime.now().millisecondsSinceEpoch,
            numberOfReps: reps,
            weight: weight,
            isWarmUp: isWarm,
            isDropSet: isDrop,
            isFailure: isFail,
          ),
        );
      }
    }

    if (_addedSets.isEmpty) {
      _addNewSet();
    }
  }

  void _addSetToState(models.Set set) {
    _addedSets.add(set);
    _repsControllers.add(TextEditingController(text: set.numberOfReps > 0 ? set.numberOfReps.toString() : ''));
    _weightControllers.add(TextEditingController(
      text: set.weight > 0 ? (set.weight == set.weight.roundToDouble() ? set.weight.toInt().toString() : set.weight.toString()) : ''
    ));
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
    super.dispose();
  }

  void _handleDone() {
    _syncControllersToSets();
    bool hasValidSet = _addedSets.any((s) => s.numberOfReps > 0);
    if (!hasValidSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise must have at least one set with reps > 0'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      '${_exerciseNameController.text.trim()}\n${_addedSets.map((s) => s.toText()).join(' ')}\n',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _syncControllersToSets();
        bool hasValidSet = _addedSets.any((s) => s.numberOfReps > 0);
        if (!hasValidSet) {
          Navigator.pop(context, null);
        } else {
          Navigator.pop(
            context,
            '${_exerciseNameController.text.trim()}\n${_addedSets.map((s) => s.toText()).join(' ')}\n',
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _exerciseNameController,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Exercise Name',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleDone,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _addedSets.length,
                itemBuilder: (context, index) {
                  final set = _addedSets[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Set ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeSet(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _weightControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Weight (lbs)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _repsControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'Reps',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: -8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: set.isWarmUp,
                                    onChanged: (val) {
                                      setState(() {
                                        set.isWarmUp = val ?? false;
                                      });
                                    },
                                  ),
                                  const Text('Warm Up'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: set.isDropSet,
                                    onChanged: (val) {
                                      setState(() {
                                        set.isDropSet = val ?? false;
                                      });
                                    },
                                  ),
                                  const Text('Drop Set'),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: set.isFailure,
                                    onChanged: (val) {
                                      setState(() {
                                        set.isFailure = val ?? false;
                                      });
                                    },
                                  ),
                                  const Text('Failure'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _addNewSet,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '+ Add Set',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
