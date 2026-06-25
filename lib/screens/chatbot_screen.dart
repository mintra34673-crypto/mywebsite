import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

/// =====================================================
/// ⚠️ ใส่ Groq API Key ของคุณตรงนี้
/// (ขอฟรีได้ที่ https://console.groq.com/keys — ไม่ต้องผูกบัตร)
/// =====================================================
const String groqApiKey = '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';
const String groqModel = 'llama-3.3-70b-versatile';
const String groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

/// System prompt: บังคับให้ EcoBot ตอบเฉพาะเรื่องการคัดแยกขยะ/รีไซเคิล และวิธีใช้งานแอป BinSort
const String systemInstruction = '''
คุณคือ "EcoBot" ผู้ช่วย AI ของแอป CleanCM (BinSort)
มีหน้าที่ให้ความรู้เกี่ยวกับการคัดแยกขยะและการรีไซเคิลสำหรับบริบทประเทศไทย
โดยใช้สีถังขยะมาตรฐาน 4 สี ได้แก่
- สีน้ำเงิน = ขยะรีไซเคิล (พลาสติก แก้ว กระดาษ โลหะ)
- สีเขียว = ขยะอินทรีย์ (เศษอาหาร เศษผัก ใบไม้)
- สีแดง = ขยะอันตราย (ถ่านไฟฉาย หลอดไฟ สารเคมี)
- สีน้ำเงินเข้ม/ดำ = ขยะทั่วไป

นอกจากนี้คุณยังต้องช่วยตอบคำถามเกี่ยวกับวิธีใช้งานฟีเจอร์ต่าง ๆ ของแอป BinSort ได้ด้วย ดังนี้:

1. หน้าแผนที่ตำแหน่งถังขยะ: แสดงแผนที่พร้อมปักหมุดตำแหน่งถังขยะประเภทต่าง ๆ ใกล้เคียง มีระบบกรองเปิด-ปิดหมุดตามประเภทขยะ และมีปุ่ม "+" สำหรับเพิ่มจุดถังขยะใหม่

2. หน้ารายละเอียดถังขยะ: เด้งขึ้นเมื่อกดเลือกหมุดบนแผนที่ แสดงชื่อสถานที่ ประเภทถัง ระยะทาง ผู้แจ้งข้อมูล วันที่อัปเดตล่าสุด และปุ่มนำทางไปยังถังขยะจุดนั้น

3. หน้าเพิ่มจุดถังขยะใหม่: ผู้ใช้กรอกชื่อสถานที่ เลือกประเภทขยะ และถ่ายรูปประกอบ เมื่อส่งสำเร็จจะได้รับคะแนนสะสมทันที 1 แต้ม

4. ระบบสแกนขยะด้วย AI: ใช้กล้องสแกนวัตถุเพื่อจำแนกประเภทขยะ หากสแกนภายในรัศมี 1 เมตรจากพิกัดถังขยะที่ลงทะเบียนไว้ จะได้คะแนนสะสมทันที แต่ถ้าสแกนนอกรัศมีจะไม่ได้คะแนน แม้ไม่ได้คะแนนก็ยังใช้ดูคำแนะนำการทิ้งขยะได้ตามปกติทุกที่ทุกเวลา

5. หน้ารางวัล: นำคะแนนสะสมมาแลกของรางวัลได้ 3 หมวดหมู่ คือ อาหาร ผลิตภัณฑ์ Eco และกิจกรรม แสดงคะแนนที่ต้องใช้และจำนวนสิทธิ์คงเหลือของแต่ละรายการ

6. หน้าคูปองรางวัล: แสดงตั๋วอิเล็กทรอนิกส์หลังแลกของรางวัลสำเร็จ มีรายละเอียดรางวัล รหัสคูปอง วันหมดอายุ และขั้นตอนการใช้คูปอง 4 ขั้นตอน

7. หน้ากิจกรรม/ประวัติ: แสดงประวัติการคัดแยกขยะย้อนหลัง ระบุชื่อขยะ วันที่ สถานที่ และคะแนนที่ได้รับแต่ละครั้ง สลับดูระหว่างประวัติการสแกนและหน้าแลกรางวัลได้ในหน้าเดียวกัน

กติกาการตอบ:
1. ขึ้นต้นด้วยคำทักทายสุภาพเมื่อเริ่มบทสนทนาเท่านั้น ไม่ต้องทักทายซ้ำทุกครั้ง
2. ตอบเป็นภาษาไทย กระชับ เข้าใจง่าย เป็นมิตร เหมาะกับผู้ใช้ทุกวัย
3. ตอบเฉพาะเรื่องขยะ การคัดแยก การรีไซเคิล สิ่งแวดล้อม และการใช้งานแอป BinSort เท่านั้น
4. ถ้าผู้ใช้ถามนอกเรื่อง ให้ตอบสุภาพว่าตอบได้เฉพาะเรื่องขยะ สิ่งแวดล้อม และการใช้งานแอป BinSort
5. ความยาวคำตอบไม่เกิน 3-4 ประโยค เพราะคำตอบจะถูกอ่านออกเสียงด้วย เลี่ยงการใส่สัญลักษณ์พิเศษเยอะเกินไป
''';

/// คำถามสำเร็จรูปยอดนิยมที่แสดงเป็นชิปด้านล่างหน้าจอ
const List<String> quickReplyQuestions = [
  'ขวดพลาสติกทิ้งถังไหน?',
  'แยกขยะอินทรีย์ยังไง?',
  'ขอรับคะแนนยังไงบ้าง?',
  'หลอดไฟทิ้งถังสีอะไร?',
  'กระดาษเปื้อนทิ้งถังไหน?',
  'แลกของรางวัลยังไง?',
];

class ChatMessage {
  final String role; // 'user' หรือ 'bot'
  final String text;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.text, required this.timestamp});

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        role: map['role'] ?? 'bot',
        text: map['text'] ?? '',
        timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const Color primaryGreen = Color(0xFF4CAF7D);
  static const Color darkGreen = Color(0xFF2E7D5B);
  static const Color userBubbleColor = Color(0xFFE9A96D);
  static const Color botBubbleColor = Color(0xFFFFFFFF);
  static const Color screenBg = Color(0xFFF4F1EC);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;
  bool _autoSpeak = true; // อ่านคำตอบ EcoBot อัตโนมัติ
  bool _speechAvailable = false;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _loadHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tts.stop().catchError((_) {});
    _speech.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('th-TH');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  /// โหลดประวัติแชทจาก Firestore (เรียงด้วย client-side แทน orderBy)
  Future<void> _loadHistory() async {
    if (_userId == null) {
      _addGreetingIfEmpty();
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('chat_history')
        .get();

    final loaded =
        snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
    loaded.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    setState(() {
      _messages.clear();
      _messages.addAll(loaded);
    });
    _addGreetingIfEmpty();
    _scrollToBottom();
  }

  void _addGreetingIfEmpty() {
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'bot',
          text:
              'สวัสดีครับ 👋 ผมชื่อ EcoBot\nถามเรื่องการจัดการขยะได้เลยครับ\n• ขวดพลาสติกทิ้งถังไหน?\n• แยกขยะยังไง?',
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _saveMessageToHistory(ChatMessage message) async {
    if (_userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('chat_history')
        .add(message.toMap());
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างประวัติแชท'),
        content: const Text('ต้องการลบประวัติการสนทนาทั้งหมดหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    if (_userId != null) {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('chat_history');
      final snapshot = await col.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
    setState(() => _messages.clear());
    _addGreetingIfEmpty();
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

  /// เรียก Groq API (รูปแบบ OpenAI-compatible) พร้อมส่งบริบทบทสนทนาก่อนหน้า
  Future<String> _askGroq(String userText) async {
    final history = _messages.takeLast(10).map((m) {
      return {
        'role': m.role == 'user' ? 'user' : 'assistant',
        'content': m.text,
      };
    }).toList();

    final body = {
      'model': groqModel,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        ...history,
        {'role': 'user', 'content': userText},
      ],
      'temperature': 0.6,
      'max_tokens': 300,
    };

    final response = await http.post(
      Uri.parse(groqEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final text = data['choices']?[0]?['message']?['content'];
    return (text ?? 'ขออภัยครับ ไม่สามารถตอบคำถามนี้ได้ในขณะนี้').toString().trim();
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage =
        ChatMessage(role: 'user', text: text, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();
    await _saveMessageToHistory(userMessage);

    try {
      final replyText = await _askGroq(text);
      final botMessage =
          ChatMessage(role: 'bot', text: replyText, timestamp: DateTime.now());
      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
      });
      _scrollToBottom();
      await _saveMessageToHistory(botMessage);
      if (_autoSpeak) _speak(replyText);
    } catch (e) {
      // ignore: avoid_print
      print('EcoBot Groq error: $e');
      final errorMessage = ChatMessage(
        role: 'bot',
        text: 'เกิดข้อผิดพลาดในการเชื่อมต่อ EcoBot กรุณาลองใหม่อีกครั้งครับ',
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
    } catch (_) {
      // flutter_tts บน Flutter Web บางเวอร์ชันไม่รองรับ stop() ก่อน speak()
    }
    try {
      await _tts.speak(text);
    } catch (_) {
      // เผื่อกรณี TTS ใช้งานไม่ได้บนอุปกรณ์/เบราว์เซอร์นี้
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('อุปกรณ์นี้ไม่รองรับการพูด หรือยังไม่อนุญาตไมโครโฟน')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: 'th_TH',
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _isListening = false;
          _sendMessage(result.recognizedWords.trim());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screenBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingBubble();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryGreen,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: primaryGreen, size: 22),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EcoBot',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              Text('Powered by Groq AI',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
              _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: Colors.white),
          tooltip: 'อ่านคำตอบอัตโนมัติ',
          onPressed: () => setState(() => _autoSpeak = !_autoSpeak),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          tooltip: 'ล้างประวัติแชท',
          onPressed: _clearHistory,
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? userBubbleColor : botBubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
                fontSize: 14.5,
                color: isUser ? Colors.white : Colors.black87,
                height: 1.4),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey),
              ),
              if (!isUser) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _speak(message.text),
                  child: const Icon(Icons.volume_up_rounded,
                      size: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: botBubbleColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// แถบคำถามสำเร็จรูป (quick reply chips) เลื่อนแนวนอน
  Widget _buildQuickReplies() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: quickReplyQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final question = quickReplyQuestions[index];
          return GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(question),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryGreen.withOpacity(0.5)),
              ),
              alignment: Alignment.center,
              child: Text(
                question,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: darkGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isListening
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFDFF3E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isListening ? Colors.red[800] : primaryGreen,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText:
                      _isListening ? 'กำลังฟัง...' : 'ถามเรื่องการแยกขยะ...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  color: userBubbleColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
