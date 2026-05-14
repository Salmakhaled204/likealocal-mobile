import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ── Data model for a single chat message ─────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];

  // keeps conversation history for context
  final List<Map<String, String>> _conversationHistory = [];

  bool _isLoading = false;

  // ── Gemini API settings ─────────────────────────────────────────────────────
  // Paste your Gemini API key here between the quotes.
  static const String _apiKey = 'AIzaSyAJiB16C9K1Pc2a4f4vD57K7EN4-8kOQOM';

  // Current Gemini Flash model
  static const String _modelName = 'gemini-2.5-flash';

  static const String _systemPrompt = '''
You are LikeALocal's friendly travel assistant. You help users discover authentic local places, hidden gems, restaurants, cafes, and experiences in cities around the world — especially in Cairo, Egypt.

You can:
- Recommend places based on budget, atmosphere, and category
- Give local tips and travel advice
- Suggest what to order or do at specific places
- Help users understand how to use the LikeALocal app
- Answer questions about neighbourhoods, best times to visit, and local culture

Keep responses friendly, concise, and practical. Use bullet points for lists. Ask follow-up questions only when needed.
''';

  @override
  void initState() {
    super.initState();

    _messages.add(
      ChatMessage(
        text:
            "Hi! I'm your LikeALocal assistant 🗺️\n\nAsk me anything — best cheap restaurants, hidden gems near you, what to do tonight, or tips for exploring like a local!",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final text = _inputController.text.trim();

    if (text.isEmpty || _isLoading) return;

    // correct key check
    if (_apiKey == 'PASTE_YOUR_KEY_HERE' || _apiKey.trim().isEmpty) {
      _addErrorMessage(
        'Gemini API key is missing. Please paste your API key in the code first.',
      );
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );

      _conversationHistory.add({'role': 'user', 'content': text});

      _isLoading = true;
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      // keep only recent messages to reduce token usage
      final recentHistory = _conversationHistory.length > 8
          ? _conversationHistory.sublist(_conversationHistory.length - 8)
          : _conversationHistory;

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt},
            ],
          },
          'contents': recentHistory.map((message) {
            return {
              'role': message['role'] == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': message['content'] ?? ''},
              ],
            };
          }).toList(),
          'generationConfig': {'maxOutputTokens': 500, 'temperature': 0.7},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final candidates = data['candidates'] as List<dynamic>?;
        final firstCandidate = candidates?.isNotEmpty == true
            ? candidates!.first as Map<String, dynamic>
            : null;
        final content = firstCandidate?['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        final firstPart = parts?.isNotEmpty == true
            ? parts!.first as Map<String, dynamic>
            : null;
        final reply = firstPart?['text'];

        final finalReply = reply == null || reply.toString().trim().isEmpty
            ? _emptyResponseMessage(data)
            : reply.toString();

        setState(() {
          _messages.add(
            ChatMessage(
              text: finalReply,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );

          _conversationHistory.add({
            'role': 'assistant',
            'content': finalReply,
          });
        });
      } else {
        _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      _addErrorMessage(
        'Something went wrong. Please check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _scrollToBottom();
    }
  }

  void _handleApiError(int statusCode, String body) {
    String cleanMessage = 'Something went wrong. Please try again.';

    try {
      final data = jsonDecode(body);
      final errorMessage = data['error']?['message']?.toString() ?? '';

      if (statusCode == 429 || errorMessage.toLowerCase().contains('quota')) {
        cleanMessage =
            'Gemini API limit reached. Please wait 1 minute and try again.\n\nIf it keeps happening, your API key has no free quota left. Create a new key or enable billing.';
      } else if (statusCode == 400) {
        cleanMessage =
            'Bad request. Please check the API request format and try again.';
      } else if (statusCode == 403) {
        cleanMessage =
            'API key problem. Please check that your Gemini API key is correct and enabled.';
      } else if (statusCode == 404) {
        cleanMessage =
            'Model not found. Change _modelName to another Gemini model, for example gemini-2.5-flash.';
      } else {
        cleanMessage = 'Error $statusCode: $errorMessage';
      }
    } catch (_) {
      cleanMessage = 'Error $statusCode. Please try again.';
    }

    _addErrorMessage(cleanMessage);
  }

  String _emptyResponseMessage(Map<String, dynamic> data) {
    final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
    final blockReason = promptFeedback?['blockReason']?.toString();
    if (blockReason != null && blockReason.isNotEmpty) {
      return 'Gemini blocked this message ($blockReason). Try asking in a different way.';
    }

    final candidates = data['candidates'] as List<dynamic>?;
    final firstCandidate = candidates?.isNotEmpty == true
        ? candidates!.first as Map<String, dynamic>
        : null;
    final finishReason = firstCandidate?['finishReason']?.toString();
    if (finishReason != null && finishReason.isNotEmpty) {
      return 'Gemini returned no text ($finishReason). Try again with a shorter question.';
    }

    return 'Gemini returned no response. Please try again.';
  }

  void _addErrorMessage(String text) {
    if (!mounted) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      );
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _conversationHistory.clear();

      _messages.add(
        ChatMessage(
          text: "Chat cleared! Ask me anything about local places 🗺️",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[600],
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Assistant',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Powered by AI',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Suggestion chips ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SuggestionChip(
                    label: '🍕 Cheap restaurants',
                    onTap: () {
                      _inputController.text = 'Best cheap restaurants nearby';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    label: '💎 Hidden gems',
                    onTap: () {
                      _inputController.text = 'Show me hidden gems locals love';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    label: '☕ Best cafes',
                    onTap: () {
                      _inputController.text = 'Best cafes with good vibes';
                      _sendMessage();
                    },
                  ),
                  _SuggestionChip(
                    label: '🌙 Nightlife',
                    onTap: () {
                      _inputController.text =
                          'What to do tonight for nightlife?';
                      _sendMessage();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Messages list ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }

                final msg = _messages[index];

                return _MessageBubble(
                  message: msg,
                  timeString: _formatTime(msg.timestamp),
                );
              },
            ),
          ),

          // ── Input bar ───────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputController,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask about local places…',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey[300] : Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _isLoading ? Colors.grey[500] : Colors.white,
                      size: 20,
                    ),
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

// ── Message bubble widget ─────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeString;

  const _MessageBubble({required this.message, required this.timeString});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[600],
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[600] : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeString,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[600],
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final value = (_controller.value - delay).abs();
                    final opacity = (1 - (value * 3).clamp(0.0, 1.0)).clamp(
                      0.3,
                      1.0,
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[400]!.withValues(alpha: opacity),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
