import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/user_role.dart';

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
  final List<Map<String, String>> _conversationHistory = [];

  bool _isLoading = false;

  // User context loaded from Firebase for personalization
  String _prefCategories = '';
  String _prefBudget = '';
  String _prefAtmosphere = '';
  String _prefArea = '';
  List<String> _realPlaceLines = [];

  // Pass with: flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Free-tier friendly model.
  // If this gives "model not found", try: gemini-2.0-flash
  static const String _modelName = 'gemini-2.0-flash-lite';

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
    _loadUserContext();
  }

  /// Fetches the user's saved preferences and a sample of real Firestore
  /// places so the AI system prompt is grounded in actual app data.
  Future<void> _loadUserContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final d = userDoc.data()!;
        _prefCategories =
            (d['preferences'] as List?)?.cast<String>().join(', ') ?? '';
        _prefBudget = (d['budgetPreference'] ?? '').toString();
        _prefAtmosphere = (d['atmospherePreference'] ?? '').toString();
        _prefArea = (d['areaPreference'] ?? '').toString();
      }

      final placesSnap = await FirebaseFirestore.instance
          .collection('places')
          .limit(20)
          .get();

      _realPlaceLines = placesSnap.docs.map((doc) {
        final d = doc.data();
        final name = (d['title'] ?? '').toString();
        if (name.isEmpty) return '';
        final parts = <String>[
          if ((d['category'] ?? '').toString().isNotEmpty)
            d['category'].toString(),
          if ((d['address'] ?? '').toString().isNotEmpty)
            d['address'].toString(),
          if ((d['budget'] ?? '').toString().isNotEmpty)
            'budget:${d['budget']}',
          if ((d['atmosphere'] ?? '').toString().isNotEmpty)
            'vibe:${d['atmosphere']}',
        ];
        return '"$name" — ${parts.join(', ')}';
      }).where((l) => l.isNotEmpty).toList();
    } catch (_) {
      // Silent fail — use generic prompt if Firebase is unreachable
    }
  }

  /// Builds the Gemini system prompt, injecting the user's Firebase
  /// preferences and real places from Firestore when available.
  String _buildSystemPrompt() {
    final buf = StringBuffer();
    buf.writeln(
      'You are LikeALocal\'s friendly travel assistant. '
      'Help users discover authentic local places, hidden gems, restaurants, '
      'cafes, and experiences — especially in Cairo, Egypt.',
    );

    final hasPrefs = _prefCategories.isNotEmpty ||
        _prefBudget.isNotEmpty ||
        _prefAtmosphere.isNotEmpty ||
        _prefArea.isNotEmpty;

    if (hasPrefs) {
      buf.writeln('\n== This user\'s preferences (personalise your answers) ==');
      if (_prefCategories.isNotEmpty) {
        buf.writeln('- Interests: $_prefCategories');
      }
      if (_prefBudget.isNotEmpty) buf.writeln('- Budget: $_prefBudget');
      if (_prefAtmosphere.isNotEmpty) {
        buf.writeln('- Preferred vibe: $_prefAtmosphere');
      }
      if (_prefArea.isNotEmpty) buf.writeln('- Preferred area: $_prefArea');
      buf.writeln(
        'Prioritise recommendations that match these preferences.',
      );
    }

    if (_realPlaceLines.isNotEmpty) {
      buf.writeln('\n== Real places listed in the LikeALocal app ==');
      for (final line in _realPlaceLines) {
        buf.writeln('• $line');
      }
      buf.writeln(
        'When relevant, recommend these specific places by name and mention '
        'they can be found inside the LikeALocal app.',
      );
    }

    buf.writeln(
      '\nKeep responses friendly, concise, and practical. '
      'Use bullet points for lists. Ask follow-up questions only when needed.',
    );
    return buf.toString();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();

    if (text.isEmpty || _isLoading) return;
    if (!await _canUseAiRequest()) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );

      _conversationHistory.add({'role': 'user', 'content': text});

      _isLoading = true;
    });

    _inputController.clear();
    _scrollToBottom();

    // If key is missing, use demo mode instead of breaking the app.
    if (_apiKey.trim().isEmpty) {
      _addBotMessage(
        '${_getFallbackReply(text)}\n\nNote: Demo mode is running because the Gemini API key is not added yet.',
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      _scrollToBottom();
      return;
    }

    try {
      // Keep only recent messages to reduce token usage on the free tier.
      final recentHistory = _conversationHistory.length > 2
          ? _conversationHistory.sublist(_conversationHistory.length - 2)
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
              {'text': _buildSystemPrompt()},
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
          'generationConfig': {'maxOutputTokens': 300, 'temperature': 0.7},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = _extractGeminiReply(data);

        if (reply.trim().isEmpty) {
          _addBotMessage(_emptyResponseMessage(data));
        } else {
          _addBotMessage(reply);
        }
      } else {
        _handleApiError(
          statusCode: response.statusCode,
          body: response.body,
          userMessage: text,
        );
      }
    } catch (_) {
      _addBotMessage(
        '${_getFallbackReply(text)}\n\nNote: Demo mode is running because the AI service could not be reached.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }

      _scrollToBottom();
    }
  }

  Future<bool> _canUseAiRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userRef.get();
    final role = UserRole.fromData(userDoc.data());
    if (role.limits.aiRequestsToday >= role.maxAiRequestsPerDay) {
      _addBotMessage(
        'You reached your ${role.subscriptionLabel} AI limit for today. Premium users get up to ${UserRole.regularFree().maxAiRequestsPerDay * 10} requests.',
      );
      return false;
    }
    await userRef.set({
      'limits': {'aiRequestsToday': FieldValue.increment(1)},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  String _extractGeminiReply(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) {
        return '';
      }

      final firstCandidate = candidates.first as Map<String, dynamic>;
      final content = firstCandidate['content'] as Map<String, dynamic>?;

      if (content == null) {
        return '';
      }

      final parts = content['parts'] as List<dynamic>?;

      if (parts == null || parts.isEmpty) {
        return '';
      }

      final firstPart = parts.first as Map<String, dynamic>;
      final text = firstPart['text'];

      return text?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _handleApiError({
    required int statusCode,
    required String body,
    required String userMessage,
  }) {
    String cleanMessage;

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final errorMessage = data['error']?['message']?.toString() ?? '';
      final lowerError = errorMessage.toLowerCase();

      if (statusCode == 429 || lowerError.contains('quota')) {
        cleanMessage =
            '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because the free Gemini limit was reached.';
      } else if (statusCode == 400) {
        cleanMessage =
            '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because the AI request format was rejected.';
      } else if (statusCode == 403) {
        cleanMessage =
            '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because Gemini access is blocked for this API key/project.';
      } else if (statusCode == 404) {
        cleanMessage =
            '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because the selected Gemini model was not found. Try gemini-2.0-flash.';
      } else {
        cleanMessage =
            '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because Gemini returned error $statusCode.';
      }
    } catch (_) {
      cleanMessage =
          '${_getFallbackReply(userMessage)}\n\nNote: Demo mode is running because Gemini returned an unexpected error.';
    }

    _addBotMessage(cleanMessage);
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

  String _getFallbackReply(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('cafe') ||
        message.contains('coffee') ||
        message.contains('قهوة') ||
        message.contains('كافيه')) {
      return '''
Here are some café ideas in Cairo:

• Zamalek: calm cafés with Nile views and cozy vibes
• Maadi: quiet cafés for studying, working, or chilling
• New Cairo: modern cafés, desserts, and group hangouts
• Downtown: old local cafés with authentic Egyptian vibes

Tip: For good vibes, go in the evening and check reviews before visiting.
''';
    }

    if (message.contains('restaurant') ||
        message.contains('food') ||
        message.contains('eat') ||
        message.contains('cheap') ||
        message.contains('مطعم') ||
        message.contains('اكل')) {
      return '''
Here are some local restaurant ideas:

• Cheap: koshary, shawarma, foul, taameya, and local grills
• Medium budget: Egyptian restaurants, pasta places, and casual dining
• Fancy: Nile-view restaurants, rooftop spots, or hotel restaurants

Best areas to search:
• Zamalek
• Maadi
• Downtown Cairo
• New Cairo
• Heliopolis

Tell me your area and budget, and I can suggest better options.
''';
    }

    if (message.contains('night') ||
        message.contains('nightlife') ||
        message.contains('tonight') ||
        message.contains('ليل') ||
        message.contains('خروج')) {
      return '''
For nightlife or going out tonight in Cairo:

• Zamalek: calm lounges, cafés, and Nile-side walks
• Downtown Cairo: local food, walking, and old-city vibes
• New Cairo: restaurants, desserts, and late-night cafés
• Maadi: cozy cafés and relaxed places with friends
• Nile Corniche: simple evening walk with a nice view

Safety tip: Go with friends, check opening hours, and avoid very empty areas late at night.
''';
    }

    if (message.contains('hidden') ||
        message.contains('gem') ||
        message.contains('local') ||
        message.contains('secret') ||
        message.contains('مكان جديد')) {
      return '''
Hidden gem ideas locals may enjoy:

• Small cafés in Maadi side streets
• Bookshops and old streets in Downtown
• Quiet Nile-view spots in Zamalek
• Local breakfast places in old Cairo areas
• Small dessert shops in Heliopolis or New Cairo

Tip: The best hidden gems are usually not the most famous places, so check recent reviews and photos.
''';
    }

    if (message.contains('budget') ||
        message.contains('money') ||
        message.contains('price') ||
        message.contains('رخيص') ||
        message.contains('سعر')) {
      return '''
Here is a simple budget guide:

• Low budget: koshary, foul, taameya, shawarma, local cafés
• Medium budget: casual restaurants, dessert spots, modern cafés
• Higher budget: rooftop restaurants, Nile-view places, hotel cafés

For a student-friendly outing, choose Downtown, Maadi, or local areas near you.
''';
    }

    if (message.contains('date') ||
        message.contains('romantic') ||
        message.contains('couple') ||
        message.contains('رومانسي')) {
      return '''
For a romantic outing:

• Zamalek: Nile-view cafés and calm restaurants
• Maadi: cozy quiet cafés and dinner spots
• New Cairo: modern restaurants and dessert places
• Nile Corniche: simple walk with a nice view

Choose a place that is quiet, not too crowded, and has good lighting.
''';
    }

    if (message.contains('family') ||
        message.contains('kids') ||
        message.contains('عائلة')) {
      return '''
For a family-friendly outing:

• New Cairo malls: restaurants, desserts, and safe walking areas
• Maadi cafés/restaurants: calmer family vibe
• Zamalek: lunch and Nile walk
• Parks or outdoor spaces during good weather

Look for places with parking, clean seating, and not-too-loud music.
''';
    }

    return '''
I can help you discover local places.

Try asking:
• Best cheap restaurants nearby
• Hidden gems locals love
• Best cafés with good vibes
• What to do tonight?
• Good places for families
• Romantic places in Cairo
''';
  }

  void _addBotMessage(String text) {
    if (!mounted) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      );

      _conversationHistory.add({'role': 'assistant', 'content': text});
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

  void _sendSuggestion(String text) {
    if (_isLoading) return;

    _inputController.text = text;
    _sendMessage();
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
                    onTap: () =>
                        _sendSuggestion('Best cheap restaurants nearby'),
                  ),
                  _SuggestionChip(
                    label: '💎 Hidden gems',
                    onTap: () =>
                        _sendSuggestion('Show me hidden gems locals love'),
                  ),
                  _SuggestionChip(
                    label: '☕ Best cafes',
                    onTap: () => _sendSuggestion('Best cafes with good vibes'),
                  ),
                  _SuggestionChip(
                    label: '🌙 Nightlife',
                    onTap: () =>
                        _sendSuggestion('What to do tonight for nightlife?'),
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
                      enabled: !_isLoading,
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'Assistant is typing...'
                            : 'Ask about local places…',
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
                  onTap: _isLoading ? null : _sendMessage,
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
