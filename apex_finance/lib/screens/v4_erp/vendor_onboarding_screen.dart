/// APEX Wave 76 — Vendor Onboarding Wizard.
/// Route: /app/erp/operations/vendor-onboarding
///
/// Step-by-step new vendor registration with compliance checks.
library;

import 'package:flutter/material.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});
  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  int _currentStep = 0;

  final _steps = const [
    _Step('1', 'البيانات الأساسية', 'اسم الشركة، السجل التجاري، الرقم الضريبي', Icons.business),
    _Step('2', 'التواصل والعناوين', 'جهات الاتصال، العنوان، الموقع الإلكتروني', Icons.contact_mail),
    _Step('3', 'البيانات البنكية', 'الآيبان، اسم البنك، طريقة الدفع', Icons.account_balance),
    _Step('4', 'المستندات والشهادات', 'السجل التجاري، الزكاة، GOSI، SADAD', Icons.upload_file),
    _Step('5', 'فحص الامتثال', 'AML، العقوبات، التصنيف الائتماني', Icons.verified_user),
    _Step('6', 'التصنيف والموافقة', 'الفئة، الحد الائتماني، الاعتماد', Icons.approval),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildStepper(),
        Expanded(child: _buildStepContent()),
        _buildNavButtons(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF009688)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معالج إدخال مورد جديد',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('6 خطوات — تسجيل كامل مع فحوصات الامتثال التلقائية',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('الخطوة ${_currentStep + 1} من ${_steps.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Expanded(child: _stepIndicator(i)),
            if (i < _steps.length - 1)
              Container(
                width: 30,
                height: 2,
                color: i < _currentStep ? const Color(0xFF009688) : Colors.black12,
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepIndicator(int i) {
    final s = _steps[i];
    final isActive = i == _currentStep;
    final isDone = i < _currentStep;
    final color = isDone ? Colors.green : isActive ? const Color(0xFF009688) : Colors.grey.shade400;
    return InkWell(
      onTap: () => setState(() => _currentStep = i),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDone ? Colors.green : isActive ? const Color(0xFF009688) : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: isActive ? Border.all(color: const Color(0xFF009688), width: 3) : null,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(s.number,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                        color: isActive ? const Color(0xFF009688) : Colors.black87)),
                Text(s.description,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _basicsStep();
      case 1:
        return _contactStep();
      case 2:
        return _bankStep();
      case 3:
        return _docsStep();
      case 4:
        return _complianceStep();
      case 5:
        return _approvalStep();
      default:
        return const SizedBox();
    }
  }

  Widget _basicsStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('البيانات الأساسية للشركة'),
        Row(
          children: [
            Expanded(child: _field('الاسم التجاري *', 'ABC للتوريدات المحدودة')),
            const SizedBox(width: 12),
            Expanded(child: _field('الاسم القانوني بالإنجليزية', 'ABC Supplies Ltd')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('السجل التجاري *', '1010234567')),
            const SizedBox(width: 12),
            Expanded(child: _field('الرقم الضريبي (VAT) *', '300987654300003')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('الدولة *', 'المملكة العربية السعودية 🇸🇦')),
            const SizedBox(width: 12),
            Expanded(child: _field('سنة التأسيس', '2015')),
          ],
        ),
        _field('نوع المنشأة', 'شركة ذات مسؤولية محدودة (LLC)'),
        _field('الفئة التجارية', 'توريدات مكتبية ومعدات تقنية'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تلميح: أدخل السجل التجاري وسنقوم تلقائياً بسحب البيانات من وزارة التجارة إن كانت متاحة',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('جهات التواصل والعنوان'),
        Row(
          children: [
            Expanded(child: _field('اسم المسؤول *', 'خالد محمد العتيبي')),
            const SizedBox(width: 12),
            Expanded(child: _field('المنصب', 'مدير المبيعات')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('البريد الإلكتروني *', 'k.otaibi@abcsupplies.com.sa')),
            const SizedBox(width: 12),
            Expanded(child: _field('رقم الجوال *', '+966-50-1234567')),
          ],
        ),
        Row(
          children: [
            Expanded(child: _field('هاتف مكتب', '+966-11-4445566')),
            const SizedBox(width: 12),
            Expanded(child: _field('الموقع الإلكتروني', 'www.abcsupplies.com.sa')),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('العنوان'),
        Row(
          children: [
            Expanded(child: _field('المدينة', 'الرياض')),
            const SizedBox(width: 12),
            Expanded(child: _field('الحي', 'العليا')),
          ],
        ),
        _field('الشارع', 'طريق الملك فهد - مبنى 442'),
        _field('الرمز البريدي', '12821'),
      ],
    );
  }

  Widget _bankStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('البيانات البنكية'),
        _field('اسم البنك *', 'البنك الأهلي السعودي'),
        _field('الآيبان (IBAN) *', 'SA44 1000 0000 8034 5678 9100'),
        _field('اسم الحساب *', 'ABC للتوريدات المحدودة'),
        Row(
          children: [
            Expanded(child: _field('العملة الافتراضية', 'ر.س')),
            const SizedBox(width: 12),
            Expanded(child: _field('طريقة الدفع المفضّلة', 'تحويل بنكي (SARIE)')),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('شروط الدفع'),
        Row(
          children: [
            Expanded(child: _field('فترة السداد المتفق عليها', 'صافي 30 يوم')),
            const SizedBox(width: 12),
            Expanded(child: _field('الحد الائتماني المقترح', '500,000 ر.س')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سنقوم بالتحقق من صحة الآيبان عبر API البنك المركزي قبل إتمام التسجيل',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _docsStep() {
    final docs = const [
      _Doc('السجل التجاري', true, '2028-12-31'),
      _Doc('شهادة الزكاة والدخل', true, '2026-12-31'),
      _Doc('شهادة GOSI', true, '2026-12-31'),
      _Doc('شهادة SADAD', false, null),
      _Doc('شهادة سعودة', true, '2026-12-31'),
      _Doc('ترخيص البلدية', false, null),
      _Doc('البوليصة التأمينية', true, '2027-06-30'),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('المستندات والشهادات'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اسحب الملفات هنا أو اضغط لرفع. الصيغ المقبولة: PDF، JPG، PNG',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final d in docs) _docRow(d),
      ],
    );
  }

  Widget _docRow(_Doc d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (d.uploaded ? Colors.green : Colors.orange).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (d.uploaded ? Colors.green : Colors.orange).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(d.uploaded ? Icons.check : Icons.upload,
                color: d.uploaded ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                if (d.uploaded)
                  Text('منتهي: ${d.expiresAt}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'))
                else
                  const Text('لم يتم الرفع بعد', style: TextStyle(fontSize: 11, color: Colors.orange)),
              ],
            ),
          ),
          if (d.uploaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: const Text('مرفوع',
                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w800)),
            )
          else
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload, size: 14),
              label: const Text('رفع', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _complianceStep() {
    final checks = const [
      _ComplianceCheck('فحص قوائم العقوبات الدولية (OFAC, UN)', true, 'لا تطابق — آمن'),
      _ComplianceCheck('فحص العقوبات المحلية', true, 'لا تطابق — آمن'),
      _ComplianceCheck('فحص AML — قاعدة World-Check', true, 'منخفض المخاطر'),
      _ComplianceCheck('التحقق من السجل التجاري', true, 'ساري — وزارة التجارة'),
      _ComplianceCheck('التحقق من الرقم الضريبي', true, 'مفعّل في ZATCA'),
      _ComplianceCheck('التحقق من شهادة الزكاة', true, 'سارية حتى 2026-12-31'),
      _ComplianceCheck('فحص تاريخ السداد لموردين آخرين', true, 'تاريخ ممتاز — 5 شركات مرجعية'),
      _ComplianceCheck('التصنيف الائتماني (Simah)', true, 'درجة A-'),
    ];
    final passed = checks.where((c) => c.passed).length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('فحوصات الامتثال التلقائية'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نتيجة الفحص العامة',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('مؤهّل — موافقة مع متابعة سنوية',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Text('$passed / ${checks.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final c in checks)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Icon(c.passed ? Icons.check_circle : Icons.error,
                    color: c.passed ? Colors.green : Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(c.name, style: const TextStyle(fontSize: 12))),
                Text(c.result, style: TextStyle(fontSize: 11, color: c.passed ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _approvalStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('التصنيف والاعتماد النهائي'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ملخّص البيانات المُدخَلة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _summaryRow('الاسم', 'ABC للتوريدات المحدودة'),
              _summaryRow('السجل', '1010234567'),
              _summaryRow('الرقم الضريبي', '300987654300003'),
              _summaryRow('المسؤول', 'خالد محمد العتيبي'),
              _summaryRow('العنوان', 'الرياض — العليا'),
              _summaryRow('البنك', 'البنك الأهلي السعودي'),
              _summaryRow('المستندات', '5 / 7 مرفوعة'),
              _summaryRow('الامتثال', '✅ 8 / 8 فحوصات ناجحة'),
              const Divider(),
              Row(
                children: [
                  Expanded(child: _field('الفئة', 'توريدات مكتبية')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('المستوى', 'Silver')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field('الحد الائتماني المعتمد', '500,000 ر.س')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('شروط الدفع', 'صافي 30 يوم')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.approval, color: Color(0xFFD4AF37)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيُرسَل طلب الاعتماد إلى مدير المشتريات. متوقّع التفعيل خلال 24 ساعة عمل.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        controller: TextEditingController(text: value),
      ),
    );
  }

  Widget _summaryRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('السابق'),
            ),
          const Spacer(),
          Text('الخطوة ${_currentStep + 1} من ${_steps.length}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 20),
          if (_currentStep < _steps.length - 1)
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep++),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('التالي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمّ إرسال الطلب — سيتم تفعيل المورد بعد الاعتماد'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('إرسال للاعتماد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  const _Step(this.number, this.title, this.description, this.icon);
}

class _Doc {
  final String name;
  final bool uploaded;
  final String? expiresAt;
  const _Doc(this.name, this.uploaded, this.expiresAt);
}

class _ComplianceCheck {
  final String name;
  final bool passed;
  final String result;
  const _ComplianceCheck(this.name, this.passed, this.result);
}
