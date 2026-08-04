import 'package:flutter/material.dart';
import 'package:brightbell/models/exercise.dart' as models;

class ExerciseCard extends StatelessWidget {
  final models.Exercise exercise;
  final String setsText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onEditName;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.setsText,
    required this.onEdit,
    required this.onDelete,
    required this.onEditName,
  });

  void _showEditNameDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController(text: exercise.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Exercise Name'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: "Exercise name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = _controller.text.trim();
                if (newName.isNotEmpty && newName != exercise.name) {
                  onEditName(newName);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onDoubleTap: () => _showEditNameDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (exercise.sets.isNotEmpty)
                      Text(
                        setsText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
