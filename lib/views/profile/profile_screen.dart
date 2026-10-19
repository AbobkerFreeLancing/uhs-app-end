import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/heartbeat_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  /// true = بيانات مكتملة (وضع القراءة فقط)
  /// false = بيانات ناقصة (وضع التعديل)
  bool _isComplete = false;

  // Form Controllers
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentAddressController = TextEditingController();
  final TextEditingController _permanentAddressController = TextEditingController();

  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController();
  final TextEditingController _guardianRelationController = TextEditingController();
  final TextEditingController _guardianJobController = TextEditingController();

  final TextEditingController _certDateController = TextEditingController();
  final TextEditingController _prevUniController = TextEditingController();
  final TextEditingController _prevAdmDateController = TextEditingController();

  // Security Form Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _selectedGender = 'M';
  String _selectedCertType = 'سودانية';
  bool _attendedPrevUni = false;

  // File Paths — الصور الثلاثة المطلوبة
  File? _avatarFile;
  File? _certFile;
  File? _idFile;

  // مسارات الصور الموجودة مسبقاً على الخادم
  String? _existingAvatarUrl;
  String? _existingCertUrl;
  String? _existingIdUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    _phoneController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianRelationController.dispose();
    _guardianJobController.dispose();
    _certDateController.dispose();
    _prevUniController.dispose();
    _prevAdmDateController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final profileProv = context.read<ProfileProvider>();
    final authProv = context.read<AuthProvider>();

    await profileProv.fetchProfile();

    if (mounted && profileProv.profileData != null) {
      final p = profileProv.profileData!;
      setState(() {
        _isLoading = false;
        _isComplete = !authProv.needsProfileCompletion;

        _birthDateController.text = p['birth_date'] ?? '';
        _phoneController.text = p['student_phone'] ?? '';
        _currentAddressController.text = p['current_address'] ?? '';
        _permanentAddressController.text = p['permanent_address'] ?? '';

        _guardianNameController.text = p['guardian_name'] ?? '';
        _guardianPhoneController.text = p['guardian_phone'] ?? '';
        _guardianRelationController.text = p['guardian_relation'] ?? '';
        _guardianJobController.text = p['guardian_job'] ?? '';

        _certDateController.text = p['certificate_date'] != null && p['certificate_date'].toString().length >= 7
            ? p['certificate_date'].toString().substring(0, 7)
            : '';
        _prevUniController.text = p['previous_university'] ?? '';
        _prevAdmDateController.text = p['previous_admission_date'] ?? '';

        _emailController.text = p['email'] ?? '';
        _selectedGender = p['gender'] ?? 'M';
        _selectedCertType = p['certificate_type'] ?? 'سودانية';
        _attendedPrevUni = p['previous_university'] != null && p['previous_university'].toString().isNotEmpty;

        // مسارات الصور المرفوعة مسبقاً
        _existingAvatarUrl = p['photo_path'];
        _existingCertUrl = p['cert_photo_path'];
        _existingIdUrl = p['id_photo_path'];
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _isComplete = !authProv.needsProfileCompletion;
        _emailController.text = authProv.studentId ?? '';
      });
    }
  }

  // ── التحقق من اكتمال البيانات المطلوبة قبل الحفظ ─────────────────────────

  /// هل الحقول النصية الأساسية مكتملة؟
  bool get _areFieldsComplete {
    return _birthDateController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _currentAddressController.text.trim().isNotEmpty &&
        _permanentAddressController.text.trim().isNotEmpty &&
        _guardianNameController.text.trim().isNotEmpty &&
        _guardianPhoneController.text.trim().isNotEmpty &&
        _guardianRelationController.text.trim().isNotEmpty &&
        _guardianJobController.text.trim().isNotEmpty &&
        _certDateController.text.trim().isNotEmpty;
  }

  /// هل الصور الثلاث موجودة (جديدة أو مرفوعة مسبقاً)؟
  bool get _hasAvatar => _avatarFile != null || (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty);
  bool get _hasCert => _certFile != null || (_existingCertUrl != null && _existingCertUrl!.isNotEmpty);
  bool get _hasId => _idFile != null || (_existingIdUrl != null && _existingIdUrl!.isNotEmpty);
  bool get _areAllPhotosPresent => _hasAvatar && _hasCert && _hasId;

  /// هل يُسمح بالحفظ؟
  bool get _canSave => _areFieldsComplete && _areAllPhotosPresent;

  // ── قائمة العناصر الناقصة لإرشاد الطالب ───────────────────────────────────
  List<String> get _missingItems {
    final List<String> missing = [];
    if (_birthDateController.text.trim().isEmpty) missing.add('تاريخ الميلاد');
    if (_phoneController.text.trim().isEmpty) missing.add('رقم الهاتف');
    if (_currentAddressController.text.trim().isEmpty) missing.add('السكن الحالي');
    if (_permanentAddressController.text.trim().isEmpty) missing.add('السكن الأصلي');
    if (_guardianNameController.text.trim().isEmpty) missing.add('اسم ولي الأمر');
    if (_guardianPhoneController.text.trim().isEmpty) missing.add('هاتف ولي الأمر');
    if (_guardianRelationController.text.trim().isEmpty) missing.add('صلة القرابة');
    if (_guardianJobController.text.trim().isEmpty) missing.add('وظيفة ولي الأمر');
    if (_certDateController.text.trim().isEmpty) missing.add('تاريخ الشهادة');
    if (!_hasAvatar) missing.add('الصورة الشخصية');
    if (!_hasCert) missing.add('صورة الشهادة');
    if (!_hasId) missing.add('صورة إثبات الهوية');
    return missing;
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (type == 'avatar') _avatarFile = File(pickedFile.path);
          if (type == 'cert') _certFile = File(pickedFile.path);
          if (type == 'id') _idFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة')),
      );
    }
  }

  void _saveProfile() async {
    // تحقق نهائي قبل الإرسال
    if (!_canSave) {
      _showMissingDataDialog();
      return;
    }

    setState(() => _isLoading = true);

    final fields = {
      'birth_date': _birthDateController.text,
      'student_phone': _phoneController.text,
      'gender': _selectedGender,
      'current_address': _currentAddressController.text,
      'permanent_address': _permanentAddressController.text,
      'guardian_name': _guardianNameController.text,
      'guardian_phone': _guardianPhoneController.text,
      'guardian_relation': _guardianRelationController.text,
      'guardian_job': _guardianJobController.text,
      'certificate_type': _selectedCertType,
      'certificate_date': _certDateController.text,
      'previous_university': _attendedPrevUni ? _prevUniController.text : '',
      'previous_admission_date': _attendedPrevUni ? _prevAdmDateController.text : '',
    };

    final profileProv = context.read<ProfileProvider>();
    final success = await profileProv.updateProfile(
      fields: fields,
      photoPath: _avatarFile?.path,
      certPhotoPath: _certFile?.path,
      idPhotoPath: _idFile?.path,
    );

    if (success && mounted) {
      final authProv = context.read<AuthProvider>();
      authProv.markProfileCompleted();

      if (profileProv.profileData != null) {
        authProv.updateLocalPhoto(profileProv.profileData!['photo_path']);
      }

      setState(() {
        _isLoading = false;
        _isComplete = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileProv.successMessage ?? 'تم حفظ وتأكيد كافة البيانات بنجاح ✓',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.accent,
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileProv.errorMessage ?? 'حدث خطأ أثناء حفظ البيانات',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showMissingDataDialog() {
    final missing = _missingItems;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('بيانات ناقصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يرجى إكمال جميع البيانات والصور المطلوبة قبل الحفظ:',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً، سأكمل البيانات', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _updateSecurity() async {
    final pass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.isNotEmpty && pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمات المرور غير متطابقة', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final profileProv = context.read<ProfileProvider>();
    final success = await profileProv.updateSecurity(
      email: _emailController.text.trim(),
      password: pass.isNotEmpty ? pass : null,
    );

    if (success && mounted) {
      setState(() {
        _isLoading = false;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileProv.successMessage ?? 'تم تحديث إعدادات الأمان بنجاح',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.accent,
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileProv.errorMessage ?? 'حدث خطأ أثناء تحديث إعدادات الأمان',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeartbeatLoader(),
                          SizedBox(height: 16),
                          Text(
                            'جاري معالجة بيانات الملف...',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Column(
                        children: [
                          // شريط حالة الملف الشخصي
                          _buildStatusBanner(),
                          const SizedBox(height: 15),

                          if (!_isComplete) ...[
                            // ── وضع التعديل: البيانات ناقصة ──
                            _buildPersonalEditCard(),
                            _buildGuardianEditCard(),
                            _buildAcademicEditCard(),
                            _buildDocsEditCard(),

                            // مؤشر التقدم والحقول الناقصة
                            if (!_canSave) _buildMissingFieldsHint(),

                            const SizedBox(height: 10),

                            // زر الحفظ — يتغير مظهره حسب الاكتمال
                            AnimatedOpacity(
                              opacity: _canSave ? 1.0 : 0.5,
                              duration: const Duration(milliseconds: 300),
                              child: CustomButton(
                                text: _canSave
                                    ? 'حفظ وتأكيد كافة البيانات ✓'
                                    : 'أكمل جميع البيانات أولاً',
                                onPressed: _saveProfile,
                              ),
                            ),
                          ] else ...[
                            // ── وضع العرض: البيانات مكتملة ──
                            _buildLockedNoticeCard(),
                            _buildPersonalViewCard(),
                            _buildGuardianViewCard(),
                            _buildAcademicViewCard(),
                            _buildDocsViewCard(),
                            _buildSecurityCard(),
                          ],
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── شريط حالة الملف ────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    if (_isComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الملف الشخصي مكتمل ومؤكد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // احسب نسبة الاكتمال
      final total = 12; // 9 حقول + 3 صور
      final missing = _missingItems.length;
      final completed = total - missing;
      final percent = (completed / total * 100).round();

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'يرجى إكمال بياناتك — $percent% مكتمل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: completed / total,
                backgroundColor: Colors.orange.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── بطاقة التنبيه: البيانات مقفولة بعد الاكتمال ───────────────────────────
  Widget _buildLockedNoticeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            Colors.indigo.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const FaIcon(FontAwesomeIcons.lock, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'البيانات مقفولة للتعديل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تم اكتمال وتأكيد ملفك الشخصي. لا يمكن تعديل البيانات الشخصية مباشرةً لضمان صحة السجلات الأكاديمية.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'يمكنك رفع طلب تعديل من قسم الدعم الفني',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.headset, color: Colors.white, size: 13),
                        SizedBox(width: 7),
                        Text(
                          'طلب تعديل عبر الدعم الفني',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  // ── مؤشر الحقول الناقصة أثناء التعديل ────────────────────────────────────
  Widget _buildMissingFieldsHint() {
    final missing = _missingItems;
    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red.shade700, size: 17),
              const SizedBox(width: 8),
              Text(
                'لا يزال ${missing.length} عنصر ناقص:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: missing
                .map(
                  (item) => Chip(
                    label: Text(item, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    backgroundColor: Colors.red.shade100,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final authProv = context.watch<AuthProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 25),
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
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const FaIcon(FontAwesomeIcons.idCard, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'ملف الطالب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              // شارة حالة الملف في الهيدر
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isComplete
                      ? Colors.green.withValues(alpha: 0.25)
                      : Colors.orange.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isComplete ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isComplete ? Icons.lock_rounded : Icons.edit_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isComplete ? 'مكتمل' : 'يحتاج إكمال',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar Circle — قابل للنقر فقط إذا البيانات ناقصة
              Stack(
                children: [
                  GestureDetector(
                    onTap: _isComplete ? null : () => _pickImage('avatar'),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white,
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!) as ImageProvider<Object>
                          : (authProv.photoPath != null && authProv.photoPath!.isNotEmpty)
                              ? NetworkImage(authProv.photoPath!) as ImageProvider<Object>
                              : null,
                      child: _avatarFile == null && (authProv.photoPath == null || authProv.photoPath!.isEmpty)
                          ? const Icon(Icons.person, size: 45, color: AppColors.primary)
                          : null,
                    ),
                  ),
                  if (!_isComplete)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                      ),
                    ),
                  if (_isComplete)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 13),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProv.studentName ?? (_isComplete ? 'اسم الطالب' : 'يرجى إكمال البيانات'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.hashtag, size: 10, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'رقم الجلوس: ${authProv.seatNumber ?? "غير معرف"}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Personal Section: Edit & View ──────────────────────────────────────────
  Widget _buildPersonalEditCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'البيانات الشخصية', icon: FontAwesomeIcons.user),
          CustomTextField(label: 'تاريخ الميلاد (الفعلي)', hint: 'YYYY-MM-DD', controller: _birthDateController),
          CustomTextField(label: 'رقم الهاتف', hint: '090XXXXXXX', controller: _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          const Text('الجنس', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
          RadioGroup<String>(
            groupValue: _selectedGender,
            onChanged: (val) => setState(() => _selectedGender = val!),
            child: Row(
              children: [
                Radio<String>(
                  value: 'M',
                  activeColor: AppColors.primary,
                ),
                const Text('ذكر', style: TextStyle(fontFamily: 'Cairo')),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'F',
                  activeColor: AppColors.primary,
                ),
                const Text('أنثى', style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
          ),
          CustomTextField(label: 'السكن الحالي', hint: 'مثال: الخرطوم - الطائف', controller: _currentAddressController),
          CustomTextField(label: 'السكن الأصلي', hint: 'مكان نشأتك الأساسي', controller: _permanentAddressController),
        ],
      ),
    );
  }

  Widget _buildPersonalViewCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'البيانات الشخصية', icon: FontAwesomeIcons.user),
          _detailRow('تاريخ الميلاد', _birthDateController.text),
          _detailRow('رقم الهاتف', _phoneController.text),
          _detailRow('الجنس', _selectedGender == 'M' ? 'ذكر' : 'أنثى'),
          _detailRow('السكن الحالي', _currentAddressController.text),
          _detailRow('السكن الأصلي', _permanentAddressController.text),
        ],
      ),
    );
  }

  // ── Guardian Section: Edit & View ──────────────────────────────────────────
  Widget _buildGuardianEditCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'بيانات ولي الأمر', icon: FontAwesomeIcons.userShield),
          CustomTextField(label: 'اسم ولي الأمر رباعي', hint: 'الاسم الكامل لولي الأمر', controller: _guardianNameController),
          CustomTextField(label: 'رقم هاتف ولي الأمر', hint: '09XXXXXXXX', controller: _guardianPhoneController, keyboardType: TextInputType.phone),
          CustomTextField(label: 'صلة القرابة', hint: 'مثال: أب - خال - أخ', controller: _guardianRelationController),
          CustomTextField(label: 'وظيفة ولي الأمر', hint: 'المهنة الحالية', controller: _guardianJobController),
        ],
      ),
    );
  }

  Widget _buildGuardianViewCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'بيانات ولي الأمر', icon: FontAwesomeIcons.userShield),
          _detailRow('اسم ولي الأمر', _guardianNameController.text),
          _detailRow('رقم الهاتف', _guardianPhoneController.text),
          _detailRow('صلة القرابة', _guardianRelationController.text),
          _detailRow('الوظيفة', _guardianJobController.text),
        ],
      ),
    );
  }

  // ── Academic Section: Edit & View ──────────────────────────────────────────
  Widget _buildAcademicEditCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'البيانات الأكاديمية', icon: FontAwesomeIcons.graduationCap),
          const CustomTextField(
            label: 'مكان الدراسة (الفرع)',
            hint: 'المقر الرئيسي',
            enabled: false,
          ),
          const SizedBox(height: 8),
          const Text('نوع الشهادة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
          DropdownButtonFormField<String>(
            initialValue: _selectedCertType,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: 'سودانية', child: Text('سودانية', style: TextStyle(fontFamily: 'Cairo'))),
              DropdownMenuItem(value: 'أخرى', child: Text('أخرى / شهادة عربية أو أجنبية', style: TextStyle(fontFamily: 'Cairo'))),
            ],
            onChanged: (val) => setState(() => _selectedCertType = val ?? _selectedCertType),
          ),
          CustomTextField(label: 'تاريخ الشهادة (سنة-شهر)', hint: 'YYYY-MM', controller: _certDateController),
          const SizedBox(height: 10),
          CheckboxListTile(
            title: const Text('هل التحقت بجامعة أخرى سابقاً؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
            value: _attendedPrevUni,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _attendedPrevUni = val!),
          ),
          if (_attendedPrevUni) ...[
            CustomTextField(label: 'اسم الجامعة السابقة', hint: 'مثال: جامعة الخرطوم', controller: _prevUniController),
            CustomTextField(label: 'تاريخ الالتحاق بالجامعة السابقة', hint: 'YYYY-MM-DD', controller: _prevAdmDateController),
          ]
        ],
      ),
    );
  }

  Widget _buildAcademicViewCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'البيانات الأكاديمية', icon: FontAwesomeIcons.graduationCap),
          _detailRow('مكان الدراسة (الفرع)', 'المقر الرئيسي'),
          _detailRow('نوع الشهادة', _selectedCertType),
          _detailRow('تاريخ الشهادة', _certDateController.text),
          if (_attendedPrevUni) ...[
            _detailRow('الجامعة السابقة', _prevUniController.text),
            _detailRow('تاريخ الالتحاق', _prevAdmDateController.text),
          ],
        ],
      ),
    );
  }

  // ── Documents Section: Edit & View ─────────────────────────────────────────
  Widget _buildDocsEditCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'الوثائق والمرفقات (مطلوبة جميعها)', icon: FontAwesomeIcons.cameraRetro),
          _buildUploadButton('الصورة الشخصية', _avatarFile, _existingAvatarUrl, () => _pickImage('avatar')),
          _buildUploadButton('صورة الشهادة', _certFile, _existingCertUrl, () => _pickImage('cert')),
          _buildUploadButton('صورة إثبات الهوية', _idFile, _existingIdUrl, () => _pickImage('id')),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String label, File? file, String? existingUrl, VoidCallback onTap) {
    final bool hasExisting = existingUrl != null && existingUrl.isNotEmpty;
    final bool isDone = file != null || hasExisting;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDone ? AppColors.primary.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDone ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.cloud_upload_outlined,
                color: isDone ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone
                          ? (file != null ? 'تم اختيار ملف $label' : '$label (مرفوعة مسبقاً)')
                          : 'تحميل $label',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDone ? AppColors.primary : Colors.black87,
                        fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isDone)
                      const Text(
                        'اضغط لتغيير الصورة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              if (isDone) const Icon(Icons.refresh, size: 18, color: AppColors.primary),
              if (!isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'مطلوب',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocsViewCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'الوثائق والمرفقات', icon: FontAwesomeIcons.cameraRetro),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDocPreview('الصورة الشخصية', _avatarFile, _existingAvatarUrl),
              _buildDocPreview('الشهادة الدراسية', _certFile, _existingCertUrl),
              _buildDocPreview('إثبات الهوية', _idFile, _existingIdUrl),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDocPreview(String label, File? file, String? existingUrl) {
    final bool hasExisting = existingUrl != null && existingUrl.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: file != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image)),
                )
              : hasExisting
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(existingUrl ?? '', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image)),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file != null || hasExisting)
              const Icon(Icons.check_circle, size: 11, color: Colors.green),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  // ── Security & Password Section ────────────────────────────────────────────
  Widget _buildSecurityCard() {
    return CustomCard(
      marginBottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeaderTitle(title: 'إعدادات الأمان (الوصول)', icon: FontAwesomeIcons.userLock),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.envelope, color: AppColors.primary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('البريد الإلكتروني المعتمد', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'Cairo')),
                      Text(_emailController.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                const Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CustomTextField(label: 'كلمة المرور الجديدة', hint: '******', isPassword: true, controller: _newPasswordController),
          CustomTextField(label: 'تأكيد كلمة المرور', hint: '******', isPassword: true, controller: _confirmPasswordController),
          const SizedBox(height: 10),
          CustomButton(
            text: 'تحديث كلمة المرور',
            onPressed: _updateSecurity,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted)),
          Text(
            value.isNotEmpty ? value : 'غير متوفر',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _CardHeaderTitle extends StatelessWidget {
  final String title;
  final FaIconData icon;

  const _CardHeaderTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            FaIcon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 14),
      ],
    );
  }
}
