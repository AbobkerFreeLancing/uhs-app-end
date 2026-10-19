import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/heartbeat_loader.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class InvoiceItem {
  final String nameAr;
  final double amount;
  InvoiceItem({required this.nameAr, required this.amount});
}

class Invoice {
  final int id;
  final String invoiceNumber;
  final String dueDate;
  final double totalAmount;
  final double paidAmount;
  final String status; // 'paid' | 'unpaid' | 'partial'
  final String? paymentMethod;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.dueDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.paymentMethod,
    required this.items,
  });

  double get remainingAmount => totalAmount - paidAmount;
}

// ─── Finance Screen ──────────────────────────────────────────────────────────

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FinanceScreenState createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // جلب البيانات المالية عند الفتح مباشرة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final financeProv = context.read<FinanceProvider>();
    await financeProv.fetchFinancials();
    
    if (mounted) {
      setState(() {
        _invoices = financeProv.invoices.map((inv) {
          final items = <InvoiceItem>[];
          if (inv['name_ar'] != null) {
            items.add(InvoiceItem(
              nameAr: inv['name_ar'].toString(),
              amount: double.tryParse(inv['amount'].toString()) ?? 0.0,
            ));
          }
          return Invoice(
            id: inv['id'] is int ? inv['id'] : int.parse(inv['id'].toString()),
            invoiceNumber: inv['invoice_number'] ?? '',
            dueDate: inv['due_date'] ?? '',
            totalAmount: double.tryParse(inv['total_amount'].toString()) ?? 0.0,
            paidAmount: double.tryParse(inv['paid_amount'].toString()) ?? 0.0,
            status: inv['status'] ?? 'unpaid',
            paymentMethod: inv['payment_receipt'] != null ? 'bank' : null,
            items: items,
          );
        }).toList();
        _isLoading = false;
      });
    }
  }

  // ── Summary Totals ──────────────────────────────────────────────────────────
  double get _totalDue => double.tryParse(context.watch<FinanceProvider>().summary['required']?.toString() ?? '0') ?? 0.0;
  double get _totalPaid => double.tryParse(context.watch<FinanceProvider>().summary['paid']?.toString() ?? '0') ?? 0.0;
  double get _totalRemaining => _totalDue - _totalPaid;

  List<Invoice> _filteredInvoices(String status) {
    if (status == 'all') return _invoices;
    return _invoices.where((inv) => inv.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeartbeatLoader(),
                      SizedBox(height: 16),
                      Text(
                        'جاري تحميل بياناتك المالية...',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildSummaryCards(),
              _buildTabBar(),
              Expanded(child: _buildTabViews()),
            ],
          ],
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
          const FaIcon(FontAwesomeIcons.fileInvoiceDollar,
              color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text(
            'الفواتير والأقسام',
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
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ───────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          _buildSummaryCard(
            label: 'إجمالي المستحق',
            amount: _totalDue,
            color: const Color(0xFF4f46e5),
            icon: FontAwesomeIcons.coins,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            label: 'المسدّد',
            amount: _totalPaid,
            color: const Color(0xFF059669),
            icon: FontAwesomeIcons.circleCheck,
          ),
          const SizedBox(width: 10),
          _buildSummaryCard(
            label: 'المتبقي',
            amount: _totalRemaining,
            color: const Color(0xFFdc2626),
            icon: FontAwesomeIcons.clockRotateLeft,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double amount,
    required Color color,
    required FaIconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            FaIcon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              '${amount.toStringAsFixed(0)} ج',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'الكل'),
          Tab(text: 'معلقة'),
          Tab(text: 'مسدّدة'),
        ],
      ),
    );
  }

  // ── Tab Views ───────────────────────────────────────────────────────────────
  Widget _buildTabViews() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildInvoiceList('all'),
        _buildInvoiceList('unpaid'),
        _buildInvoiceList('paid'),
      ],
    );
  }

  Widget _buildInvoiceList(String filter) {
    final list = _filteredInvoices(filter == 'paid' ? 'paid' : filter);
    final displayList = filter == 'unpaid'
        ? _invoices
            .where((inv) => inv.status == 'unpaid' || inv.status == 'partial')
            .toList()
        : list;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(FontAwesomeIcons.fileCircleCheck,
                size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'لا توجد فواتير في هذه الفئة',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Cairo',
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: displayList.length,
      itemBuilder: (context, index) =>
          _buildInvoiceCard(displayList[index], index),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, int index) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (invoice.status) {
      case 'paid':
        statusColor = const Color(0xFF059669);
        statusLabel = 'محصّلة';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'partial':
        statusColor = const Color(0xFFd97706);
        statusLabel = 'جزئية';
        statusIcon = Icons.hourglass_bottom;
        break;
      default:
        statusColor = const Color(0xFFdc2626);
        statusLabel = 'معلّقة';
        statusIcon = Icons.cancel_outlined;
    }

    final double progress =
        invoice.totalAmount > 0 ? invoice.paidAmount / invoice.totalAmount : 0;

    return GestureDetector(
      onTap: () => _showInvoiceDetails(invoice),
      child: CustomCard(
        marginBottom: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Cairo',
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'تاريخ الاستحقاق: ${invoice.dueDate}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusBadge(
                  text: statusLabel,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  textColor: statusColor,
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Items ────────────────────────────────────────────────────
            ...invoice.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '• ${item.nameAr}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      '${item.amount.toStringAsFixed(0)} ج',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Progress Bar ──────────────────────────────────────────────
            if (invoice.status != 'paid') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المسدّد: ${invoice.paidAmount.toStringAsFixed(0)} ج',
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'المتبقي: ${invoice.remainingAmount.toStringAsFixed(0)} ج',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFdc2626),
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Footer Total + Pay Button ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Cairo'),
                    ),
                    Text(
                      '${invoice.totalAmount.toStringAsFixed(2)} ج.س',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                if (invoice.status != 'paid')
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(invoice),
                    icon: const FaIcon(FontAwesomeIcons.creditCard,
                        size: 13, color: Colors.white),
                    label: const Text(
                      'إرسال إشعار دفع',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                  )
                else
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.receipt,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        invoice.paymentMethod == 'bank' ? 'بنكي' : 'نقدي',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Invoice Details Bottom Sheet ─────────────────────────────────────────
  void _showInvoiceDetails(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  'تفاصيل الفاتورة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('رقم الفاتورة', invoice.invoiceNumber),
                _detailRow('تاريخ الاستحقاق', invoice.dueDate),
                _detailRow('الإجمالي',
                    '${invoice.totalAmount.toStringAsFixed(2)} ج.س'),
                _detailRow(
                    'المسدّد', '${invoice.paidAmount.toStringAsFixed(2)} ج.س'),
                _detailRow('المتبقي',
                    '${invoice.remainingAmount.toStringAsFixed(2)} ج.س'),
                if (invoice.paymentMethod != null)
                  _detailRow('طريقة الدفع',
                      invoice.paymentMethod == 'bank' ? 'تحويل بنكي' : 'نقدي'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'بنود الفاتورة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                ...invoice.items.map((item) => _detailRow(
                    item.nameAr, '${item.amount.toStringAsFixed(2)} ج.س')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }

  // ── Payment Dialog with File Upload & Bank Details ────────────────────────
  void _showPaymentDialog(Invoice invoice) {
    final financeProv = context.read<FinanceProvider>();
    final transactionController = TextEditingController();
    String? selectedBank;
    File? receiptImageFile;
    bool isUploading = false;

    // تهيئة البنك الافتراضي إذا وجد
    if (financeProv.banks.isNotEmpty) {
      selectedBank = financeProv.banks.first['bank_name']?.toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'رفع إشعار سداد بنكي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات الفاتورة
                Text(
                  'فاتورة: ${invoice.invoiceNumber}\nالقيمة المستحقة: ${invoice.remainingAmount.toStringAsFixed(2)} ج.س',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textDark),
                ),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 10),

                // بيانات البنوك المتاحة
                if (financeProv.banks.isNotEmpty) ...[
                  const Text(
                    'الحسابات البنكية المعتمدة للجامعة:',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: financeProv.banks.map<Widget>((b) {
                          final name = b['bank_name'] ?? '';
                          final num = b['account_number'] ?? '';
                          final accName = b['account_name']?.toString() ?? '';
                          final dispName = accName.isNotEmpty ? ' ($accName)' : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              '• $name: $num$dispName',
                              style: const TextStyle(fontSize: 10, fontFamily: 'Cairo', color: AppColors.textMuted),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                // اختيار البنك
                const Text('اختر البنك المحول إليه', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedBank,
                  dropdownColor: Colors.white,
                  hint: const Text('اختر البنك المالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: financeProv.banks.isNotEmpty
                      ? financeProv.banks
                          .map((b) => b['bank_name']?.toString() ?? 'بنك')
                          .toSet()
                          .map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            );
                          }).toList()
                      : [
                          const DropdownMenuItem<String>(
                            value: 'بنك الخرطوم',
                            child: Text('بنك الخرطوم (بنكك)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                          ),
                          const DropdownMenuItem<String>(
                            value: 'بنك أم درمان الوطني',
                            child: Text('بنك أم درمان الوطني', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                          )
                        ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedBank = val;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // رقم الإشعار/التحويل
                const Text('رقم العملية / المرجع المالي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: transactionController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    hintText: 'أدخل رقم المعاملة البنكية',
                    hintStyle: const TextStyle(fontSize: 11, fontFamily: 'Cairo'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 15),

                // إرفاق صورة الإيصال
                const Text('إرفاق إيصال التحويل (صورة)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    try {
                      final XFile? picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 70,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          receiptImageFile = File(picked.path);
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('خطأ في تحديد الصورة', style: TextStyle(fontFamily: 'Cairo'))),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: receiptImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(receiptImageFile!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 30, color: AppColors.primary),
                              SizedBox(height: 6),
                              Text('اضغط لتصفح المعرض وإرفاق صورة', style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: AppColors.textMuted)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 15),

                // مؤشر الرفع
                if (isUploading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.danger)),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      final txNum = transactionController.text.trim();
                      if (selectedBank == null || selectedBank!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء تحديد البنك المحول إليه', style: TextStyle(fontFamily: 'Cairo'))),
                        );
                        return;
                      }
                      if (txNum.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء إدخال رقم المعاملة البنكية', style: TextStyle(fontFamily: 'Cairo'))),
                        );
                        return;
                      }
                      if (receiptImageFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('الرجاء إرفاق صورة إيصال التحويل', style: TextStyle(fontFamily: 'Cairo'))),
                        );
                        return;
                      }

                      setDialogState(() {
                        isUploading = true;
                      });

                      final success = await financeProv.uploadReceipt(
                        invoiceId: invoice.id,
                        transactionNumber: txNum,
                        bankName: selectedBank!,
                        receiptFilePath: receiptImageFile!.path,
                      );

                      setDialogState(() {
                        isUploading = false;
                      });

                      if (success) {
                        Navigator.pop(ctx);
                        _loadData(); // إعادة جلب الفواتير لتحديث القائمة
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(financeProv.successMessage ?? 'تم رفع إشعار السداد بنجاح وجاري المراجعة', style: const TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: AppColors.accent,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(financeProv.errorMessage ?? 'فشل رفع الإشعار المالي', style: const TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('إرسال الإشعار', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
