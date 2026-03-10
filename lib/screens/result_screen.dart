import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studybuddy_client/screens/chat_screen.dart';
import 'package:studybuddy_client/widgets/custom_footer.dart';
import 'package:studybuddy_client/widgets/custom_navbar.dart';
import 'package:studybuddy_client/widgets/flashcard_widget.dart';
import 'package:studybuddy_client/widgets/quiz_widget.dart';
import 'package:studybuddy_client/widgets/flowchart_widget.dart';
import 'package:studybuddy_client/screens/board_screen.dart';
import 'package:studybuddy_client/services/api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ResultScreen({super.key, required this.data});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _localAudioPath;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _prepareAudio();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  Future<void> _prepareAudio() async {
    final audioBase64 = widget.data['audio_base64'];
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      if (kIsWeb) return;
      try {
        final bytes = base64Decode(audioBase64);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/summary_audio.wav');
        await file.writeAsBytes(bytes);
        setState(() {
          _localAudioPath = file.path;
        });
      } catch (e) {
        debugPrint('Error preparing audio: $e');
      }
    }
  }

  void _toggleAudio() async {
    final audioBase64 = widget.data['audio_base64'];
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (kIsWeb && audioBase64 != null) {
        final dataUri = 'data:audio/wav;base64,$audioBase64';
        await _audioPlayer.play(UrlSource(dataUri));
      } else if (_localAudioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_localAudioPath!));
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomNavbar(),
      body: Column(
        children: [
          _buildHeader(context),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Summary', icon: Icon(Icons.summarize_outlined)),
              Tab(text: 'Notes', icon: Icon(Icons.note_alt_outlined)),
              Tab(text: 'Flashcards', icon: Icon(Icons.style_outlined)),
              Tab(text: 'Flowchart', icon: Icon(Icons.account_tree_outlined)),
              Tab(text: 'Doubts', icon: Icon(Icons.question_answer_outlined)),
              Tab(text: 'Quiz', icon: Icon(Icons.quiz_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildNotesTab(),
                _buildFlashcardsTab(),
                _buildFlowchartTab(),
                _buildDoubtsTab(),
                _buildQuizTab(),
              ],
            ),
          ),
          const CustomFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.data['topic'] ?? 'Processing Result',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore your generated study materials below',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (widget.data['audio_base64'] != null)
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _toggleAudio,
                  tooltip: _isPlaying ? 'Pause' : 'Listen',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _startCollaboration,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Collaborate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startCollaboration() async {
    final topic = widget.data['topic'] ?? 'Study Session';
    final summaryId = widget.data['id'];

    if (summaryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start collaboration for unsaved note.'),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.createGroup(topic, summaryId);

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BoardScreen(group: response['group']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting collaboration: $e')),
        );
      }
    }
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            widget.data['summary'] ?? 'No summary available.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            widget.data['extractedText'] ?? 'No notes available.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFlashcardsTab() {
    final rawFlashNotes = widget.data['flash_notes'];

    if (rawFlashNotes == null) {
      return const Center(child: Text("No flash cards found."));
    }

    // Parse the notes into a list of {question, answer}
    final List<Map<String, String>> flashcards = [];

    if (rawFlashNotes is String) {
      final lines = rawFlashNotes.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('*')) continue;
        var content = trimmed.substring(1).trim();
        String question = '';
        String answer = '';
        if (content.contains(':')) {
          final parts = content.split(':');
          question = parts[0].trim();
          answer = parts.sublist(1).join(':').trim();
        } else if (content.contains(' - ')) {
          final parts = content.split(' - ');
          question = parts[0].trim();
          answer = parts.sublist(1).join(' - ').trim();
        } else {
          question = "Definition";
          answer = content;
        }
        if (question.isNotEmpty && answer.isNotEmpty) {
          flashcards.add({
            'question': question.replaceAll('**', ''),
            'answer': answer.replaceAll('**', ''),
          });
        }
      }
    } else if (rawFlashNotes is List) {
      for (var item in rawFlashNotes) {
        if (item is Map) {
          flashcards.add({
            'question': (item['question'] ?? item['front'] ?? 'Question')
                .toString()
                .replaceAll('**', ''),
            'answer': (item['answer'] ?? item['back'] ?? 'Answer')
                .toString()
                .replaceAll('**', ''),
          });
        }
      }
    } else if (rawFlashNotes is Map) {
      // Possible fallback for map-based flash notes
      rawFlashNotes.forEach((key, value) {
        flashcards.add({
          'question': key.toString().replaceAll('**', ''),
          'answer': value.toString().replaceAll('**', ''),
        });
      });
    }

    if (flashcards.isEmpty) {
      if (rawFlashNotes is String) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: MarkdownBody(
              data: rawFlashNotes,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
          ),
        );
      }
      return const Center(child: Text("No flash cards could be parsed."));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 250,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
      ),
      itemCount: flashcards.length,
      itemBuilder: (context, index) {
        final card = flashcards[index];
        return FlashcardWidget(
          question: card['question']!,
          answer: card['answer']!,
        );
      },
    );
  }

  Widget _buildFlowchartTab() {
    final flowchartData =
        widget.data['flowchart'] as Map<String, dynamic>? ?? {};
    return FlowchartWidget(flowchartData: flowchartData);
  }

  Widget _buildDoubtsTab() {
    return ChatScreen(
      initialMessage:
          "I have some doubts about ${widget.data['topic']}. Can you help?",
    );
  }

  Widget _buildQuizTab() {
    final quiz = widget.data['quiz'] as List<dynamic>? ?? [];
    if (quiz.isEmpty) return const Center(child: Text("No quiz available."));
    return QuizWidget(quizData: quiz);
  }
}
