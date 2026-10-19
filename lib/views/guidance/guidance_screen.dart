import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/guidance_provider.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/heartbeat_loader.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class AffairsMessage {
  final String text;
  final String senderType; // 'student' | 'admin'
  final String time;
  final File? attachment;
  final String? attachmentUrl;
  final String? attachmentType; // 'audio' | 'image' | 'document'
  final String? mockAttachmentName;

  AffairsMessage({
    required this.text,
    required this.senderType,
    required this.time,
    this.attachment,
    this.attachmentUrl,
    this.attachmentType,
    this.mockAttachmentName,
  });
}

class AffairsRequest {
  final int id;
  final String title;
  final String type; // 'complaint' | 'suggestion' | 'care' | 'other'
  final String status; // 'مفتوح' | 'قيد المتابعة' | 'مغلق'
  final String lastActivity;
  final List<AffairsMessage> messages;

  AffairsRequest({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.lastActivity,
    required this.messages,
  });
}

// ─── Guidance Screen ──────────────────────────────────────────────────────────

class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({super.key});

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  bool _isLoading = true;
  List<AffairsRequest> _requests = [];
  AffairsRequest? _activeRequest; // Currently open chat request

  // Dialog and chat controllers
  final TextEditingController _newTitleController = TextEditingController();
  final TextEditingController _newDescController = TextEditingController();
  String _selectedType = 'complaint';

  final TextEditingController _replyController = TextEditingController();
  File? _replyAttachment;
  String? _replyAttachmentType; // 'image' | 'audio' | 'document'
  String? _mockAttachmentName;

  // Recording Simulator state
  bool _isRecording = false;
  int _recordSeconds = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    _newDescController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final guidanceProv = context.read<GuidanceProvider>();
    await guidanceProv.fetchRequests();
    
    if (mounted) {
      setState(() {
        _requests = guidanceProv.requests.map((r) {
          final typeVal = r['request_type'] ?? 'complaint';
          return AffairsRequest(
            id: r['id'] is int ? r['id'] : int.parse(r['id'].toString()),
            title: r['title'] ?? '',
            type: typeVal,
            status: r['status'] ?? 'مفتوح',
            lastActivity: r['created_at_str'] ?? r['last_activity_at'] ?? 'الآن',
            messages: [],
          );
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _openRequestChat(AffairsRequest req) async {
    setState(() => _isLoading = true);
    final guidanceProv = context.read<GuidanceProvider>();
    await guidanceProv.fetchChatHistory(req.id);
    
    if (mounted) {
      setState(() {
        _activeRequest = AffairsRequest(
          id: req.id,
          title: req.title,
          type: req.type,
          status: guidanceProv.activeChatStatus,
          lastActivity: req.lastActivity,
          messages: guidanceProv.chatMessages.map((m) {
            return AffairsMessage(
              text: m['message_text'] ?? '',
              senderType: m['sender_type'] ?? 'student',
              time: m['time_str'] ?? '',
              attachmentUrl: m['attachment_path'],
              attachmentType: m['attachment_type'],
              mockAttachmentName: m['attachment_path'] != null ? m['attachment_path'].toString().split('/').last : null,
            );
          }).toList(),
        );
        _isLoading = false;
      });
    }
  }

  void _startVoiceRecording() async {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    () async {
      while (_isRecording) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isRecording || !mounted) break;
        setState(() {
          _recordSeconds++;
        });
      }
    }();
  }

  void _stopVoiceRecording() {
    setState(() {
      _isRecording = false;
      _replyAttachmentType = 'audio';
      _mockAttachmentName = 'تسجيل_صوتي_$_recordSeconds' 'ث.webm';
    });
  }

  Future<void> _pickAttachment(String type) async {
    try {
      if (type == 'image') {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
        );
        if (pickedFile != null) {
          setState(() {
            _replyAttachment = File(pickedFile.path);
            _replyAttachmentType = 'image';
            _mockAttachmentName = pickedFile.name;
          });
        }
      } else {
        // Mock file attachment
        setState(() {
          _replyAttachment = File('mock_doc.pdf');
          _replyAttachmentType = 'document';
          _mockAttachmentName = 'مستند_إثبات_حالة.pdf';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء اختيار الملف')),
      );
    }
  }

  void _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _replyAttachment == null) return;

    setState(() => _isLoading = true);

    final guidanceProv = context.read<GuidanceProvider>();
    final success = await guidanceProv.sendChatMessage(
      requestId: _activeRequest!.id,
      message: text,
      attachmentPath: _replyAttachment?.path,
    );

    if (success && mounted) {
      _replyController.clear();
      _replyAttachment = null;
      _replyAttachmentType = null;
      _mockAttachmentName = null;

      // تحديث المحادثة
      setState(() {
        _activeRequest = AffairsRequest(
          id: _activeRequest!.id,
          title: _activeRequest!.title,
          type: _activeRequest!.type,
          status: guidanceProv.activeChatStatus,
          lastActivity: 'الآن',
          messages: guidanceProv.chatMessages.map((m) {
            return AffairsMessage(
              text: m['message_text'] ?? '',
              senderType: m['sender_type'] ?? 'student',
              time: m['time_str'] ?? '',
              attachmentUrl: m['attachment_path'],
              attachmentType: m['attachment_type'],
              mockAttachmentName: m['attachment_path'] != null ? m['attachment_path'].toString().split('/').last : null,
            );
          }).toList(),
        );
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(guidanceProv.errorMessage ?? 'فشل في إرسال الرسالة', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _createNewRequest() async {
    final title = _newTitleController.text.trim();
    final desc = _newDescController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع حقول الطلب', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close Bottom Sheet modal
    setState(() => _isLoading = true);

    final guidanceProv = context.read<GuidanceProvider>();
    final newId = await guidanceProv.createRequest(
      title: title,
      type: _selectedType,
      description: desc,
    );

    if (newId != null && mounted) {
      _newTitleController.clear();
      _newDescController.clear();
      
      // فتح المحادثة للطلب الجديد مباشرة
      final req = AffairsRequest(
        id: newId,
        title: title,
        type: _selectedType,
        status: 'جديد',
        lastActivity: 'الآن',
        messages: [],
      );
      _openRequestChat(req);
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(guidanceProv.errorMessage ?? 'فشل في فتح طلب الرعاية والتوجيه', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showNewRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'فتح طلب رعاية وتوجيه جديد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'تصنيف الطلب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'complaint', child: Text('شكوى اجتماعية / أكاديمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                    DropdownMenuItem(value: 'care', child: Text('رعاية اجتماعية وبحث حالة للرسوم', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                    DropdownMenuItem(value: 'suggestion', child: Text('مقترح للتطوير الأكاديمي', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                    DropdownMenuItem(value: 'other', child: Text('أخرى / استفسار عام', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        _selectedType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'عنوان الطلب أو الموضوع',
                  hint: 'مثال: طلب رعاية قسط الفصل الثالث',
                  controller: _newTitleController,
                ),
                const Text(
                  'تفاصيل ومبررات الطلب',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _newDescController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل حالتك أو مبررات طلبك هنا بالتفصيل الممكن...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFe1e8ed), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFe1e8ed), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'تأكيد الإرسال',
                        onPressed: _createNewRequest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _activeRequest == null ? _buildListView() : _buildChatView(),
      ),
    );
  }

  // ─── List View Layout ──────────────────────────────────────────────────────

  Widget _buildListView() {
    return Column(
      children: [
        _buildListHeader(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeartbeatLoader(),
                      SizedBox(height: 16),
                      Text(
                        'جاري جلب سجل الرعاية والتوجيه...',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildRequestsList(),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const FaIcon(FontAwesomeIcons.handshakeAngle, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرعاية والتوجيه',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                'شؤون الطلاب والشكاوى الاجتماعية',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _showNewRequestDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              '+ طلب جديد',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diversity_3_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'لا توجد طلبات أو مقترحات حالية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(AffairsRequest req) {
    Color typeBg;
    Color typeText;
    String typeLabel;

    if (req.type == 'complaint') {
      typeBg = const Color(0xFFffebee);
      typeText = const Color(0xFFc62828);
      typeLabel = 'شكوى';
    } else if (req.type == 'care') {
      typeBg = const Color(0xFFe8f5e9);
      typeText = const Color(0xFF2e7d32);
      typeLabel = 'رعاية';
    } else if (req.type == 'suggestion') {
      typeBg = const Color(0xFFe3f2fd);
      typeText = const Color(0xFF1565c0);
      typeLabel = 'مقترح';
    } else {
      typeBg = const Color(0xFFf3e5f5);
      typeText = const Color(0xFF6a1b9a);
      typeLabel = 'أخرى';
    }

    return CustomCard(
      marginBottom: 14,
      child: InkWell(
        onTap: () => _openRequestChat(req),
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                  text: typeLabel,
                  backgroundColor: typeBg,
                  textColor: typeText,
                ),
                const SizedBox(width: 8),
                Text(
                  '#${req.id}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  req.status,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: req.status == 'مغلق' ? Colors.grey : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              req.title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تاريخ الطلب: ${req.lastActivity}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                ),
                const Row(
                  children: [
                    Text(
                      'فتح المحادثة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chat View Layout ──────────────────────────────────────────────────────

  Widget _buildChatView() {
    final req = _activeRequest!;
    return Column(
      children: [
        _buildChatHeader(req),
        Expanded(
          child: Container(
            color: const Color(0xFFf9fafb),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: req.messages.length,
              itemBuilder: (context, index) {
                final msg = req.messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
        ),
        _buildAttachmentPreview(),
        _buildChatInputArea(),
      ],
    );
  }

  Widget _buildChatHeader(AffairsRequest req) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _activeRequest = null;
              });
              _loadRequests(); // Refresh main list
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'طلب #${req.id} - ${req.status}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            text: req.type == 'complaint'
                ? 'شكوى'
                : req.type == 'care'
                    ? 'رعاية'
                    : req.type == 'suggestion'
                        ? 'مقترح'
                        : 'أخرى',
            backgroundColor: req.type == 'complaint'
                ? const Color(0xFFffebee)
                : const Color(0xFFe8f5e9),
            textColor: req.type == 'complaint'
                ? const Color(0xFFc62828)
                : const Color(0xFF2e7d32),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AffairsMessage msg) {
    final isStudent = msg.senderType == 'student';
    final AlignmentGeometry alignment = isStudent ? Alignment.centerRight : Alignment.centerLeft;
    final Color bubbleColor = isStudent ? const Color(0xFFe3f2fd) : const Color(0xFFf3f4f6);
    final Color textColor = isStudent ? const Color(0xFF0d47a1) : const Color(0xFF374151);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isStudent ? 16 : 2),
            bottomRight: Radius.circular(isStudent ? 2 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.text.isNotEmpty) ...[
              Text(
                msg.text,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty) ...[
              _buildAttachmentBubbleContent(msg),
              const SizedBox(height: 6),
            ],
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                msg.time,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentBubbleContent(AffairsMessage msg) {
    if (msg.attachmentType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: msg.attachmentUrl != null
            ? Image.network(msg.attachmentUrl!, fit: BoxFit.cover)
            : Container(
                constraints: const BoxConstraints(maxHeight: 180),
                color: Colors.grey.shade200,
                child: const AspectRatio(
                  aspectRatio: 1.5,
                  child: Icon(Icons.image, size: 45, color: Colors.grey),
                ),
              ),
      );
    } else if (msg.attachmentType == 'audio') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.primary, size: 20),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
            const Icon(Icons.volume_up, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              msg.mockAttachmentName ?? 'تسجيل صوتي',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      // Document
      return InkWell(
        onTap: () {
          // Open URL in default browser
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg.mockAttachmentName ?? 'مستند مرفق',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAttachmentPreview() {
    if (_replyAttachmentType == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFeceff1))),
      ),
      child: Row(
        children: [
          Icon(
            _replyAttachmentType == 'image'
                ? Icons.image
                : _replyAttachmentType == 'audio'
                    ? Icons.mic
                    : Icons.insert_drive_file,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _mockAttachmentName ?? 'ملف مرفق',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () {
              setState(() {
                _replyAttachment = null;
                _replyAttachmentType = null;
                _mockAttachmentName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatInputArea() {
    // Disabled if request is closed
    final isClosed = _activeRequest!.status == 'مغلق';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
        ],
      ),
      child: isClosed
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const Text(
                'هذه المحادثة مغلقة من قبل الإدارة الفنية',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            )
          : Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                  onPressed: () => _pickAttachment('image'),
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.primary),
                  onPressed: () => _pickAttachment('document'),
                ),
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'جاري تسجيل الصوت...' : 'اكتب رسالتك هنا...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFf1f3f4),
                    ),
                    enabled: !_isRecording,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onLongPress: _startVoiceRecording,
                  onLongPressEnd: (_) => _stopVoiceRecording(),
                  child: IconButton(
                    icon: Icon(
                      _isRecording ? Icons.mic : Icons.send,
                      color: _isRecording ? Colors.red : AppColors.primary,
                    ),
                    onPressed: _isRecording ? null : _sendReply,
                  ),
                ),
              ],
            ),
    );
  }
}
