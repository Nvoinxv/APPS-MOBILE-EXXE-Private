// ============================================================
// FILE: lib/pages/payment_pages.dart
// ============================================================
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style/app_colors_payment.dart';
import '../hooks/payment_gate_way_hook.dart';

// ─────────────────────────────
// DATA MODELS
// ─────────────────────────────
enum PlanType { monthly, semiAnnual, annual }

class PlanInfo {
  final PlanType type;
  final String label;
  final String planKey;
  final double priceUsdt;
  final double? originalUsdt;
  final String period;
  final String? badge;
  final String saving;
  final List<String> features;

  const PlanInfo({
    required this.type,
    required this.label,
    required this.planKey,
    required this.priceUsdt,
    this.originalUsdt,
    required this.period,
    this.badge,
    required this.saving,
    required this.features,
  });
}

const List<PlanInfo> kPlans = [
  PlanInfo(
    type:      PlanType.monthly,
    label:     '1 Month',
    planKey:   'monthly',
    priceUsdt: 65,
    period:    '/mo',
    saving:    '',
    features: [
      'Full market access',
      'Real-time StreetView data',
      'Basic alerts',
    ],
  ),
  PlanInfo(
    type:         PlanType.semiAnnual,
    label:        '6 Months',
    planKey:      'semi_annual',
    priceUsdt:    250,
    originalUsdt: 390,
    period:       '/6mo',
    badge:        'SAVE 36%',
    saving:       'Save 140 USDT',
    features: [
      'Full market access',
      'Real-time StreetView data',
      'Advanced alerts',
      'Portfolio tracker',
    ],
  ),
  PlanInfo(
    type:         PlanType.annual,
    label:        '1 Year',
    planKey:      'annual',
    priceUsdt:    375,
    originalUsdt: 780,
    period:       '/yr',
    badge:        'BEST VALUE',
    saving:       'Save 405 USDT',
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
// WALLET VALIDATOR
// ─────────────────────────────
bool _isValidEvmWallet(String address) {
  final regex = RegExp(r'^0x[0-9a-fA-F]{40}$');
  return regex.hasMatch(address);
}

// ─────────────────────────────
// MAIN PAGE
// ─────────────────────────────
class PaymentPage extends StatefulWidget {
  final String token;
  const PaymentPage({Key? key, required this.token}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with TickerProviderStateMixin {
  PlanType _selectedPlan = PlanType.semiAnnual;
  bool     _isLoading    = false;
  int      _currentStep  = 0;

  final _walletCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  PlanInfo get _plan => kPlans.firstWhere((p) => p.type == _selectedPlan);

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
      _fadeCtrl..reset()..forward();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _fadeCtrl..reset()..forward();
    }
  }

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await Payment_Hook.CheckoutPayment(
      userWallet: _walletCtrl.text.trim(),
      planType:   _plan.planKey,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      showModalBottomSheet(
        context:            context,
        backgroundColor:    Colors.transparent,
        isScrollControlled: true,
        isDismissible:      false,
        enableDrag:         false,
        builder: (_) => _CryptoPaymentSheet(
          checkoutData: result['data'] as Map<String, dynamic>,
          planLabel:    _plan.label,
        ),
      );
    } else {
      final msg = result['message'] ?? result['error'] ?? 'Checkout gagal.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(msg as String),
          backgroundColor: PaymentColorStyle.errorRed,
          behavior:        SnackBarBehavior.floating,
        ),
      );
    }
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
          color:        PaymentColorStyle.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: PaymentColorStyle.borderColor),
        ),
        child: Icon(
          isBack ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
          size:  isBack ? 16 : 18,
          color: PaymentColorStyle.subtitleText,
        ),
      ),
    );
  }

  Widget _buildSecureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.greenDim,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: PaymentColorStyle.greenNeon, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('SECURE', style: PaymentColorStyle.greenBadgeStyle),
        ],
      ),
    );
  }

  String _stepLabel() => _currentStep == 0
      ? 'Step 1 — Choose your plan'
      : 'Step 2 — Confirm & pay';

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: List.generate(2, (i) {
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
                                color:      PaymentColorStyle.greenNeon.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (i < 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _PlanStep(
        selectedPlan:   _selectedPlan,
        onPlanSelected: (p) => setState(() => _selectedPlan = p),
        onNext:         _nextStep,
      );
    }
    return _SummaryStep(
      plan:       _plan,
      walletCtrl: _walletCtrl,
      formKey:    _formKey,
      isLoading:  _isLoading,
      onPay:      _handleCheckout,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — PLAN SELECTION
// FIX: CTA masuk ListView sebagai item terakhir — tidak ada Column 2-children
//      lagi, jadi tidak ada overflow di layar kecil / desktop window kecil.
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      children: [
        Text('Choose your plan', style: PaymentColorStyle.displayStyle),
        const SizedBox(height: 4),
        Text(
          'Unlock full access to StreetView Investing',
          style: PaymentColorStyle.labelStyle,
        ),
        const SizedBox(height: 20),
        _buildNetworkBadge(),
        const SizedBox(height: 16),
        ...kPlans.map((plan) => _PlanCard(
          plan:       plan,
          isSelected: selectedPlan == plan.type,
          onTap:      () => onPlanSelected(plan.type),
        )),
        const SizedBox(height: 16),
        _buildGuaranteeNote(),
        const SizedBox(height: 16),
        // ── CTA di dalam ListView — tidak pernah overflow ──
        _buildBottomCTA(label: 'Continue to Payment', onTap: onNext),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNetworkBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF1A1200),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3BA2F).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFF3BA2F), shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('B', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payment via USDT · BNB Smart Chain (BEP-20)',
              style: PaymentColorStyle.captionStyle.copyWith(
                color: const Color(0xFFF3BA2F),
              ),
            ),
          ),
          const Icon(Icons.lock_rounded,
              size: 13, color: Color(0xFFF3BA2F)),
        ],
      ),
    );
  }

  Widget _buildGuaranteeNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.greenDim,
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
        margin:   const EdgeInsets.only(bottom: 12),
        padding:  const EdgeInsets.all(18),
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
                  '${plan.priceUsdt.toStringAsFixed(0)} USDT',
                  style: PaymentColorStyle.priceStyle.copyWith(
                    color: isSelected
                        ? PaymentColorStyle.greenNeon
                        : PaymentColorStyle.titleText,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(plan.period,
                      style: PaymentColorStyle.pricePeriodStyle),
                ),
                if (plan.originalUsdt != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${plan.originalUsdt!.toStringAsFixed(0)}',
                    style: PaymentColorStyle.captionStyle.copyWith(
                      decoration:      TextDecoration.lineThrough,
                      decorationColor: PaymentColorStyle.bodyText,
                    ),
                  ),
                ],
                const Spacer(),
                if (plan.saving.isNotEmpty)
                  Text(
                    plan.saving,
                    style: PaymentColorStyle.captionStyle.copyWith(
                      color:      PaymentColorStyle.greenLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: PaymentColorStyle.borderColor, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 6,
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
          size:  12,
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
// STEP 2 — SUMMARY & CONFIRM
// FIX: sama seperti _PlanStep — CTA ada di dalam ListView langsung.
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStep extends StatelessWidget {
  final PlanInfo plan;
  final TextEditingController walletCtrl;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onPay;

  const _SummaryStep({
    required this.plan,
    required this.walletCtrl,
    required this.formKey,
    required this.isLoading,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        children: [
          Text('Confirm order', style: PaymentColorStyle.displayStyle),
          const SizedBox(height: 4),
          Text(
            'Enter your wallet to generate payment address',
            style: PaymentColorStyle.labelStyle,
          ),
          const SizedBox(height: 24),
          _buildOrderCard(),
          const SizedBox(height: 20),
          _buildSectionLabel('Your Wallet Address'),
          const SizedBox(height: 10),
          _buildWalletField(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Must be an EVM-compatible wallet (MetaMask, Trust Wallet, etc.)',
              style: PaymentColorStyle.captionStyle.copyWith(
                color: PaymentColorStyle.bodyText,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPaymentSummary(),
          const SizedBox(height: 12),
          _buildCryptoNote(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 11, color: PaymentColorStyle.bodyText),
              const SizedBox(width: 5),
              Text(
                'Verified on-chain · No account needed',
                style: PaymentColorStyle.captionStyle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── CTA di dalam ListView ──
          _buildBottomCTA(
            label: isLoading
                ? 'Generating address...'
                : 'Pay ${plan.priceUsdt.toStringAsFixed(0)} USDT',
            onTap:     isLoading ? null : onPay,
            isLoading: isLoading,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWalletField() {
    return TextFormField(
      controller: walletCtrl,
      style: const TextStyle(
        color: PaymentColorStyle.titleText,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Wallet address required';
        if (!_isValidEvmWallet(v.trim())) {
          return 'Format tidak valid. Contoh: 0x1a2b...3c4d';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: '0x...',
        hintStyle: const TextStyle(
          color: PaymentColorStyle.bodyText,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        prefixIcon: const Icon(
          Icons.account_balance_wallet_outlined,
          size: 18, color: PaymentColorStyle.bodyText,
        ),
        suffixIcon: GestureDetector(
          onTap: () async {
            final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
            if (clipboard?.text != null) {
              walletCtrl.text = clipboard!.text!.trim();
            }
          },
          child: Container(
            margin:  const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:        PaymentColorStyle.borderColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              'Paste',
              style: PaymentColorStyle.captionStyle.copyWith(
                color: PaymentColorStyle.subtitleText,
              ),
            ),
          ),
        ),
        filled:    true,
        fillColor: PaymentColorStyle.cardBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(
              color: PaymentColorStyle.greenNeon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PaymentColorStyle.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: PaymentColorStyle.errorRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:     PaymentColorStyle.selectedPlanGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.3)),
        boxShadow: PaymentColorStyle.selectedCardShadow,
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
                '${plan.priceUsdt.toStringAsFixed(0)} USDT${plan.period}',
                style: PaymentColorStyle.priceStyle.copyWith(
                  fontSize: 18, color: PaymentColorStyle.greenNeon,
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
              Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3BA2F), shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('B', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.black,
                  )),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'via USDT · BNB Smart Chain',
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

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentColorStyle.borderColor),
      ),
      child: Column(
        children: [
          _buildPriceRow('Plan',    '${plan.priceUsdt.toStringAsFixed(0)} USDT'),
          const SizedBox(height: 8),
          _buildPriceRow('Network', 'BEP-20'),
          const SizedBox(height: 8),
          _buildPriceRow('Gas fee', '~0.05 BNB (paid by sender)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: PaymentColorStyle.borderColor, height: 1),
          ),
          _buildPriceRow(
            'Total', '${plan.priceUsdt.toStringAsFixed(0)} USDT',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFF0D1A0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaymentColorStyle.greenNeon.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: PaymentColorStyle.greenNeon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A payment address will be generated. Send the EXACT USDT amount '
              'from your registered wallet within 60 minutes.',
              style: PaymentColorStyle.captionStyle.copyWith(
                color: PaymentColorStyle.greenLight, height: 1.5,
              ),
            ),
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

  Widget _buildPriceRow(String label, String value,
      {bool highlight = false}) {
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
                  fontSize: 18, color: PaymentColorStyle.greenNeon)
              : PaymentColorStyle.labelStyle.copyWith(
                  color: PaymentColorStyle.subtitleText),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: BOTTOM CTA BUTTON
// Sekarang dipakai sebagai item biasa di dalam ListView, bukan widget terpisah
// yang di-pin di bawah. Styling tetap sama persis.
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildBottomCTA({
  required String label,
  VoidCallback? onTap,
  bool isLoading = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height:   54,
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
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CRYPTO PAYMENT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CryptoPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> checkoutData;
  final String planLabel;

  const _CryptoPaymentSheet({
    required this.checkoutData,
    required this.planLabel,
  });

  @override
  State<_CryptoPaymentSheet> createState() => _CryptoPaymentSheetState();
}

class _CryptoPaymentSheetState extends State<_CryptoPaymentSheet> {
  String  _status           = 'pending';
  String? _txHash;
  String? _txExplorer;
  String? _discordLink;
  bool    _pollingActive    = true;
  int     _remainingSeconds = 3600;

  late Timer _countdownTimer;
  late Timer _pollingTimer;

  String get _orderId       => widget.checkoutData['order_id'] as String;
  String get _walletAddress => widget.checkoutData['wallet_address'] as String;
  String get _userWallet    => widget.checkoutData['user_wallet'] as String;
  double get _amountUsdt    =>
      (widget.checkoutData['amount_usdt'] as num).toDouble();

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startPolling();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _status = 'expired';
          t.cancel();
          _stopPolling();
        }
      });
    });
  }

  void _startPolling() {
    _pollStatus();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (_pollingActive) _pollStatus(); },
    );
  }

  void _stopPolling() {
    _pollingActive = false;
    _pollingTimer.cancel();
  }

  Future<void> _pollStatus() async {
    final result = await Payment_Hook.CheckTransactionStatus(orderId: _orderId);
    if (!mounted || !_pollingActive) return;

    if (result['success'] != true) return;

    final data   = result['data'] as Map<String, dynamic>;
    final status = data['status'] as String;

    setState(() {
      _status = status;
      if (status == 'paid') {
        _txHash      = data['tx_hash'] as String?;
        _txExplorer  = data['tx_explorer'] as String?;
        _discordLink = data['discord_link'] as String?;
        _countdownTimer.cancel();
        _stopPolling();
      } else if (status == 'expired') {
        _countdownTimer.cancel();
        _stopPolling();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pollingTimer.cancel();
    super.dispose();
  }

  String get _countdownFormatted {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text('$label copied!'),
        duration:        const Duration(seconds: 1),
        backgroundColor: PaymentColorStyle.greenDark,
        behavior:        SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          20 + MediaQuery.of(context).padding.bottom,
        ),
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
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _status == 'paid'
                      ? _buildPaidContent()
                      : _status == 'expired'
                          ? _buildExpiredContent()
                          : _buildPendingContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingContent() {
    final isWarning = _remainingSeconds < 300;

    return Column(
      key: const ValueKey('pending'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Send Payment', style: PaymentColorStyle.displayStyle),
                  const SizedBox(height: 2),
                  Text(
                    'Order #$_orderId',
                    style: PaymentColorStyle.captionStyle.copyWith(
                      color: PaymentColorStyle.bodyText,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isWarning
                    ? PaymentColorStyle.errorRed.withOpacity(0.12)
                    : PaymentColorStyle.greenDim,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isWarning
                      ? PaymentColorStyle.errorRed.withOpacity(0.4)
                      : PaymentColorStyle.greenNeon.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size:  13,
                      color: isWarning
                          ? PaymentColorStyle.errorRed
                          : PaymentColorStyle.greenNeon),
                  const SizedBox(width: 5),
                  Text(
                    _countdownFormatted,
                    style: PaymentColorStyle.labelStyle.copyWith(
                      color: isWarning
                          ? PaymentColorStyle.errorRed
                          : PaymentColorStyle.greenNeon,
                      fontWeight:   FontWeight.w700,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildNetworkBadge(),
        const SizedBox(height: 10),
        _buildCopyRow(
          label:     'Amount to Send',
          value:     '${_amountUsdt.toStringAsFixed(0)} USDT',
          copyValue: _amountUsdt.toStringAsFixed(0),
          icon:      Icons.paid_outlined,
          highlight: true,
        ),
        const SizedBox(height: 8),
        _buildCopyRow(
          label:     'Send To (Business Wallet)',
          value:     _walletAddress,
          copyValue: _walletAddress,
          icon:      Icons.account_balance_wallet_outlined,
          truncate:  true,
        ),
        const SizedBox(height: 8),
        _buildUserWalletTile(),
        const SizedBox(height: 14),
        _buildWarningNote(),
        const SizedBox(height: 14),
        _buildPollingIndicator(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNetworkBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF1A1200),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3BA2F).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF3BA2F), shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('B', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BNB Smart Chain · BEP-20',
                  style: PaymentColorStyle.labelStyle.copyWith(
                    color: const Color(0xFFF3BA2F), fontWeight: FontWeight.w600,
                  )),
              Text('USDT Token', style: PaymentColorStyle.captionStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserWalletTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaymentColorStyle.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded,
              size: 16, color: PaymentColorStyle.bodyText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send From (Your Wallet)',
                  style: PaymentColorStyle.captionStyle.copyWith(
                    color: PaymentColorStyle.bodyText, fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_userWallet.substring(0, 8)}...${_userWallet.substring(_userWallet.length - 6)}',
                  style: PaymentColorStyle.labelStyle.copyWith(
                    color: PaymentColorStyle.subtitleText, fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline_rounded,
              size: 15, color: PaymentColorStyle.greenNeon),
        ],
      ),
    );
  }

  Widget _buildWarningNote() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:        PaymentColorStyle.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: PaymentColorStyle.errorRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: PaymentColorStyle.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Send EXACT amount from your registered wallet only.',
              style: PaymentColorStyle.captionStyle.copyWith(
                color: PaymentColorStyle.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 11, height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
                PaymentColorStyle.greenNeon.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Listening for your transaction...',
          style: PaymentColorStyle.captionStyle.copyWith(
            color: PaymentColorStyle.bodyText,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidContent() {
    return Column(
      key: const ValueKey('paid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                PaymentColorStyle.greenNeon.withOpacity(0.3),
                PaymentColorStyle.greenDark.withOpacity(0.1),
              ]),
              border: Border.all(color: PaymentColorStyle.greenNeon, width: 1.5),
            ),
            child: const Icon(Icons.check_rounded,
                size: 36, color: PaymentColorStyle.greenNeon),
          ),
        ),
        const SizedBox(height: 16),
        Text('Payment Confirmed!',
            style: PaymentColorStyle.displayStyle,
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Your ${widget.planLabel} plan is now active.',
          style: PaymentColorStyle.labelStyle.copyWith(
              color: PaymentColorStyle.bodyText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (_txHash != null) ...[
          _buildInfoTile(
            icon:  Icons.receipt_long_rounded,
            label: 'TX Hash',
            value: '${_txHash!.substring(0, 10)}...${_txHash!.substring(_txHash!.length - 6)}',
            onTap: _txExplorer != null
                ? () => _copy(_txExplorer!, 'Explorer link')
                : null,
          ),
          const SizedBox(height: 8),
        ],
        if (_discordLink != null) ...[
          GestureDetector(
            onTap: () => _copy(_discordLink!, 'Discord link'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: PaymentColorStyle.selectedPlanGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: PaymentColorStyle.greenNeon.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.discord,
                      size: 18, color: PaymentColorStyle.greenNeon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Join Discord Community',
                        style: PaymentColorStyle.labelStyle.copyWith(
                          color: PaymentColorStyle.greenNeon,
                        )),
                  ),
                  const Icon(Icons.copy_rounded,
                      size: 13, color: PaymentColorStyle.greenNeon),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        GestureDetector(
          onTap: () => Navigator.of(context)..pop()..pop(),
          child: Container(
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExpiredContent() {
    return Column(
      key: const ValueKey('expired'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PaymentColorStyle.errorRed.withOpacity(0.1),
              border: Border.all(
                  color: PaymentColorStyle.errorRed.withOpacity(0.4)),
            ),
            child: const Icon(Icons.timer_off_rounded,
                size: 30, color: PaymentColorStyle.errorRed),
          ),
        ),
        const SizedBox(height: 16),
        Text('Order Expired',
            style: PaymentColorStyle.displayStyle,
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Payment window has closed.\nPlease start a new checkout.',
          style: PaymentColorStyle.labelStyle.copyWith(
            color: PaymentColorStyle.bodyText, height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color:        PaymentColorStyle.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PaymentColorStyle.borderColor),
            ),
            child: Center(
              child: Text(
                'Try Again',
                style: PaymentColorStyle.labelStyle.copyWith(
                  color:      PaymentColorStyle.subtitleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCopyRow({
    required String label,
    required String value,
    required String copyValue,
    required IconData icon,
    bool highlight = false,
    bool truncate  = false,
  }) {
    final display = truncate && value.length > 20
        ? '${value.substring(0, 8)}...${value.substring(value.length - 6)}'
        : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? PaymentColorStyle.greenDim
            : PaymentColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? PaymentColorStyle.greenNeon.withOpacity(0.3)
              : PaymentColorStyle.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size:  16,
              color: highlight
                  ? PaymentColorStyle.greenNeon
                  : PaymentColorStyle.bodyText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: PaymentColorStyle.captionStyle.copyWith(
                      color: PaymentColorStyle.bodyText, fontSize: 10,
                    )),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: PaymentColorStyle.labelStyle.copyWith(
                    color:      highlight
                        ? PaymentColorStyle.greenNeon
                        : PaymentColorStyle.titleText,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copy(copyValue, label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        PaymentColorStyle.borderColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded,
                      size: 12, color: PaymentColorStyle.subtitleText),
                  const SizedBox(width: 4),
                  Text('Copy',
                      style: PaymentColorStyle.captionStyle.copyWith(
                        color: PaymentColorStyle.subtitleText,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        PaymentColorStyle.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PaymentColorStyle.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: PaymentColorStyle.bodyText),
            const SizedBox(width: 8),
            Text(label,
                style: PaymentColorStyle.captionStyle.copyWith(
                  color: PaymentColorStyle.bodyText,
                )),
            const Spacer(),
            Text(value,
                style: PaymentColorStyle.labelStyle.copyWith(
                  color: PaymentColorStyle.subtitleText,
                )),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded,
                  size: 12, color: PaymentColorStyle.bodyText),
            ],
          ],
        ),
      ),
    );
  }
}