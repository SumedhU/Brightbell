import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:brightbell/utils/date_utils.dart';
import 'package:brightbell/utils/streak_utils.dart';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/workout_utils.dart';

const _model = 'gemini-3.8-flash';

// Keeps the prompt within context limits.
const _maxWorkoutsInContext = 20;

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _buildUserContext() async {
    final workouts = await WorkoutUtils.getAllWorkouts();
    final goalDays = await UserUtils.getGoalDays();
    final streak = StreakUtils.getCurrentStreak(
      StreakUtils.calculateTimeline(workouts, goalDays),
    );

    final sb = StringBuffer()
      ..writeln(
        "The user's planned workout days: ${goalDays.map((d) => _dayNames[d - 1]).join(', ')}.",
      )
      ..writeln('Current streak: $streak days.')
      ..writeln();

    if (workouts.isEmpty) {
      sb.writeln('The user has no logged workouts.');
    } else {
      sb.writeln(
        "Here is the user's workout history (from newest to oldest). Sets are written [reps, weight in lbs], with (W) warm-up, (D) drop set and (F) to failure:",
      );
      for (var w in workouts.take(_maxWorkoutsInContext)) {
        sb.writeln('Date: ${w.date} (${w.title})\nExercises:\n${w.rawText}\n');
      }
    }
    return sb.toString();
  }

  Future<void> _initChat() async {
    String userContext;
    try {
      userContext = await _buildUserContext();
    } catch (e) {
      userContext = "The user's workout history could not be loaded.";
      _messages.add({
        'role': 'error',
        'text': 'Failed to load workout history: $e',
      });
    }

    final systemInstruction =
        '''You are an AI Coach for a fitness app called Brightbell.
Your role is to ONLY answer questions related to workouts and fitness.
You must use the provided workout data to recommend workouts based on the user's history and length of absence from their last logged workout.
Current date: ${dateKey(DateTime.now())}
If the user asks about anything not related to fitness or workouts, politely decline to answer.

$userContext''';

    _chat = FirebaseAI.googleAI()
        .generativeModel(
          model: _model,
          systemInstruction: Content.system(systemInstruction),
        )
        .startChat();

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    // One message at a time keeps the chat history in order.
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    Map<String, dynamic> reply;
    try {
      final response = await _chat.sendMessage(Content.text(text));
      reply = {'role': 'ai', 'text': response.text ?? 'No response'};
    } catch (e) {
      reply = {'role': 'error', 'text': 'Error: $e'};
    }

    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('AI Coach'),
        backgroundColor: AppColors.cream,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      final isError = message['role'] == 'error';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 16.0,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.navy
                                : (isError
                                      ? AppColors.danger
                                      : AppColors.surface),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            message['text'] ?? '',
                            style: TextStyle(
                              color: isUser || isError
                                  ? AppColors.cream
                                  : AppColors.navy,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: AppColors.navy),
                  ),
                Container(
                  padding: const EdgeInsets.all(16.0).copyWith(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Ask anything...',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 16.0,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: AppColors.cream,
                          ),
                          onPressed: _isLoading ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
