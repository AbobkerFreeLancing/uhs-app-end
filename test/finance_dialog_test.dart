import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uohs_student_app/providers/finance_provider.dart';
import 'package:uohs_student_app/views/finance/finance_screen.dart';

// فئة محاكاة لـ FinanceProvider لحقن بيانات مزيفة وتجنب طلبات الشبكة
class MockFinanceProvider extends FinanceProvider {
  final List<dynamic> mockInvoices;
  final List<dynamic> mockBanks;

  MockFinanceProvider({required this.mockInvoices, required this.mockBanks});

  @override
  List<dynamic> get invoices => mockInvoices;

  @override
  List<dynamic> get banks => mockBanks;

  @override
  Map<String, dynamic> get summary => {
    'required': '1000.00',
    'paid': '0.00',
    'in_progress': '0.00',
  };

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchFinancials() async {
    // لا نفعل شيئاً في الفحص المحاكي لتجنب الاتصال بالشبكة
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FinanceScreen payment dialog test', (WidgetTester tester) async {
    final mockInvoices = [
      {
        'id': 1,
        'invoice_number': 'INV-1234',
        'due_date': '2026-06-01',
        'amount': '1000.00',
        'paid_amount': '0.00',
        'status': 'unpaid',
        'name_ar': 'رسوم التسجيل',
        'payment_receipt': null,
      }
    ];

    final mockBanks = [
      {
        'id': 2,
        'bank_name': 'فوري',
        'account_number': '30030175',
      },
      {
        'id': 3,
        'bank_name': 'بنك الخرطوم (بنكك)',
        'account_number': '7744325',
      }
    ];

    final mockProvider = MockFinanceProvider(
      mockInvoices: mockInvoices,
      mockBanks: mockBanks,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<FinanceProvider>.value(
          value: mockProvider,
          child: const FinanceScreen(),
        ),
      ),
    );

    // ننتظر انتهاء التحميل الافتراضي
    await tester.pumpAndSettle();

    // نتحقق من أن زر "إرسال إشعار دفع" موجود
    final buttonFinder = find.text('إرسال إشعار دفع');
    expect(buttonFinder, findsOneWidget);

    // ننقر على الزر لفتح النافذة المنبثقة
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // نتحقق من أن العنوان "رفع إشعار سداد بنكي" قد ظهر في النافذة المنبثقة
    expect(find.text('رفع إشعار سداد بنكي'), findsOneWidget);
  });
}
