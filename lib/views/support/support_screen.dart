import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/support_provider.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/heartbeat_loader.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────

class SupportTicket {
  final int id;
  final String title;
  final String desc;
  String status; // 'pending' | 'accepted' | 'rejected'
  final String date;
  String? feedback;
  File? attachment;
  String? attachmentUrl;

  SupportTicket({
    required this.id,
    required this.title,
    required this.desc,
    required this.status,
    required this.date,
    this.feedback,
    this.attachment,
    this.attachmentUrl,
  });
}

// ─── Support Screen ──────────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _isLoading = true;
  List<SupportTicket> _tickets = [];

  // Controllers for Add/Edit Ticket Dialog
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  File? _selectedAttachment;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTickets();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final supportProv = context.read<SupportProvider>();
    await supportProv.fetchTickets();
    if (mounted) {
      setState(() {
        _tickets = supportProv.tickets.map((t) {
          return SupportTicket(
            id: t['id'] is int ? t['id'] : int.parse(t['id'].toString()),
            title: t['title'] ?? '',
            desc: t['desc'] ?? '',
            status: t['status'] ?? 'pending',
            date: t['date'] ?? '',
            feedback: t['feedback'],
            attachmentUrl: t['attachment_path'],
          );
        }).toList();
        _isLoading = false;
      });
    }
  }

  bool get _hasPendingTicket => _tickets.any((ticket) => ticket.status == 'pending');

  Future<void> _pickFile() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedAttachment = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة')),
      );
    }
  }

  void _submitTicket({SupportTicket? existingTicket}) async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء العنوان ووصف المشكلة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close sheet/modal
    setState(() => _isLoading = true);

    final supportProv = context.read<SupportProvider>();
    final success = await supportProv.createTicket(
      title: title,
      description: desc,
      attachmentPath: _selectedAttachment?.path,
      editId: existingTicket?.id,
    );

    if (success && mounted) {
      _titleController.clear();
      _descController.clear();
      _selectedAttachment = null;
      await _loadTickets();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingTicket != null ? 'تم تعديل الطلب وإعادة إرساله بنجاح' : 'تم إرسال طلب الدعم بنجاح وفتح التذكرة',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.accent,
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(supportProv.errorMessage ?? 'حدث خطأ أثناء معالجة الطلب', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showTicketModal({SupportTicket? ticketToEdit}) {
    if (ticketToEdit != null) {
      _titleController.text = ticketToEdit.title;
      _descController.text = ticketToEdit.desc;
      _selectedAttachment = ticketToEdit.attachment;
    } else {
      _titleController.clear();
      _descController.clear();
      _selectedAttachment = null;
    }

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
                Text(
                  ticketToEdit != null ? 'تعديل طلب الدعم المرفوض' : 'فتح تذكرة دعم جديدة',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                  ),
                ),
                if (ticketToEdit != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfff8e1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFb78103), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أنت تقوم بتعديل طلب مرفوض بناءً على ملاحظات الإدارة.',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFFb78103), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'عنوان المشكلة',
                  hint: 'مثال: مشكلة في تسجيل المواد',
                  controller: _titleController,
                ),
                const Text(
                  'تفاصيل المشكلة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'اشرح لنا المشكلة بالتفصيل...',
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
                const SizedBox(height: 16),
                const Text(
                  'إرفاق مستند أو صورة (اختياري)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await _pickFile();
                    setModalState(() {});
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedAttachment == null ? Colors.grey.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedAttachment == null ? Colors.grey.shade300 : AppColors.primary,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedAttachment == null ? Icons.attach_file : Icons.check_circle,
                          color: _selectedAttachment == null ? Colors.grey : AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedAttachment == null ? 'اختر ملف إثبات للمشكلة' : 'تم اختيار المرفق بنجاح',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: _selectedAttachment == null ? Colors.black54 : AppColors.primary,
                              fontWeight: _selectedAttachment == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_selectedAttachment != null)
                          const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'إرسال الطلب',
                        onPressed: () => _submitTicket(existingTicket: ticketToEdit),
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
        child: Column(
          children: [
            _buildHeader(),
            _buildStickyNotice(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeartbeatLoader(),
                          SizedBox(height: 16),
                          Text(
                            'جاري تحميل التذاكر الفنية...',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _tickets.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _hasPendingTicket ? _showPendingAlert : _showTicketModal,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'طلب جديد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
          const FaIcon(FontAwesomeIcons.headset, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text(
            'الدعم الفني والشكاوى',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTickets,
          ),
        ],
      ),
    );
  }

  // ── Notice Box ──────────────────────────────────────────────────────────────
  Widget _buildStickyNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: AppColors.primary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا يمكنك فتح تذكرة جديدة إذا كان لديك طلب حالي قيد المراجعة.',
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'Cairo',
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.ticket,
            size: 60,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد تذاكر دعم فني سابقة',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اضغط على زر "طلب جديد" بالأسفل لطلب الدعم.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // ── Ticket Card ─────────────────────────────────────────────────────────────
  Widget _buildTicketCard(SupportTicket ticket) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (ticket.status) {
      case 'accepted':
        statusColor = const Color(0xFF059669);
        statusText = 'مقبول';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = const Color(0xFFdc2626);
        statusText = 'مرفوض';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFFd97706);
        statusText = 'قيد المراجعة';
        statusIcon = Icons.hourglass_empty;
    }

    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Date & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تاريخ التذكرة: ${ticket.date}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'Cairo',
                ),
              ),
              StatusBadge(
                text: statusText,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                textColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            ticket.title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          // Description
          Text(
            ticket.desc,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              fontFamily: 'Cairo',
              color: Colors.black87,
            ),
          ),
          if (ticket.attachmentUrl != null && ticket.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // Show view attachment popup
                showDialog(
                  context: context,
                  builder: (c) => Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBar(
                          title: const Text('المرفق المرفوع', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          leading: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(c),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(ticket.attachmentUrl!, fit: BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.image, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'عرض المرفق المرفوع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Feedback / Response Section
          if (ticket.feedback != null && ticket.feedback!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        ticket.status == 'accepted' ? 'رد الدعم الفني:' : 'سبب الرفض:',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ticket.feedback!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Edit Button for Rejected Tickets
          if (ticket.status == 'rejected') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _showTicketModal(ticketToEdit: ticket),
                icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                label: const Text(
                  'تعديل وإعادة إرسال',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pending Ticket Dialog ───────────────────────────────────────────────────
  void _showPendingAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'لا يمكن فتح طلب جديد',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'لديك تذكرة دعم فني قيد المراجعة حالياً. يرجى الانتظار حتى يتم الرد عليها وإغلاقها قبل إرسال طلب جديد.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
