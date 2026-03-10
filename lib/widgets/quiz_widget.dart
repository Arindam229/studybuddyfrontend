import 'package:flutter/material.dart';

class QuizWidget extends StatefulWidget {
  final List<dynamic> quizData;

  const QuizWidget({super.key, required this.quizData});

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentIndex = 0;
  String? _selectedOption;
  bool _isAnswered = false;
  int _score = 0;

  void _submitAnswer(String option) {
    if (_isAnswered) return;
    setState(() {
      _selectedOption = option;
      _isAnswered = true;
      if (option == widget.quizData[_currentIndex]['correctAnswer']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _isAnswered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.quizData.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              "Quiz Completed!",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Your Score: $_score / ${widget.quizData.length}",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _selectedOption = null;
                  _isAnswered = false;
                });
              },
              child: const Text("Restart Quiz"),
            ),
          ],
        ),
      );
    }

    final question = widget.quizData[_currentIndex];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.quizData.length,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 32),
            Text(
              "Question ${_currentIndex + 1} of ${widget.quizData.length}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              question['question'],
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ...List.generate((question['options'] as List).length, (index) {
              final option = question['options'][index];
              final isSelected = _selectedOption == option;
              final isCorrect = option == question['correctAnswer'];

              Color color = Colors.transparent;
              if (_isAnswered) {
                if (isCorrect) color = Colors.green.withValues(alpha: 0.2);
                if (isSelected && !isCorrect)
                  color = Colors.red.withValues(alpha: 0.2);
              } else if (isSelected) {
                color = Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _submitAnswer(option),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isAnswered
                            ? (isCorrect
                                  ? Colors.green
                                  : (isSelected
                                        ? Colors.red
                                        : Colors.grey.withValues(alpha: 0.3)))
                            : (isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.withValues(alpha: 0.3)),
                        width: isSelected || (_isAnswered && isCorrect) ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: color,
                    ),
                    child: Row(
                      children: [
                        Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected || (_isAnswered && isCorrect)
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        if (_isAnswered && isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (_isAnswered && isSelected && !isCorrect)
                          const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_isAnswered) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  child: Text(
                    _currentIndex == widget.quizData.length - 1
                        ? "See Results"
                        : "Next Question",
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
