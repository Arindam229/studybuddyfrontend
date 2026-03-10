import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studybuddy_client/services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentScreenshotText;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messages.add({'text': widget.initialMessage!, 'isUser': true});
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final historyData = await ApiService.getHistory();
      if (historyData['success']) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(
            historyData['history'].map((item) {
              final textRaw = item['text'];
              String text;
              if (textRaw is List) {
                text = textRaw.join('\n');
              } else {
                text = textRaw?.toString() ?? '';
              }

              return {'text': text, 'isUser': item['role'] == 'user'};
            }),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      _showError("Failed to load history: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();

    final screenshotContext = _currentScreenshotText;
    _currentScreenshotText = null; // Use once then clear to avoid confusion

    setState(() {
      _messages.add({'text': messageText, 'isUser': true});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendChat(
        messageText,
        screenshotText: screenshotContext,
      );
      if (response['success']) {
        setState(() {
          final replyRaw = response['reply'];
          String reply;
          if (replyRaw is List) {
            reply = replyRaw.join('\n');
          } else {
            reply = replyRaw?.toString() ?? 'Empty reply';
          }
          _messages.add({'text': reply, 'isUser': false});
        });
        _scrollToBottom();
      }
    } catch (e) {
      _showError("Failed to send message: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() {
        _isLoading = true;
        _messages.add({
          'text': "Uploading image: ${image.name}...",
          'isUser': true,
          'isImagePlaceholder': true,
        });
      });
      _scrollToBottom();

      final response = await ApiService.uploadChatImage(image);

      setState(() {
        _messages.removeWhere((msg) => msg['isImagePlaceholder'] == true);
        if (response['success']) {
          final extracted = response['data']['extractedText'];
          if (extracted is List) {
            _currentScreenshotText = extracted.join('\n');
          } else {
            _currentScreenshotText = extracted?.toString();
          }

          _messages.add({
            'text':
                "Image scanned. You can now ask questions about this screenshot!",
            'isUser': false,
          });
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg['isImagePlaceholder'] == true);
      });
      _showError("Failed to upload image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _clearHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.clearHistory();
      if (response['success']) {
        setState(() {
          _messages.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat history cleared.')),
          );
        }
      }
    } catch (e) {
      _showError("Failed to clear history: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          TextButton.icon(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('Clear Chat'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                try {
                  final message = _messages[index];
                  final isUser = message['isUser'] == true;

                  return Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isUser
                                  ? const Radius.circular(0)
                                  : const Radius.circular(12),
                              bottomLeft: isUser
                                  ? const Radius.circular(12)
                                  : const Radius.circular(0),
                            ),
                          ),
                          child: Text(
                            (message['text'] ?? '').toString(),
                            style: TextStyle(
                              color: isUser
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSecondary,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  return const ListTile(
                    title: Text(
                      'Error rendering message',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
              },
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),

          // Input Area
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      onPressed: _uploadImage,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type your question...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _handleSendMessage,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
