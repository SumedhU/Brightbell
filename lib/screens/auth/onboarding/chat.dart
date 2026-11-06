import 'package:brightbell/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:brightbell/utils/user_utils.dart';
import 'package:brightbell/utils/notification_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

enum OptionType { buttons, daysSelection }

class ChatOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const ChatOnboardingScreen({super.key, required this.onComplete});

  @override
  State<ChatOnboardingScreen> createState() => _ChatOnboardingScreenState();
}

class _ChatOnboardingScreenState extends State<ChatOnboardingScreen> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  List<String> _currentOptions = [];
  List<String> _pendingOptions = [];

  OptionType _currentOptionType = OptionType.buttons;
  OptionType _pendingOptionType = OptionType.buttons;

  final List<int> _selectedDays = [];

  static const _dayLabels = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    _showBotMessage("WELCOME TO BRIGHTBELL! ARE YOU READY TO LIFT?", [
      "YES",
      "NO",
    ]);
  }

  void _showBotMessage(
    String text,
    List<String> options, {
    OptionType optionType = OptionType.buttons,
  }) {
    setState(() {
      _isTyping = true;
      _currentOptions = [];
      _currentOptionType = OptionType.buttons;
      _pendingOptions = options;
      _pendingOptionType = optionType;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: text, isUser: false));
      });
      _scrollToBottom();
    });
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
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

  Future<void> _handleOptionSelected(String option) async {
    setState(() {
      _currentOptions = [];
      _currentOptionType = OptionType.buttons;
    });
    _addMessage(ChatMessage(text: option, isUser: true));

    if (option == "YES") {
      _showBotMessage(
        "THAT'S THE SPIRIT! I ONLY HAVE 2 QUESTIONS BEFORE STARTING.",
        ["NEXT"],
      );
    } else if (option == "NO") {
      _showBotMessage(
        "NO WORRIES! LET'S SET YOU UP FOR WHEN YOU WANT TO START YOUR WORKOUT. I ONLY HAVE 2 QUESTIONS TO BE READY.",
        ["NEXT"],
      );
    } else if (option == "NEXT") {
      bool hasGoalDays = false;
      try {
        hasGoalDays = await UserUtils.hasGoalDays();
      } catch (_) {
        // Offline: just ask again.
      }
      if (!mounted) return;
      if (hasGoalDays) {
        _showBotMessage("I'LL REMIND YOU TO WORKOUT ON YOUR SELECTED DAYS.", [
          "REMIND ME TO PRACTICE",
        ]);
      } else {
        _showBotMessage(
          "WHICH DAYS ARE YOU GOING TO WORKOUT?",
          [],
          optionType: OptionType.daysSelection,
        );
      }
    } else if (option == "REMIND ME TO PRACTICE") {
      await NotificationService().setNotificationsEnabled(true);
      if (!mounted) return;
      _showBotMessage("PROFILE SETUP COMPLETE.", ["CONTINUE"]);
    } else if (option == "CONTINUE") {
      widget.onComplete();
    }
  }

  Future<void> _handleDaysSelectionDone() async {
    setState(() {
      _currentOptions = [];
      _currentOptionType = OptionType.buttons;
    });

    // No selection means every day.
    final days = [
      for (int day = 1; day <= 7; day++)
        if (_selectedDays.isEmpty || _selectedDays.contains(day)) day,
    ];
    final msg = days.length == 7
        ? "EVERY DAY"
        : days.map((day) => _dayLabels[day - 1]).join(", ");
    _addMessage(ChatMessage(text: msg, isUser: true));

    await UserUtils.saveGoalDays(days);
    if (!mounted) return;
    _showBotMessage("I'LL REMIND YOU TO WORKOUT ON YOUR SELECTED DAYS.", [
      "REMIND ME TO PRACTICE",
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(
          "INITIALIZING...",
          style: GoogleFonts.pressStart2p(
            color: AppColors.orange,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: NintendoChatBubble(
                      message: message,
                      onProgress: _scrollToBottom,
                      onAnimationComplete: () {
                        _scrollToBottom();
                        // Offer the reply options once the latest bot message
                        // has finished typing out.
                        if (index == _messages.length - 1 && !message.isUser) {
                          setState(() {
                            _currentOptions = _pendingOptions;
                            _currentOptionType = _pendingOptionType;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "...",
                  style: GoogleFonts.pressStart2p(
                    fontSize: 20,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          if (_currentOptionType == OptionType.buttons &&
              _currentOptions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.navy, width: 4),
                ),
                color: AppColors.cream,
              ),
              child: SafeArea(
                child: Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  alignment: WrapAlignment.spaceEvenly,
                  children: _currentOptions.map((option) {
                    return GestureDetector(
                      onTap: () => _handleOptionSelected(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.navy, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.navy,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.pressStart2p(
                            fontSize: 12,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          else if (_currentOptionType == OptionType.daysSelection)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.navy, width: 4),
                ),
                color: AppColors.cream,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.center,
                      children: List.generate(7, (index) {
                        int dayValue = index + 1;
                        bool isSelected = _selectedDays.contains(dayValue);
                        String dayLabel = _dayLabels[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDays.remove(dayValue);
                              } else {
                                _selectedDays.add(dayValue);
                              }
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.navy
                                  : AppColors.surface,
                              border: Border.all(
                                color: AppColors.navy,
                                width: 4,
                              ),
                            ),
                            child: Text(
                              dayLabel,
                              style: GoogleFonts.pressStart2p(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.cream
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _handleDaysSelectionDone,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.navy, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.navy,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          "DONE",
                          style: GoogleFonts.pressStart2p(
                            fontSize: 12,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NintendoChatBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onProgress;
  final VoidCallback onAnimationComplete;

  const NintendoChatBubble({
    super.key,
    required this.message,
    required this.onProgress,
    required this.onAnimationComplete,
  });

  @override
  State<NintendoChatBubble> createState() => _NintendoChatBubbleState();
}

class _NintendoChatBubbleState extends State<NintendoChatBubble> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(NintendoChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.text != widget.message.text) {
      _timer?.cancel();
      _displayedText = "";
      _currentIndex = 0;
      _startTyping();
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_currentIndex < widget.message.text.length) {
        if (mounted) {
          setState(() {
            _displayedText += widget.message.text[_currentIndex];
            _currentIndex++;
          });
        }
        if (_currentIndex % 10 == 0) {
          widget.onProgress();
        }
      } else {
        timer.cancel();
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.navy, width: 4),
        boxShadow: const [
          BoxShadow(color: AppColors.navy, offset: Offset(4, 4)),
        ],
      ),
      child: Text(
        _displayedText,
        style: GoogleFonts.pressStart2p(
          fontSize: 12,
          height: 1.5,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
