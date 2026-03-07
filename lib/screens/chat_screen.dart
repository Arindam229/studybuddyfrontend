import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studybuddy_client/services/api_service.dart';
import 'package:studybuddy_client/services/auth_service.dart';

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
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

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
            historyData['history'].map(
              (item) => {
                'text': item['text'],
                'isUser': item['role'] == 'user',
              },
            ),
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

    setState(() {
      _messages.add({'text': messageText, 'isUser': true});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendChat(messageText);
      if (response['success']) {
        setState(() {
          _messages.add({'text': response['reply'], 'isUser': false});
        });
        _scrollToBottom();
      }
    } catch (e) {
      _showError("Failed to send message: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImageUpload() async {
    try {
      // Pick an image from the camera (can be gallery on desktop/web if camera is unavailable)
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

      final response = await ApiService.uploadImage(image);

      setState(() {
        // Remove the placeholder message
        _messages.removeWhere((msg) => msg['isImagePlaceholder'] == true);

        if (response['success']) {
          _messages.add({
            'text':
                "Image scanned. Extracted Text:\n\n${response['data']['extractedText']}",
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyBuddy AI'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
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
                final isUser = message['isUser'] as bool;

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isUser
                            ? const Radius.circular(0)
                            : const Radius.circular(20),
                        bottomLeft: isUser
                            ? const Radius.circular(20)
                            : const Radius.circular(0),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      message['text'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16.0,
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
              child: CircularProgressIndicator(),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              onPressed: _handleImageUpload,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8.0),
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _handleSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
