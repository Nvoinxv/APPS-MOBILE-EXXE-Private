// ============================================================
// FILE: lib/pages/payment_pages.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style/app_colors_payment.dart';

// ─────────────────────────────
// DATA MODELS
// ─────────────────────────────
enum PlanType { monthly, semiAnnual, annual }

class PlanInfo {
  final PlanType type;
  final String label;
  final String planKey;
  final double priceUSD;
  final double? originalUSD;
  final String period;
  final String? badge;
  final String saving;
  final List<String> features;

  const PlanInfo({
    required this.type,
    required this.label,
    required this.planKey,
    required this.priceUSD,
    this.originalUSD,
    required this.period,
    this.badge,
    required this.saving,
    required this.features,
  });
}

const List<PlanInfo> kPlans = [
  PlanInfo(
    type:    PlanType.monthly,
    label:   '1 Month',
    planKey: 'monthly',
    priceUSD: 66.00,
    period:  '/mo',
    saving:  '',
    features: [
      'Full market access',
      'Real-time StreetView data',
      'Basic alerts',
    ],
  ),
  PlanInfo(
    type:        PlanType.semiAnnual,
    label:       '6 Months',
    planKey:     'semi_annual',
    priceUSD:    264.00,
    originalUSD: 396.00,
    period:      '/6mo',
    badge:       'SAVE 33%',
    saving:      'Save \$132',
    features: [
      'Full market access',
      'Real-time StreetView data',
      'Advanced alerts',
      'Portfolio tracker',
    ],
  ),
  PlanInfo(
    type:        PlanType.annual,
    label:       '1 Year',
    planKey:     'annual',
    priceUSD:    396.00,
    originalUSD: 792.00,
    period:      '/yr',
    badge:       'BEST VALUE',
    saving:      'Save \$396',
    features: [
      'Full market access',
      'Real-time StreetView data',
      'Advanced alerts',
      'Portfolio tracker',
      'Priority support',
      'Early feature access',
    ],
  ),
];

// ─────────────────────────────
// PAYMENT METHOD MODEL
// ─────────────────────────────
class PaymentMethod {
  final String id;
  final String name;
  final String category;
  final String logoAsset;
  final bool isIndonesia;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.category,
    required this.logoAsset,
    required this.isIndonesia,
  });
}

const List<PaymentMethod> kPaymentMethods = [
  // ── Indonesia ──
  PaymentMethod(id: 'gopay',      name: 'GoPay',              category: 'ewallet', logoAsset: 'gopay',      isIndonesia: true),
  PaymentMethod(id: 'ovo',        name: 'OVO',                category: 'ewallet', logoAsset: 'ovo',        isIndonesia: true),
  PaymentMethod(id: 'dana',       name: 'DANA',               category: 'ewallet', logoAsset: 'dana',       isIndonesia: true),
  PaymentMethod(id: 'shopeepay',  name: 'ShopeePay',          category: 'ewallet', logoAsset: 'shopeepay',  isIndonesia: true),
  PaymentMethod(id: 'qris',       name: 'QRIS',               category: 'ewallet', logoAsset: 'qris',       isIndonesia: true),
  PaymentMethod(id: 'bca_va',     name: 'BCA Virtual Account',category: 'bank',    logoAsset: 'bca',        isIndonesia: true),
  PaymentMethod(id: 'mandiri_va', name: 'Mandiri VA',         category: 'bank',    logoAsset: 'mandiri',    isIndonesia: true),
  PaymentMethod(id: 'bni_va',     name: 'BNI VA',             category: 'bank',    logoAsset: 'bni',        isIndonesia: true),
  PaymentMethod(id: 'bri_va',     name: 'BRI VA',             category: 'bank',    logoAsset: 'bri',        isIndonesia: true),
  PaymentMethod(id: 'permata_va', name: 'Permata VA',         category: 'bank',    logoAsset: 'permata',    isIndonesia: true),
  // ── International ──
  PaymentMethod(id: 'visa',      name: 'Visa / Mastercard', category: 'card', logoAsset: 'visa',      isIndonesia: false),
  PaymentMethod(id: 'paypal',    name: 'PayPal',            category: 'card', logoAsset: 'paypal',    isIndonesia: false),
  PaymentMethod(id: 'stripe',    name: 'Stripe',            category: 'card', logoAsset: 'stripe',    isIndonesia: false),
  PaymentMethod(id: 'applepay',  name: 'Apple Pay',         category: 'card', logoAsset: 'applepay',  isIndonesia: false),
  PaymentMethod(id: 'googlepay', name: 'Google Pay',        category: 'card', logoAsset: 'googlepay', isIndonesia: false),
];

// ─────────────────────────────
// MAIN PAGE
// ─────────────────────────────
class PaymentPage extends StatefulWidget {
  final String token;
  const PaymentPage({Key? key, required this.token}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with TickerProviderStateMixin {
  PlanType _selectedPlan   = PlanType.semiAnnual;
  String?  _selectedMethod;
  bool     _isLoading      = false;
  int      _currentStep    = 0;

  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  PlanInfo get _plan => kPlans.firstWhere((p) => p.type == _selectedPlan);

  void _nextStep() {
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1 && _selectedMethod != null) {
      setState(() => _currentStep = 2);
    }
    _fadeCtrl
      ..reset()
      ..forward();
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _fadeCtrl
        ..reset()
        ..forward();
    }
  }

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: ganti dengan Payment_Hook.CheckoutPayment(
    //   amount: _plan.priceUSD.toInt(),
    //   customerName: _nameCtrl.text,
    //   customerEmail: _emailCtrl.text,
    //   planType: _plan.planKey,
    //   token: widget.token,
    // )
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);
    if (mounted) _showSuccessSheet();
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SuccessSheet(plan: _plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PaymentColorStyle.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildStepIndicator(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildCurrentStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(gradient: PaymentColorStyle.headerGradient),
      child: Row(
        children: [
          _buildNavButton(),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upgrade Plan', style: PaymentColorStyle.headingStyle),
              Text(
                _stepLabel(),
                style: PaymentColorStyle.captionStyle.copyWith(
                  color: PaymentColorStyle.greenNeon,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildSecureBadge(),
        ],
      ),
    );
  }

  Widget _buildNavButton() {
    final isBack = _currentStep > 0;
    return GestureDetector(
      onTap: isBack ? _prevStep : () => Navigator.pop(context),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: PaymentColorStyle.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PaymentColorStyle.borderColor),
        ),
        child: Icon(
          isBack ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
          size: isBack ? 16 : 18,
          color: PaymentColorStyle.subtitleText,
        ),
      ),
    );
  }

  Widget _buildSecureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PaymentColorStyle.greenDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── FIX: hapus const dari Container ini ──────────────────────────
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: PaymentColorStyle.greenNeon,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('SECURE', style: PaymentColorStyle.greenBadgeStyle),
        ],
      ),
    );
  }

  String _stepLabel() {
    switch (_currentStep) {
      case 0:  return 'Step 1 — Choose your plan';
      case 1:  return 'Step 2 — Payment method';
      default: return 'Step 3 — Confirm & pay';
    }
  }

  // ── STEP INDICATOR ─────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: List.generate(3, (i) {
          final active  = i <= _currentStep;
          final current = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: current ? 3 : 2,
                    decoration: BoxDecoration(
                      color: active
                          ? PaymentColorStyle.greenNeon
                          : PaymentColorStyle.borderColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: PaymentColorStyle.greenNeon.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP ROUTER ────────────────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _PlanStep(
          selectedPlan:   _selectedPlan,
          onPlanSelected: (p) => setState(() => _selectedPlan = p),
          onNext:         _nextStep,
        );
      case 1:
        return _MethodStep(
          selectedMethod:   _selectedMethod,
          onMethodSelected: (m) => setState(() => _selectedMethod = m),
          onNext:           _nextStep,
        );
      default:
        return _SummaryStep(
          plan:      _plan,
          method:    _selectedMethod!,
          nameCtrl:  _nameCtrl,
          emailCtrl: _emailCtrl,
          formKey:   _formKey,
          isLoading: _isLoading,
          onPay:     _handleCheckout,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — PLAN SELECTION
// ─────────────────────────────────────────────────────────────────────────────
class _PlanStep extends StatelessWidget {
  final PlanType selectedPlan;
  final ValueChanged<PlanType> onPlanSelected;
  final VoidCallback onNext;

  const _PlanStep({
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Text('Choose your plan', style: PaymentColorStyle.displayStyle),
              const SizedBox(height: 4),
              Text(
                'Unlock full access to StreetView Investing',
                style: PaymentColorStyle.labelStyle,
              ),
              const SizedBox(height: 24),
              ...kPlans.map((plan) => _PlanCard(
                plan:       plan,
                isSelected: selectedPlan == plan.type,
                onTap:      () => onPlanSelected(plan.type),
              )),
              const SizedBox(height: 16),
              _buildGuaranteeNote(),
            ],
          ),
        ),
        _buildBottomCTA(label: 'Continue to Payment', onTap: onNext),
      ],
    );
  }

  Widget _buildGuaranteeNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaymentColorStyle.greenDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: PaymentColorStyle.greenNeon, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All plans include 7-day money-back guarantee',
              style: PaymentColorStyle.labelStyle.copyWith(
                color: PaymentColorStyle.greenNeon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanInfo plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? PaymentColorStyle.selectedPlanGradient
              : PaymentColorStyle.planCardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? PaymentColorStyle.greenNeon
                : PaymentColorStyle.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? PaymentColorStyle.selectedCardShadow
              : PaymentColorStyle.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? PaymentColorStyle.greenNeon
                          : PaymentColorStyle.borderColor,
                      width: isSelected ? 5 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(plan.label, style: PaymentColorStyle.headingStyle),
                const Spacer(),
                if (plan.badge != null) _buildBadge(plan.badge!),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${plan.priceUSD.toStringAsFixed(0)}',
                  style: PaymentColorStyle.priceStyle.copyWith(
                    color: isSelected
                        ? PaymentColorStyle.greenNeon
                        : PaymentColorStyle.titleText,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(plan.period, style: PaymentColorStyle.pricePeriodStyle),
                ),
                if (plan.originalUSD != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '\$${plan.originalUSD!.toStringAsFixed(0)}',
                    style: PaymentColorStyle.captionStyle.copyWith(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: PaymentColorStyle.bodyText,
                    ),
                  ),
                ],
                const Spacer(),
                if (plan.saving.isNotEmpty)
                  Text(
                    plan.saving,
                    style: PaymentColorStyle.captionStyle.copyWith(
                      color: PaymentColorStyle.greenLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: PaymentColorStyle.borderColor, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: plan.features
                  .map((f) => _FeatureChip(label: f, isSelected: isSelected))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: text == 'BEST VALUE'
            ? PaymentColorStyle.goldAccent
            : PaymentColorStyle.greenNeon,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: PaymentColorStyle.greenBadgeStyle.copyWith(
          color: PaymentColorStyle.backgroundColor,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FeatureChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_rounded,
          size: 12,
          color: isSelected
              ? PaymentColorStyle.greenNeon
              : PaymentColorStyle.bodyText,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: PaymentColorStyle.captionStyle.copyWith(
            color: isSelected
                ? PaymentColorStyle.subtitleText
                : PaymentColorStyle.bodyText,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — PAYMENT METHOD
// ─────────────────────────────────────────────────────────────────────────────
class _MethodStep extends StatelessWidget {
  final String? selectedMethod;
  final ValueChanged<String> onMethodSelected;
  final VoidCallback onNext;

  const _MethodStep({
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final local = kPaymentMethods.where((m) => m.isIndonesia).toList();
    final intl  = kPaymentMethods.where((m) => !m.isIndonesia).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Text('Payment method', style: PaymentColorStyle.displayStyle),
              const SizedBox(height: 4),
              Text('Choose how you want to pay',
                  style: PaymentColorStyle.labelStyle),
              const SizedBox(height: 24),
              _buildSection('🇮🇩  Indonesia', local),
              const SizedBox(height: 20),
              _buildSection('🌐  International', intl),
            ],
          ),
        ),
        _buildBottomCTA(
          label: 'Review Order',
          onTap: selectedMethod != null ? onNext : null,
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<PaymentMethod> methods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: PaymentColorStyle.captionStyle.copyWith(
                color: PaymentColorStyle.bodyText,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Divider(color: PaymentColorStyle.borderColor)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: methods.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemBuilder: (_, i) => _MethodTile(
            method:     methods[i],
            isSelected: selectedMethod == methods[i].id,
            onTap:      () => onMethodSelected(methods[i].id),
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  IconData _icon() {
    switch (method.category) {
      case 'ewallet': return Icons.account_balance_wallet_rounded;
      case 'bank':    return Icons.account_balance_rounded;
      default:        return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? PaymentColorStyle.greenDark.withOpacity(0.5)
              : PaymentColorStyle.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? PaymentColorStyle.greenNeon
                : PaymentColorStyle.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PaymentColorStyle.greenNeon.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _icon(),
              size: 18,
              color: isSelected
                  ? PaymentColorStyle.greenNeon
                  : PaymentColorStyle.bodyText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                method.name,
                style: PaymentColorStyle.labelStyle.copyWith(
                  color: isSelected
                      ? PaymentColorStyle.titleText
                      : PaymentColorStyle.subtitleText,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: PaymentColorStyle.greenNeon),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — SUMMARY & CONFIRM
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStep extends StatelessWidget {
  final PlanInfo plan;
  final String method;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onPay;

  const _SummaryStep({
    required this.plan,
    required this.method,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.formKey,
    required this.isLoading,
    required this.onPay,
  });

  PaymentMethod get _method =>
      kPaymentMethods.firstWhere((m) => m.id == method);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text('Confirm order', style: PaymentColorStyle.displayStyle),
                const SizedBox(height: 4),
                Text('Almost done — fill in your info',
                    style: PaymentColorStyle.labelStyle),
                const SizedBox(height: 24),
                _buildOrderCard(),
                const SizedBox(height: 20),
                _buildSectionLabel('Customer Information'),
                const SizedBox(height: 10),
                _buildTextField(
                  ctrl:      nameCtrl,
                  hint:      'Full name',
                  icon:      Icons.person_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  ctrl:         emailCtrl,
                  hint:         'Email address',
                  icon:         Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 20),
                _buildPriceBreakdown(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 11, color: PaymentColorStyle.bodyText),
                    const SizedBox(width: 5),
                    Text(
                      'Secured by 256-bit SSL encryption',
                      style: PaymentColorStyle.captionStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildBottomCTA(
            label:     isLoading ? 'Processing...' : 'Pay \$${plan.priceUSD.toStringAsFixed(0)}',
            onTap:     isLoading ? null : onPay,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:     PaymentColorStyle.selectedPlanGradient,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.3)),
        boxShadow:    PaymentColorStyle.selectedCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const BoxDecoration(
                  color:        PaymentColorStyle.greenNeon,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text('PLAN', style: PaymentColorStyle.greenBadgeStyle),
              ),
              const SizedBox(width: 12),
              Text(plan.label, style: PaymentColorStyle.headingStyle),
              const Spacer(),
              Text(
                '\$${plan.priceUSD.toStringAsFixed(0)}${plan.period}',
                style: PaymentColorStyle.priceStyle.copyWith(
                  fontSize: 18,
                  color: PaymentColorStyle.greenNeon,
                ),
              ),
            ],
          ),
          if (plan.saving.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.trending_down_rounded,
                    size: 14, color: PaymentColorStyle.greenLight),
                const SizedBox(width: 6),
                Text(
                  plan.saving,
                  style: PaymentColorStyle.captionStyle.copyWith(
                    color:      PaymentColorStyle.greenLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: PaymentColorStyle.borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 15, color: PaymentColorStyle.bodyText),
              const SizedBox(width: 8),
              Text(
                'via ${_method.name}',
                style: PaymentColorStyle.labelStyle.copyWith(
                  color: PaymentColorStyle.subtitleText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: PaymentColorStyle.captionStyle.copyWith(
        color:         PaymentColorStyle.bodyText,
        letterSpacing: 1.2,
        fontSize:      10,
        fontWeight:    FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: keyboardType,
      style:     const TextStyle(color: PaymentColorStyle.titleText, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: PaymentColorStyle.bodyText, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: PaymentColorStyle.bodyText),
        filled:    true,
        fillColor: PaymentColorStyle.cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.greenNeon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.errorRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    final tax   = plan.priceUSD * 0.11;
    final total = plan.priceUSD + tax;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: PaymentColorStyle.borderColor),
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', '\$${plan.priceUSD.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildPriceRow('Tax (11%)', '\$${tax.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: PaymentColorStyle.borderColor, height: 1),
          ),
          _buildPriceRow('Total', '\$${total.toStringAsFixed(2)}', highlight: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Text(
          label,
          style: PaymentColorStyle.labelStyle.copyWith(
            color:      highlight ? PaymentColorStyle.subtitleText : PaymentColorStyle.bodyText,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: highlight
              ? PaymentColorStyle.priceStyle.copyWith(
                  fontSize: 18,
                  color:    PaymentColorStyle.greenNeon,
                )
              : PaymentColorStyle.labelStyle,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: BOTTOM CTA BUTTON
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildBottomCTA({
  required String label,
  VoidCallback? onTap,
  bool isLoading = false,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    decoration: const BoxDecoration(
      color:  PaymentColorStyle.backgroundColor,
      border: Border(top: BorderSide(color: PaymentColorStyle.borderColor)),
    ),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient:     onTap != null ? PaymentColorStyle.ctaGradient : null,
          color:        onTap == null ? PaymentColorStyle.borderColor  : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    onTap != null ? PaymentColorStyle.ctaShadow    : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        PaymentColorStyle.backgroundColor),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: onTap != null
                        ? PaymentColorStyle.backgroundColor
                        : PaymentColorStyle.disabledText,
                    fontSize:      16,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final PlanInfo plan;
  const _SuccessSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      decoration: const BoxDecoration(
        color:        PaymentColorStyle.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        PaymentColorStyle.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PaymentColorStyle.greenNeon.withOpacity(0.3),
                  PaymentColorStyle.greenDark.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: PaymentColorStyle.greenNeon, width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                size: 36, color: PaymentColorStyle.greenNeon),
          ),
          const SizedBox(height: 20),
          Text('Payment initiated!',
              style: PaymentColorStyle.displayStyle,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your ${plan.label} plan is being activated.\nYou\'ll receive a confirmation email shortly.',
            style: PaymentColorStyle.labelStyle.copyWith(
              color:  PaymentColorStyle.bodyText,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient:     PaymentColorStyle.selectedPlanGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: PaymentColorStyle.greenNeon.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: PaymentColorStyle.greenNeon, size: 18),
                const SizedBox(width: 10),
                Text(
                  '${plan.label} · \$${plan.priceUSD.toStringAsFixed(0)}${plan.period}',
                  style: PaymentColorStyle.labelStyle.copyWith(
                    color: PaymentColorStyle.greenNeon,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context)
              ..pop()
              ..pop(),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient:     PaymentColorStyle.ctaGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow:    PaymentColorStyle.ctaShadow,
              ),
              child: Center(
                child: Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    color:      PaymentColorStyle.backgroundColor,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}