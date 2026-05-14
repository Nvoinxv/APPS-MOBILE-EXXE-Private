// ============================================================
// FILE: lib/utils/role_guard.dart
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Enum Role ────────────────────────────────────────────────────────────────
enum UserRole { admin, exclusive, general, unknown }

// ─── JWT Decoder ─────────────────────────────────────────────────────────────
UserRole decodeRoleFromToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return UserRole.unknown;
    String payload = parts[1];
    switch (payload.length % 4) {
      case 2: payload += '=='; break;
      case 3: payload += '=';  break;
    }
    final decoded = utf8.decode(base64Url.decode(payload));
    final Map<String, dynamic> data = json.decode(decoded);
    final role = (data['role'] as String? ?? '').toLowerCase();
    switch (role) {
      case 'admin':     return UserRole.admin;
      case 'exclusive': return UserRole.exclusive;
      case 'general':   return UserRole.general;
      default:          return UserRole.unknown;
    }
  } catch (_) {
    return UserRole.unknown;
  }
}

bool isAllowedRole(UserRole role) =>
    role == UserRole.admin || role == UserRole.exclusive;

// ─── Role Permission ─────────────────────────────────────────────────────────
class RolePermission {
  final UserRole role;
  const RolePermission._(this.role);

  factory RolePermission.of(String token) =>
      RolePermission._(decodeRoleFromToken(token));

  bool get canView     => role == UserRole.admin || role == UserRole.exclusive;
  bool get canUpload   => role == UserRole.admin;
  bool get isAdmin     => role == UserRole.admin;
  bool get isExclusive => role == UserRole.exclusive;
  bool get isGeneral   => role == UserRole.general || role == UserRole.unknown;
}

// ─── Role Guard (full page) ───────────────────────────────────────────────────
class RoleGuard extends StatelessWidget {
  final String token;
  final Widget child;
  const RoleGuard({Key? key, required this.token, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final perm = RolePermission.of(token);
    return perm.canView ? child : LockedScreen(token: token);
  }
}

// ─── Upload Guard ─────────────────────────────────────────────────────────────
class UploadGuard extends StatelessWidget {
  final String token;
  final Widget child;
  const UploadGuard({Key? key, required this.token, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) =>
      RolePermission.of(token).canUpload ? child : const SizedBox.shrink();
}

// ─── Section Lock Banner ──────────────────────────────────────────────────────
class SectionLockBanner extends StatelessWidget {
  final String sectionName;
  final String token;
  const SectionLockBanner({
    Key? key,
    required this.sectionName,
    this.token = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color green   = Color(0xFFBEFF00);
    const Color surface = Color(0xFF0F1A0F);
    const Color border  = Color(0xFF1A2E1A);

    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  green.withOpacity(0.06),
              border: Border.all(color: green.withOpacity(0.25), width: 1.5),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: green.withOpacity(0.65), size: 30),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color:        green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: green.withOpacity(0.2)),
            ),
            child: Text('EXCLUSIVE CONTENT',
                style: TextStyle(
                    color:         green.withOpacity(0.75),
                    fontSize:      10,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2)),
          ),
          const SizedBox(height: 16),
          Text(sectionName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Konten ini hanya tersedia untuk member Exclusive dan Admin.\nUpgrade akunmu untuk mengakses seluruh fitur EXXE.LAB.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (token.isNotEmpty) {
                Navigator.pushNamed(context, '/payment', arguments: token);
              } else {
                Navigator.pushNamed(context, '/login');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [green, green.withOpacity(0.85)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color:      green.withOpacity(0.2),
                      blurRadius: 16,
                      offset:     const Offset(0, 4))
                ],
              ),
              child: const Text('Upgrade ke Exclusive',
                  style: TextStyle(
                      color:         Color(0xFF080C08),
                      fontSize:      14,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Locked Screen (full page) ────────────────────────────────────────────────
class LockedScreen extends StatefulWidget {
  final String token;
  const LockedScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl, _fadeCtrl, _scanCtrl;
  late Animation<double>   _pulseAnim, _fadeAnim, _scanAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _scanAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _scanCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose(); _fadeCtrl.dispose(); _scanCtrl.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home',
          arguments: widget.token);
    }
  }

  void _goToPayment() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/payment', arguments: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    const Color bg      = Color(0xFF080C08);
    const Color green   = Color(0xFFBEFF00);
    const Color surface = Color(0xFF0F1A0F);
    const Color border  = Color(0xFF1A2E1A);

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, _) => Opacity(
          opacity: _fadeAnim.value,
          child: SafeArea(
            child: Stack(
              children: [
                // ── Scan line ─────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _scanAnim,
                  builder: (context, _) => Positioned(
                    top:  MediaQuery.of(context).size.height * _scanAnim.value,
                    left: 0, right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          green.withOpacity(0.08),
                          green.withOpacity(0.15),
                          green.withOpacity(0.08),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),

                // ── Grid background ───────────────────────────────────────────
                Positioned.fill(
                    child: CustomPaint(
                        painter: _GridPainter(color: border))),

                // ── Content ───────────────────────────────────────────────────
                Column(
                  children: [
                    // Back button — fixed, tidak ikut scroll
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color:        surface,
                              borderRadius: BorderRadius.circular(8),
                              border:       Border.all(color: border),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white54,
                                size: 16),
                          ),
                        ),
                      ),
                    ),

                    // ── FIX: ganti Center → SingleChildScrollView ────────────
                    // Center tidak bisa scroll → overflow di layar kecil.
                    // SingleChildScrollView + BouncingScrollPhysics = flex
                    // di semua ukuran layar tanpa kuning-kuning.
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ── Ikon kunci dengan pulse ──────────────────────
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => Container(
                                  width: 120, height: 120,
                                  decoration: BoxDecoration(
                                    shape:  BoxShape.circle,
                                    color:  surface,
                                    border: Border.all(
                                        color: green.withOpacity(
                                            0.3 * _pulseAnim.value),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: green.withOpacity(
                                              0.1 * _pulseAnim.value),
                                          blurRadius: 40,
                                          spreadRadius: 10)
                                    ],
                                  ),
                                  child: Icon(
                                      Icons.lock_outline_rounded,
                                      color: green.withOpacity(
                                          0.6 + 0.4 * _pulseAnim.value),
                                      size: 52),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Badge ────────────────────────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color:        green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: green.withOpacity(0.2)),
                                ),
                                child: Text('RESTRICTED ACCESS',
                                    style: TextStyle(
                                        color:         green.withOpacity(0.8),
                                        fontSize:      11,
                                        fontWeight:    FontWeight.w700,
                                        letterSpacing: 2.5)),
                              ),
                              const SizedBox(height: 20),

                              // ── Judul ────────────────────────────────────────
                              const Text('EXXE Terminal',
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontSize:   32,
                                      fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),

                              // ── Subtitle ─────────────────────────────────────
                              Text(
                                'Fitur ini hanya tersedia untuk member\nExclusive dan Admin.',
                                style: TextStyle(
                                    color:    Colors.white.withOpacity(0.4),
                                    fontSize: 15,
                                    height:   1.6),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 36),

                              // ── Feature list ─────────────────────────────────
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:        surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border),
                                ),
                                child: Column(children: [
                                  _FRow(
                                      icon:  Icons.candlestick_chart_outlined,
                                      label: 'Live Candlestick Chart',
                                      color: green),
                                  const SizedBox(height: 14),
                                  _FRow(
                                      icon:  Icons.bar_chart_rounded,
                                      label: 'Multi-Timeframe Analysis',
                                      color: green),
                                  const SizedBox(height: 14),
                                  _FRow(
                                      icon:  Icons.timeline_rounded,
                                      label: 'Risk Ratio & Fibonacci Tools',
                                      color: green),
                                  const SizedBox(height: 14),
                                  _FRow(
                                      icon:  Icons.currency_bitcoin_rounded,
                                      label: 'Top 100 Crypto Data',
                                      color: green),
                                ]),
                              ),
                              const SizedBox(height: 28),

                              // ── Tombol Upgrade ────────────────────────────────
                              SizedBox(
                                width: double.infinity,
                                child: GestureDetector(
                                  onTap: _goToPayment,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        green, green.withOpacity(0.85)
                                      ]),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                            color: green.withOpacity(0.25),
                                            blurRadius: 20,
                                            offset: const Offset(0, 6))
                                      ],
                                    ),
                                    child: const Text(
                                        'Upgrade ke Exclusive',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color:         Color(0xFF080C08),
                                            fontSize:      15,
                                            fontWeight:    FontWeight.w800,
                                            letterSpacing: 0.5)),
                                  ),
                                ),
                              ),
                            ],
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
}

// ─── Feature Row ─────────────────────────────────────────────────────────────
class _FRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _FRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16),
    ),
    const SizedBox(width: 12),
    Text(label,
        style: TextStyle(
            color:      Colors.white.withOpacity(0.7),
            fontSize:   13,
            fontWeight: FontWeight.w500)),
    const Spacer(),
    Icon(Icons.lock_outline, color: color.withOpacity(0.4), size: 14),
  ]);
}

// ─── Grid Painter ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}