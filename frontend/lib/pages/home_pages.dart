import 'package:flutter/material.dart';
import '../style/app_typography_style.dart';
import '../style/apps_colors_quant.dart';
import '../style/apps_color_news.dart';
import '../style/apps_color_daily_search.dart';
import '../screen/navbar_screen.dart';
import '../screen/radian_navbar_gta_5_screen.dart';
import '../hooks/otp_hook.dart';
import '../hooks/update_profile_hook.dart'; // ✅ untuk getProfileHook
import 'daily_research_pages.dart';
import 'news_pages.dart';
import 'quant_investing_pages.dart';
import 'trade_ideas_pages.dart';
import 'street_view_pages.dart';
import 'market_outlook_pages.dart';
import 'research_coin_pages.dart';
import 'profile_pages.dart';

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({
    super.key,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _marketOutlookScrollController = ScrollController();
  final ScrollController _quantTradeScrollController = ScrollController();

  final GlobalKey _dailyResearchKey = GlobalKey();
  final GlobalKey _newsKey = GlobalKey();
  final GlobalKey _marketOutlookKey = GlobalKey();
  final GlobalKey _streetViewKey = GlobalKey();
  final GlobalKey _quantKey = GlobalKey();
  final GlobalKey _tradeIdeasKey = GlobalKey();

  String _activeSection = 'daily_research';
  String _currentPage   = 'home';

  // ── User data ──────────────────────────────────────────────────────────────
  String  _displayName     = '';       // display_name dari DB (bisa diubah user)
  String  _username        = '';       // fallback: name dari register
  String  _email           = '';
  String  _role            = 'USER';
  String  _description     = '';       // bio user
  String? _profileImageUrl;            // URL foto profile
  bool    _isLoadingUser   = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateActiveSection);
    _marketOutlookScrollController.addListener(_updateMarketOutlookActiveSection);
    _quantTradeScrollController.addListener(_updateQuantTradeActiveSection);
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _marketOutlookScrollController.dispose();
    _quantTradeScrollController.dispose();
    super.dispose();
  }

  // ─── Load user data: prioritas GET /profile → SharedPreferences ───────────
  // Kenapa GET /profile dan bukan hanya SharedPreferences?
  // → Supaya display_name, description, profile_image_url yang sudah diupdate
  //   di ProfilePage langsung keliatan di HomeScreen saat balik.
  Future<void> _loadUserData() async {
    try {
      // Step 1: Ambil base data (email, role, name) dari SharedPreferences dulu
      // supaya UI tidak kosong selama fetch API berlangsung
      final localData = await SendOtpHook.getUserData();
      if (localData != null && mounted) {
        setState(() {
          _email       = localData['email']        ?? '';
          _role        = localData['role']         ?? 'USER';
          _username    = localData['name']         ?? _email.split('@')[0];
          _displayName = localData['display_name'] ?? '';
          _description = localData['description']  ?? '';
          _profileImageUrl = localData['profile_image_url'];
          _isLoadingUser = false;
        });
      }

      // Step 2: Fetch fresh dari GET /profile (source of truth)
      // Ini update display_name, description, photo yang mungkin baru diubah
      final serverData = await getProfileHook();
      if (serverData != null && mounted) {
        setState(() {
          _email           = serverData['email']            ?? _email;
          _role            = serverData['role']             ?? _role;
          _username        = serverData['name']             ?? _username;
          _displayName     = serverData['display_name']     ?? '';
          _description     = serverData['description']      ?? '';
          _profileImageUrl = serverData['profile_image_url'];
          _isLoadingUser   = false;
        });
      } else if (localData == null) {
        // Tidak ada data sama sekali → redirect ke login
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('[ERROR] Failed to load user data: $e');
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // ─── Nama yang ditampilkan di top bar ─────────────────────────────────────
  // Prioritas: display_name (yang bisa diubah user) → name dari register → 'User'
  String get _shownName {
    if (_displayName.trim().isNotEmpty) return _displayName.trim();
    if (_username.trim().isNotEmpty)   return _username.trim();
    return 'User';
  }

  // ─── Inisial untuk avatar ─────────────────────────────────────────────────
  String get _initials {
    final name = _shownName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Scroll listeners (tidak berubah)
  // ══════════════════════════════════════════════════════════════════════════

  void _updateActiveSection() {
    if (_currentPage != 'home') return;
    final dailyContext = _dailyResearchKey.currentContext;
    final newsContext  = _newsKey.currentContext;
    if (dailyContext != null && newsContext != null) {
      final newsObj = newsContext.findRenderObject();
      if (newsObj is RenderBox) {
        final newsPosition = newsObj.localToGlobal(Offset.zero).dy;
        if (newsPosition < 200) {
          if (_activeSection != 'news') setState(() => _activeSection = 'news');
        } else {
          if (_activeSection != 'daily_research') setState(() => _activeSection = 'daily_research');
        }
      }
    }
  }

  void _updateMarketOutlookActiveSection() {
    if (_currentPage != 'market_outlook_page') return;
    final streetViewContext = _streetViewKey.currentContext;
    if (streetViewContext != null) {
      final streetViewObj = streetViewContext.findRenderObject();
      if (streetViewObj is RenderBox) {
        final pos = streetViewObj.localToGlobal(Offset.zero).dy;
        if (pos < 200) {
          if (_activeSection != 'street_view') setState(() => _activeSection = 'street_view');
        } else {
          if (_activeSection != 'market_outlook') setState(() => _activeSection = 'market_outlook');
        }
      }
    }
  }

  void _updateQuantTradeActiveSection() {
    if (_currentPage != 'quant_trade_page') return;
    final tradeIdeasContext = _tradeIdeasKey.currentContext;
    if (tradeIdeasContext != null) {
      final tradeIdeasObj = tradeIdeasContext.findRenderObject();
      if (tradeIdeasObj is RenderBox) {
        final pos = tradeIdeasObj.localToGlobal(Offset.zero).dy;
        if (pos < 200) {
          if (_activeSection != 'trade_ideas') setState(() => _activeSection = 'trade_ideas');
        } else {
          if (_activeSection != 'quant') setState(() => _activeSection = 'quant');
        }
      }
    }
  }

  void _scrollToSection(String section) {
    if (section == 'quant' || section == 'trade_ideas') {
      if (_currentPage != 'quant_trade_page') {
        setState(() { _currentPage = 'quant_trade_page'; _activeSection = section; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _performQuantTradeScroll(section));
      } else {
        _performQuantTradeScroll(section);
      }
    } else if (section == 'market_outlook' || section == 'street_view') {
      if (_currentPage != 'market_outlook_page') {
        setState(() { _currentPage = 'market_outlook_page'; _activeSection = section; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _performMarketOutlookScroll(section));
      } else {
        _performMarketOutlookScroll(section);
      }
    } else {
      if (_currentPage != 'home') {
        setState(() { _currentPage = 'home'; _activeSection = section; });
        WidgetsBinding.instance.addPostFrameCallback((_) => _performHomeScroll(section));
      } else {
        _performHomeScroll(section);
      }
    }
  }

  void _performHomeScroll(String section) {
    final key = section == 'daily_research' ? _dailyResearchKey : _newsKey;
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  void _performMarketOutlookScroll(String section) {
    final key = section == 'market_outlook' ? _marketOutlookKey : _streetViewKey;
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  void _performQuantTradeScroll(String section) {
    final key = section == 'quant' ? _quantKey : _tradeIdeasKey;
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  void _navigateToPage(String page) {
    setState(() { _currentPage = page; _activeSection = page; });
  }

  void _handleNavigation(String section) {
    if (['daily_research','news','market_outlook','street_view','quant','trade_ideas'].contains(section)) {
      _scrollToSection(section);
    } else {
      _navigateToPage(section);
    }
  }

  Future<void> _handleLogout() async {
    await SendOtpHook.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ─── Navigate ke ProfilePage, lalu refresh data saat balik ────────────────
  // Kenapa pakai .then()?
  // → Saat user balik dari ProfilePage setelah update nama/foto,
  //   HomeScreen otomatis refresh supaya top bar langsung update.
  void _navigateToProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ProfilePage(
          token:    widget.token,
          username: _shownName,
          email:    _email,
          role:     _role,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) {
      // ✅ Refresh data setelah balik dari ProfilePage
      // Ini yang bikin nama, foto, dan deskripsi langsung update di top bar
      _loadUserData();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopLogo(),
              Expanded(child: _buildPageContent()),
              BottomNavBar(activeSection: _activeSection, onNavigate: _handleNavigation),
            ],
          ),
          RadialCircleMenu(activeSection: _activeSection, onNavigate: _handleNavigation),
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentPage) {
          case 'quant_trade_page':
      return CustomScrollView(
        controller: _quantTradeScrollController,
        physics:    const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              key:     _quantKey,
              padding: const EdgeInsets.symmetric(vertical: 40),
              color:   const Color(0xFF0A0A0A),
              child:   QuantInvestingSection(token: widget.token),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverToBoxAdapter(
            child: Container(
              key:     _tradeIdeasKey,
              padding: const EdgeInsets.symmetric(vertical: 40),
              color:   const Color(0xFF0A0A0A),
              child:   TradeIdeasSection(token: widget.token),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      );

      case 'research_coin':
        return ResearchCoinSection(token: widget.token);
      case 'market_outlook_page':
        return CustomScrollView(
          controller: _marketOutlookScrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: Container(key: _marketOutlookKey, padding: const EdgeInsets.symmetric(vertical: 40), color: const Color(0xFF0A0A0A), child: MarketOutlookSection(token: widget.token))),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
            SliverToBoxAdapter(child: Container(key: _streetViewKey, padding: const EdgeInsets.symmetric(vertical: 40), color: const Color(0xFF0A0A0A), child: CryptoStreetViewSection(token: widget.token))),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        );
      default:
        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: DailyResearchSection(key: _dailyResearchKey, token: widget.token)),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
            SliverToBoxAdapter(child: NewsSection(key: _newsKey, token: widget.token, role: _role)),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        );
    }
  }

  Widget _buildTopLogo() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLogo(),
            _buildUserProfile(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A1A), Color(0xFF0D1F0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2D5A2D).withOpacity(0.3), width: 1),
          ),
          child: Image.asset('assets/logo_exxe_no_background.png', width: 24, height: 24, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EXXE.LAB', style: TextStyle(color: Color(0xFF5FAD56), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5, height: 1)),
            const SizedBox(height: 2),
            Text('Research Portal', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1)),
          ],
        ),
      ],
    );
  }

  // ─── User Profile Button di top bar ───────────────────────────────────────
  Widget _buildUserProfile() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile': _navigateToProfile(); break;
          case 'logout':  _handleLogout();      break;
        }
      },
      // ── Popup header: nama + deskripsi + foto ──────────────────────────────
      itemBuilder: (context) => [
        // ── Header info user (non-clickable) ─────────────────────────────────
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1)),
            ),
            child: Row(
              children: [
                // Avatar kecil di popup
                _buildSmallAvatar(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shownName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_description.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _description.trim(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: 2),
                        Text(
                          _role,
                          style: const TextStyle(
                            color: Color(0xFF5FAD56),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Menu items ────────────────────────────────────────────────────────
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7), size: 18),
              const SizedBox(width: 12),
              Text('Profile', style: TextStyle(color: Colors.white.withOpacity(0.9))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Color(0xFFFF5252), size: 18),
              const SizedBox(width: 12),
              const Text('Logout', style: TextStyle(color: Color(0xFFFF5252))),
            ],
          ),
        ),
      ],
      // ── Trigger button di top bar ─────────────────────────────────────────
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar di top bar ─────────────────────────────────────────
            _buildSmallAvatar(size: 32),
            const SizedBox(width: 10),
            // ── Nama + Role ───────────────────────────────────────────────
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoadingUser
                    ? Container(
                        width: 70,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Text(
                        _shownName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                const SizedBox(height: 2),
                Text(
                  _role,
                  style: TextStyle(
                    color: const Color(0xFF5FAD56).withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Avatar kecil — dipakai di top bar dan di popup header ────────────────
  Widget _buildSmallAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF5FAD56), Color(0xFF2D5A2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5FAD56).withOpacity(0.25),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF111C11)),
        child: ClipOval(
          child: _isLoadingUser
              ? const SizedBox()
              : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  // ✅ Tampilkan foto profile kalau ada
                  ? Image.network(
                      _profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsAvatar(),
                    )
                  // Fallback: inisial
                  : _initialsAvatar(),
        ),
      ),
    );
  }

  Widget _initialsAvatar() => Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: const Color(0xFF5FAD56),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
}