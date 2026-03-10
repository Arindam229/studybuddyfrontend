import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';
import 'package:studybuddy_client/services/api_service.dart';
import 'package:studybuddy_client/services/auth_service.dart';
import 'package:studybuddy_client/widgets/flashcard_widget.dart';
import 'package:studybuddy_client/widgets/quiz_widget.dart';
import 'package:studybuddy_client/widgets/flowchart_widget.dart';
import 'package:studybuddy_client/screens/chat_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:studybuddy_client/utils/html_stub.dart'
    if (dart.library.html) 'dart:html'
    as html;
import 'package:studybuddy_client/utils/js_util_stub.dart'
    if (dart.library.html) 'dart:js_util'
    as js_util;

class BoardScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const BoardScreen({super.key, required this.group});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class RemoteCursor {
  final String name;
  final Offset position;
  final Color color;
  RemoteCursor({
    required this.name,
    required this.position,
    required this.color,
  });
}

class _BoardScreenState extends State<BoardScreen> {
  // Agora State
  RtcEngine? _engine;
  bool _localUserJoined = false;
  final Set<int> _remoteUids = {}; // Support multiple remote users
  bool _muted = false;
  bool _videoDisabled = false;
  bool _showPeople = false;
  bool _showMeetingInfo = true;
  bool _sdkLoaded = false;
  final List<FloatingReaction> _reactions = []; // Active floating reactions
  final List<String> _reactionEmojis = ['👍', '❤️', '🎉', '😮', '😢', '🔥'];

  // Navigation & Data State
  int _currentTab = 0; // 0: Summary, 1-5: Others, 6: Whiteboard
  Map<String, dynamic>? _summaryData;
  bool _isLoadingSummary = false;

  // Whiteboard Tools State
  Color _selectedColor = Colors.black;
  double _strokeWidth = 4.0;
  bool _isEraser = false;
  final Map<String, RemoteCursor> _remoteCursors = {};
  String? _currentUserId;
  String? _currentUserName;
  late IO.Socket _socket;
  final List<DrawingPoint?> _drawingPoints = [];
  final GlobalKey _whiteboardKey =
      GlobalKey(); // Key for coordinate calculation

  @override
  void initState() {
    super.initState();
    _currentUserId =
        AuthService().currentUser?.uid ??
        'user_${DateTime.now().millisecondsSinceEpoch}';
    _currentUserName = AuthService().currentUser?.displayName ?? 'Student';
    _initAgora();
    _initSocket();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    final summaryId = widget.group['summaryId'];
    if (summaryId == null || summaryId == 'general') return;

    if (mounted) setState(() => _isLoadingSummary = true);
    try {
      final response = await ApiService.getDocumentById(summaryId);
      final doc = response['document'];
      if (doc != null) {
        debugPrint('[SUMMARY DEBUG] Full Document Data: $doc');
        if (mounted) {
          setState(() {
            _summaryData = doc;
            _isLoadingSummary = false;
          });
        }
      }
    } catch (e) {
      debugPrint(
        '[SUMMARY ERROR] Error fetching summary for id $summaryId: $e',
      );
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching summary: $e')));
      }
    }
  }

  @override
  void dispose() {
    _socket.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // --- Socket Logic ---
  void _initSocket() {
    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      print('Socket connected: ${_socket.id}');
      _socket.emit('join-room', widget.group['id']);
    });

    // Listen for drawing data
    _socket.on('draw', (data) {
      if (mounted) {
        setState(() {
          final userId = data['userId'];
          final userName = data['userName'] ?? 'User';

          if (data['type'] == 'point') {
            final color = data['isEraser']
                ? Colors.white
                : Color(data['color']);
            _drawingPoints.add(
              DrawingPoint(
                offset: Offset(data['x'].toDouble(), data['y'].toDouble()),
                paint: Paint()
                  ..color = color
                  ..strokeWidth = data['width'].toDouble()
                  ..strokeCap = StrokeCap.round
                  ..blendMode = data['isEraser']
                      ? BlendMode.clear
                      : BlendMode.srcOver,
              ),
            );

            // Update remote cursor
            _remoteCursors[userId] = RemoteCursor(
              name: userName,
              position: Offset(data['x'].toDouble(), data['y'].toDouble()),
              color: Color(data['color']),
            );
          } else if (data['type'] == 'end') {
            _drawingPoints.add(null);
            _remoteCursors.remove(userId);
          } else if (data['type'] == 'clear') {
            _drawingPoints.clear();
          }
        });
      }
    });

    // Listen for navigation sync
    _socket.on('sync-navigation', (data) {
      if (mounted) {
        setState(() {
          _currentTab = data['tabIndex'];
        });
      }
    });

    // Listen for reactions
    _socket.on('reaction', (data) {
      if (mounted) {
        _showFloatingReaction(data['emoji'], data['userName'] ?? 'Someone');
      }
    });
  }

  // --- Agora Logic ---
  Future<void> _initAgora() async {
    if (kIsWeb) {
      int retries = 0;
      while (retries < 10 && mounted) {
        try {
          final hasAgora = js_util.hasProperty(html.window, 'AgoraRTC');
          if (hasAgora) {
            setState(() => _sdkLoaded = true);
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 1000));
        retries++;
      }
      if (!_sdkLoaded && mounted) {
        return;
      }
    }

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Get token from backend
    try {
      final tokenResponse = await ApiService.getVideoToken(widget.group['id']);
      // Debug: print token response to help diagnose web issues
      debugPrint('[AGORA DEBUG] tokenResponse: $tokenResponse');
      final appId = tokenResponse['appId'];
      final token = tokenResponse['token'];

      debugPrint(
        '[AGORA DEBUG] appId: $appId, token present: ${token != null}',
      );

      if (appId == null || appId.toString().isEmpty) {
        debugPrint('[AGORA ERROR] Missing appId from token response');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agora App ID missing from server response'),
          ),
        );
        return;
      }
      if (token == null || token.toString().isEmpty) {
        debugPrint('[AGORA ERROR] Missing token from token response');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agora token missing from server response'),
            ),
          );
        }
        return;
      }

      try {
        _engine = createAgoraRtcEngine();
        await _engine!.initialize(RtcEngineContext(appId: appId));
      } catch (e) {
        debugPrint('[AGORA ERROR] createAgoraRtcEngine failed: $e');
        return;
      }

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              '[AGORA EVENT] onJoinChannelSuccess fired - connection channel: ${connection.channelId}',
            );
            if (mounted) {
              setState(() {
                _localUserJoined = true;
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint(
              '[AGORA EVENT] onUserJoined fired - remoteUid: $remoteUid',
            );
            if (mounted) {
              setState(() {
                _remoteUids.add(remoteUid);
              });
            }
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint(
                  '[AGORA EVENT] onUserOffline fired - remoteUid: $remoteUid',
                );
                if (mounted) {
                  setState(() {
                    _remoteUids.remove(remoteUid);
                  });
                }
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AGORA ERROR EVENT] Error: $err, Message: $msg');
          },
          onTokenPrivilegeWillExpire:
              (RtcConnection connection, String token) async {
                debugPrint('[AGORA EVENT] onTokenPrivilegeWillExpire');
                try {
                  final newTokenResponse = await ApiService.getVideoToken(
                    widget.group['id'] ?? 'general',
                  );
                  final newToken = newTokenResponse['token'];
                  if (newToken != null) {
                    await _engine?.renewToken(newToken);
                  }
                } catch (e) {
                  debugPrint('[AGORA ERROR] Failed to renew token: $e');
                }
              },
        ),
      );

      await _engine!.enableAudio();
      await _engine!.enableVideo();
      debugPrint('[AGORA DEBUG] Audio/Video enabled. Starting preview...');
      await _engine!.startPreview();
      debugPrint('[AGORA DEBUG] Preview started.');

      if (mounted) {
        setState(() {});
      }
      try {
        await _engine!.joinChannel(
          token: token,
          channelId: widget.group['id'],
          uid: 0,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        );
        debugPrint('[AGORA DEBUG] joinChannel SUCCESS (command sent)');
        try {
          _engine?.muteLocalAudioStream(false);
          _engine?.enableLocalVideo(true);
        } catch (e) {
          debugPrint('[AGORA DEBUG] error in explicit publish enable: $e');
        }
      } catch (joinErr) {
        debugPrint('[AGORA ERROR] joinChannel failed: $joinErr');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join Agora channel: $joinErr')),
          );
        }
      }
    } catch (e) {
      debugPrint('Agora initialization error: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.group['name']} - Live Board'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _showInviteDialog,
            tooltip: 'Invite Friends',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _drawingPoints.clear()),
            tooltip: 'Clear whiteboard',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Main Content Layer
          Column(
            children: [
              _buildTabSelector(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildMainContent()),
                    if (_localUserJoined || _remoteUids.isNotEmpty)
                      _buildVideoSidebar(),
                  ],
                ),
              ),
            ],
          ),

          // Control Toolbar (Google Meet Style)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: _buildMeetControls(),
          ),

          // Meeting Info Overlay
          if (_showMeetingInfo) _buildMeetingInfoOverlay(),

          // People Overlay
          if (_showPeople) _buildPeopleOverlay(),

          // Reactions Layer
          ..._reactions.map((r) => _buildFloatingReaction(r)),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tabControl('Summary', 0, Icons.description_outlined),
            _tabControl('Notes', 1, Icons.note_alt_outlined),
            _tabControl('Flashcards', 2, Icons.style_outlined),
            _tabControl('Flowchart', 3, Icons.account_tree_outlined),
            _tabControl('Doubts', 4, Icons.question_answer_outlined),
            _tabControl('Quiz', 5, Icons.quiz_outlined),
            _tabControl('Whiteboard', 6, Icons.draw_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentTab) {
      case 0:
        return _buildSummaryView();
      case 1:
        return _buildNotesTab();
      case 2:
        return _buildFlashcardsTab();
      case 3:
        return _buildFlowchartTab();
      case 4:
        return _buildDoubtsTab();
      case 5:
        return _buildQuizTab();
      case 6:
        return _buildWhiteboard();
      default:
        return _buildSummaryView();
    }
  }

  Widget _buildNotesTab() {
    if (_summaryData == null) return _emptyState('No notes available.');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: _summaryData!['extractedText'] ?? 'No notes content.',
      ),
    );
  }

  Widget _buildFlashcardsTab() {
    final rawFlashNotes = _summaryData?['flash_notes'];
    if (rawFlashNotes == null) return _emptyState('No flashcards found.');

    final List<Map<String, String>> flashcards = [];

    void parseItem(dynamic item) {
      if (item == null) return;
      if (item is String) {
        // Try JSON first
        try {
          final decoded = jsonDecode(item);
          if (decoded is List) {
            for (var sub in decoded) parseItem(sub);
            return;
          } else if (decoded is Map) {
            parseItem(decoded);
            return;
          }
        } catch (_) {}

        // Not JSON, try Markdown-style lines (from ResultScreen)
        final lines = item.split('\n');
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('*')) continue;
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
      } else if (item is Map) {
        final q =
            (item['question'] ?? item['front'] ?? item['Question'] ?? item['q'])
                ?.toString();
        final a =
            (item['answer'] ?? item['back'] ?? item['Answer'] ?? item['a'])
                ?.toString();
        if (q != null && a != null) {
          flashcards.add({'question': q, 'answer': a});
        }
      }
    }

    if (rawFlashNotes is List) {
      for (var item in rawFlashNotes) parseItem(item);
    } else {
      parseItem(rawFlashNotes);
    }

    if (flashcards.isEmpty) return _emptyState('Could not parse flashcards.');

    return Container(
      color: Colors.grey[100],
      child: GridView.builder(
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
      ),
    );
  }

  Widget _buildFlowchartTab() {
    final rawFlowchart = _summaryData?['flowchart'];

    Map<String, dynamic> flowchartData = {
      'nodes': [
        {'id': 'n1', 'label': 'Core Concept', 'color': Colors.blue[100]!.value},
        {'id': 'n2', 'label': 'Research', 'color': Colors.green[100]!.value},
        {'id': 'n3', 'label': 'Planning', 'color': Colors.orange[100]!.value},
        {'id': 'n4', 'label': 'Execution', 'color': Colors.purple[100]!.value},
      ],
      'edges': [
        {'from': 'n1', 'to': 'n2'},
        {'from': 'n2', 'to': 'n3'},
        {'from': 'n3', 'to': 'n4'},
      ],
    };

    if (rawFlowchart != null) {
      if (rawFlowchart is Map<String, dynamic> && rawFlowchart.isNotEmpty) {
        flowchartData = rawFlowchart;
      } else if (rawFlowchart is String && rawFlowchart.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawFlowchart);
          if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
            flowchartData = decoded;
          }
        } catch (_) {}
      }
    }

    return Container(
      color: Colors.white,
      child: FlowchartWidget(
        flowchartData: flowchartData,
        isEditable: false,
        onChanged: (result) {
          setState(() {
            _summaryData?['flowchart'] = result;
          });
          final docId = widget.group['summaryId'];
          if (docId != null && docId != 'general') {
            ApiService.updateDocument(docId, {'flowchart': result}).catchError((
              e,
            ) {
              debugPrint('[FLOWCHART SAVE ERROR] $e');
              return <String, dynamic>{};
            });
          }
        },
      ),
    );
  }

  Widget _buildDoubtsTab() {
    return ChatScreen(
      initialMessage:
          "Collaboratively discussing ${_summaryData?['topic'] ?? 'these notes'}.",
    );
  }

  Widget _buildQuizTab() {
    final rawQuiz = _summaryData?['quiz'];
    if (rawQuiz == null) return _emptyState('No quiz available.');

    List<dynamic> quiz = [];
    if (rawQuiz is List) {
      quiz = rawQuiz;
    } else if (rawQuiz is String) {
      try {
        final decoded = jsonDecode(rawQuiz);
        if (decoded is List) quiz = decoded;
      } catch (_) {}
    }

    if (quiz.isEmpty) return _emptyState('No quiz content found.');
    return Container(
      color: Colors.white,
      child: QuizWidget(quizData: quiz),
    );
  }

  Widget _emptyState(String msg) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _tabControl(String label, int index, IconData icon) {
    final active = _currentTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTab = index);
        _socket.emit('sync-navigation', {
          'roomId': widget.group['id'],
          'tabIndex': index,
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_isLoadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summaryData == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'No shared note summary linked to this group.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: _summaryData!['summary'] ?? 'No summary content available.',
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16, color: Colors.black87),
          h1: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          h2: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteboard() {
    return Stack(
      children: [
        Container(
          color: Colors.white,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final RenderBox renderBox =
                    _whiteboardKey.currentContext!.findRenderObject()
                        as RenderBox;
                final Offset localPos = renderBox.globalToLocal(
                  details.globalPosition,
                );

                final point = DrawingPoint(
                  offset: localPos,
                  paint: Paint()
                    ..color = _isEraser ? Colors.white : _selectedColor
                    ..strokeWidth = _strokeWidth
                    ..strokeCap = StrokeCap.round
                    ..blendMode = _isEraser
                        ? BlendMode.clear
                        : BlendMode.srcOver,
                );
                _drawingPoints.add(point);

                _socket.emit('draw', {
                  'roomId': widget.group['id'],
                  'userId': _currentUserId,
                  'userName': _currentUserName,
                  'type': 'point',
                  'x': localPos.dx,
                  'y': localPos.dy,
                  'color': _selectedColor.value,
                  'width': _strokeWidth,
                  'isEraser': _isEraser,
                });
              });
            },
            onPanEnd: (_) {
              setState(() => _drawingPoints.add(null));
              _socket.emit('draw', {
                'roomId': widget.group['id'],
                'userId': _currentUserId,
                'type': 'end',
              });
            },
            child: CustomPaint(
              key: _whiteboardKey,
              size: Size.infinite,
              painter: WhiteboardPainter(points: _drawingPoints),
            ),
          ),
        ),

        // Remote Cursors (Figma-like)
        ..._remoteCursors.values.map((cursor) => _buildRemoteCursor(cursor)),

        // Whiteboard Toolbar
        Positioned(top: 16, left: 16, child: _buildWhiteboardToolbar()),
      ],
    );
  }

  Widget _buildRemoteCursor(RemoteCursor cursor) {
    return Positioned(
      left: cursor.position.dx,
      top: cursor.position.dy,
      child: Column(
        children: [
          Icon(Icons.edit, size: 24, color: cursor.color),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cursor.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cursor.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteboardToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolIcon(
            Icons.brush,
            !_isEraser,
            () => setState(() => _isEraser = false),
          ),
          _toolIcon(
            Icons.auto_fix_normal,
            _isEraser,
            () => setState(() => _isEraser = true),
          ),
          const VerticalDivider(),
          _colorCircle(Colors.black),
          _colorCircle(Colors.red),
          _colorCircle(Colors.blue),
          _colorCircle(Colors.green),
          _colorCircle(Colors.orange),
          const VerticalDivider(),
          _strokeSlider(),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon, bool active, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        icon,
        color: active ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      onPressed: onTap,
    );
  }

  Widget _colorCircle(Color color) {
    bool active = _selectedColor == color && !_isEraser;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedColor = color;
        _isEraser = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _strokeSlider() {
    return SizedBox(
      width: 80,
      child: Slider(
        value: _strokeWidth,
        min: 2,
        max: 20,
        onChanged: (val) => setState(() => _strokeWidth = val),
      ),
    );
  }

  Widget _buildVideoSidebar() {
    if (!_localUserJoined && _remoteUids.isEmpty) return const SizedBox();

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        border: Border(left: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _videoCard("You", _localVideo()),
          ..._remoteUids.map(
            (uid) => _videoCard("Guest $uid", _remoteVideo(uid)),
          ),
        ],
      ),
    );
  }

  Widget _videoCard(String label, Widget video) {
    return Container(
      height: 150,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          video,
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _localVideo() {
    if (_engine == null) return const SizedBox();
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0), // Use 0 for local on web/mobile
      ),
    );
  }

  Widget _remoteVideo(int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: widget.group['id']),
      ),
    );
  }

  Widget _buildMeetControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withAlpha(0x4D),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _meetButton(
            _muted ? Icons.mic_off : Icons.mic,
            _muted ? Colors.redAccent : Colors.white,
            _muted ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
            () {
              setState(() => _muted = !_muted);
              _engine?.muteLocalAudioStream(_muted);
            },
          ),
          const SizedBox(width: 12),
          _meetButton(
            _videoDisabled ? Icons.videocam_off : Icons.videocam,
            _videoDisabled ? Colors.redAccent : Colors.white,
            _videoDisabled
                ? Colors.redAccent.withOpacity(0.2)
                : Colors.transparent,
            () {
              setState(() => _videoDisabled = !_videoDisabled);
              _engine?.enableLocalVideo(!_videoDisabled);
            },
          ),
          const SizedBox(width: 12),
          _meetButton(
            Icons.info_outline,
            _showMeetingInfo ? Colors.cyanAccent : Colors.white,
            _showMeetingInfo
                ? Colors.cyanAccent.withOpacity(0.2)
                : Colors.transparent,
            () => setState(() => _showMeetingInfo = !_showMeetingInfo),
          ),
          const SizedBox(width: 12),
          _meetButton(
            Icons.add_reaction_outlined,
            Colors.white,
            Colors.transparent,
            _showReactionPicker,
          ),
          const SizedBox(width: 12),
          _meetButton(
            Icons.people_outline,
            _showPeople ? Colors.cyanAccent : Colors.white,
            _showPeople
                ? Colors.cyanAccent.withOpacity(0.2)
                : Colors.transparent,
            () => setState(() => _showPeople = !_showPeople),
          ),
          const SizedBox(width: 12),
          _meetButton(
            Icons.call_end,
            Colors.white,
            Colors.redAccent,
            () => Navigator.pop(context),
            isEnd: true,
          ),
        ],
      ),
    );
  }

  void _showReactionPicker() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF202124),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _reactionEmojis.map((emoji) {
              return IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sendReaction(emoji);
                },
                icon: Text(emoji, style: const TextStyle(fontSize: 24)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _sendReaction(String emoji) {
    _socket.emit('reaction', {
      'roomId': widget.group['id'],
      'emoji': emoji,
      'userName': _currentUserName,
    });
    _showFloatingReaction(emoji, 'You');
  }

  void _showFloatingReaction(String emoji, String user) {
    final reaction = FloatingReaction(
      emoji: emoji,
      userName: user,
      id: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      _reactions.add(reaction);
    });

    // Remove after animation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _reactions.removeWhere((r) => r.id == reaction.id);
        });
      }
    });
  }

  Widget _buildFloatingReaction(FloatingReaction reaction) {
    return Positioned(
      bottom: 100,
      left: MediaQuery.of(context).size.width * 0.4 + (reaction.id % 100),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 4),
        builder: (context, value, child) {
          return Opacity(
            opacity: 1.0 - value,
            child: Transform.translate(
              offset: Offset(0, -value * 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reaction.userName,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(reaction.emoji, style: const TextStyle(fontSize: 40)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _meetButton(
    IconData icon,
    Color color,
    Color bgColor,
    VoidCallback onTap, {
    bool isEnd = false,
  }) {
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isEnd
                ? null
                : Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildMeetingInfoOverlay() {
    final inviteCode =
        widget.group['inviteCode'] ?? widget.group['id'] ?? '...';
    return Positioned(
      left: 24,
      bottom: 100,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Your meeting's ready",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showMeetingInfo = false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text("Invite others"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a73e8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Or share this meeting code with others you want in the meeting",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteCode,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleOverlay() {
    return Positioned(
      right: 24,
      bottom: 140,
      top: 100,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF202124),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "People",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showPeople = false),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                children: [
                  _peopleTile("You (Local User)", isLocal: true),
                  ..._remoteUids.map((uid) => _peopleTile("Collaborator $uid")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peopleTile(String name, {bool isLocal = false}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blueGrey,
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: Icon(
        isLocal ? (_muted ? Icons.mic_off : Icons.mic) : Icons.mic,
        color: isLocal && _muted ? Colors.redAccent : Colors.white54,
        size: 18,
      ),
    );
  }

  void _showInviteDialog() {
    final inviteCode =
        widget.group['inviteCode'] ?? widget.group['id'] ?? '...';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Collaborators'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your friends:'),
            const SizedBox(height: 16),
            SelectableText(
              inviteCode,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            child: const Text('Copy Code'),
          ),
        ],
      ),
    );
  }
}

class FloatingReaction {
  final String emoji;
  final String userName;
  final int id;
  FloatingReaction({
    required this.emoji,
    required this.userName,
    required this.id,
  });
}

class DrawingPoint {
  Offset offset;
  Paint paint;
  DrawingPoint({required this.offset, required this.paint});
}

class WhiteboardPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  WhiteboardPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [
          points[i]!.offset,
        ], points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) => true;
}
