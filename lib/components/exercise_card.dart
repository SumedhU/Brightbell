import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:brightbell/models/exercise.dart' as models;
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final controller = TextEditingController(text: exercise.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Exercise Name'),
          content: TextField(
            controller: controller,
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
                final newName = controller.text.trim();
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
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onDoubleTap: () => _showEditNameDialog(context),
        splashColor: AppColors.border,
        highlightColor: AppColors.border,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (exercise.sets.isNotEmpty)
                      Text(
                        setsText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.trash300,
                  color: AppColors.navy,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
