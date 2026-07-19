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
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  // 0: normal, 1: warm, 2: drop
  int _setType = 0;

  final List<models.Set> _addedSets = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSetsText != null) {
      Iterable<Match> matches = RegExp(
        r'\[([0-9.]+),\s*([0-9.]+)\](?:\(([WD])\))?',
      ).allMatches(widget.initialSetsText!);
      for (Match m in matches) {
        int reps = int.tryParse(m.group(1)!) ?? 0;
        double weight = double.tryParse(m.group(2)!) ?? 0.0;
        bool isWarm = m.group(3) == 'W';
        bool isDrop = m.group(3) == 'D';
        _addedSets.add(
          models.Set(
            id: DateTime.now().millisecondsSinceEpoch,
            numberOfReps: reps,
            weight: weight,
            isWarmUp: isWarm,
            isDropSet: isDrop,
          ),
        );
      }
    }
  }

  void _addSet() {
    String reps = _repsController.text.isNotEmpty ? _repsController.text : '0';
    String weight = _weightController.text.isNotEmpty ? _weightController.text : '0';

    int repsInt = int.tryParse(reps) ?? 0;
    double weightDouble = double.tryParse(weight) ?? 0.0;

    setState(() {
      _addedSets.add(
        models.Set(
          id: DateTime.now().millisecondsSinceEpoch,
          numberOfReps: repsInt,
          weight: weightDouble,
          isWarmUp: _setType == 1,
          isDropSet: _setType == 2,
        ),
      );
      _repsController.clear();
    });
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(
          context,
          _addedSets.map((s) => s.toText()).join(' ') + '\n',
        );
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
                  child: Text(
                    'Add sets for ${widget.exerciseName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _addedSets.map((s) => s.toText()).join(' ') + '\n',
                      );
                    },
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
            if (_addedSets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Added:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._addedSets.asMap().entries.map((entry) {
                      int idx = entry.key;
                      models.Set data = entry.value;

                      Color textColor = Colors.black;
                      if (data.isWarmUp) textColor = Colors.blue;
                      if (data.isDropSet) textColor = Colors.red;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data.toText().trim(),
                            style: TextStyle(fontSize: 16, color: textColor),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                _repsController.text = data.numberOfReps
                                    .toString();
                                // Format weight to avoid .0 if not needed when editing
                                _weightController.text =
                                    data.weight == data.weight.roundToDouble()
                                    ? data.weight.toInt().toString()
                                    : data.weight.toString();
                                _setType = data.isWarmUp
                                    ? 1
                                    : data.isDropSet
                                    ? 2
                                    : 0;
                                _addedSets.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (lbs)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _addSet(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ToggleButtons(
                isSelected: [_setType == 1, _setType == 2],
                onPressed: (index) {
                  setState(() {
                    int newType = index + 1;
                    if (_setType == newType) {
                      _setType = 0; // Toggle off if already selected
                    } else {
                      _setType = newType;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Warm Up Set'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Drop Set'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _addSet,
                    child: const Text(
                      'Add Set',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
