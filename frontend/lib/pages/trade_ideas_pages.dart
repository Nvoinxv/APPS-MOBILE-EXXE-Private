import 'package:flutter/material.dart';
import '../hooks/trade_ideas_hook.dart';
import '../style/apps_colors_trade_ideas.dart';
import '../postingan/trade_ideas_postingan.dart';
import '../utils/role_guard.dart';
 
class TradeIdeasSection extends StatefulWidget {
  final String token;
 
  const TradeIdeasSection({
    super.key,
    required this.token,
  });
 
  @override
  State<TradeIdeasSection> createState() => _TradeIdeasSectionState();
}
 
class _TradeIdeasSectionState extends State<TradeIdeasSection> {
  List<Map<String, dynamic>> tradeIdeasList    = [];
  List<Map<String, dynamic>> filteredTradeIdeas = [];
  bool isLoading = true;
 
  final TextEditingController _searchController = TextEditingController();
 
  late final RolePermission _perm;
 
  @override
  void initState() {
    super.initState();
    _perm = RolePermission.of(widget.token);
    _searchController.addListener(_filterTradeIdeas);
    if (_perm.canView) _loadData();
  }
 
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
 
  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final result = await Trade_Ideas_Hook.GetAllTradeIdeas(
        token: widget.token,
      );
      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) {
          setState(() {
            tradeIdeasList = data.map((item) {
              return item is Map<String, dynamic> ? item : <String, dynamic>{};
            }).toList();
            filteredTradeIdeas = tradeIdeasList;
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading trade ideas: $e');
      setState(() => isLoading = false);
    }
  }
 
  void _filterTradeIdeas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredTradeIdeas = query.isEmpty
          ? tradeIdeasList
          : tradeIdeasList.where((trade) {
              final tradeIdea = (trade['Trade_idea'] ?? '').toString().toLowerCase();
              final tipeTrade = (trade['Tipe_trade'] ?? '').toString().toLowerCase();
              final aktivasi  = (trade['Aktivasi']   ?? '').toString().toLowerCase();
              return tradeIdea.contains(query) ||
                  tipeTrade.contains(query) ||
                  aktivasi.contains(query);
            }).toList();
    });
  }
 
  @override
  Widget build(BuildContext context) {
    // ── GENERAL → centered lock banner ───────────────────────────────────────
    if (_perm.isGeneral) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header tetap ada tapi tanpa controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: _buildHeaderLocked(),
          ),
          const SizedBox(height: 48),
          // Banner center + constrained width
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionLockBanner(
                  sectionName: 'Trade Ideas',
                  token: widget.token,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      );
    }
 
    // ── ADMIN / EXCLUSIVE → konten penuh ─────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(showControls: true),
        const SizedBox(height: 32),
        if (isLoading)
          SizedBox(
            height: 400,
            child: Center(
              child: CircularProgressIndicator(
                color:       TradeIdeasColorStyle.greenNeon,
                strokeWidth: 3,
              ),
            ),
          )
        else if (filteredTradeIdeas.isEmpty)
          _buildEmptyState()
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: filteredTradeIdeas.map((trade) {
                return _TradeIdeaCard(
                  tradeData: trade,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostinganTradeIdeasScreen(tradeIdeasData: trade),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
 
  // ─── Header untuk general (locked) — simpler, no controls ─────────────────
  Widget _buildHeaderLocked() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TradeIdeasColorStyle.greenNeon.withOpacity(0.2),
                TradeIdeasColorStyle.greenNeon.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TradeIdeasColorStyle.greenNeon.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.show_chart,
              color: TradeIdeasColorStyle.greenNeon, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trade Ideas',
                style: TradeIdeasColorStyle.sectionTitleStyle),
            const SizedBox(height: 4),
            Text(
              'Actionable setups & market execution plans',
              style: TextStyle(
                color:      TradeIdeasColorStyle.searchPlaceholder
                    .withOpacity(0.5),
                fontSize:   14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader({required bool showControls}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TradeIdeasColorStyle.greenNeon.withOpacity(0.2),
                      TradeIdeasColorStyle.greenNeon.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TradeIdeasColorStyle.greenNeon.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.show_chart,
                    color: TradeIdeasColorStyle.greenNeon, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trade Ideas',
                      style: TradeIdeasColorStyle.sectionTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    'Actionable setups & market execution plans',
                    style: TextStyle(
                      color:      TradeIdeasColorStyle.searchPlaceholder
                          .withOpacity(0.5),
                      fontSize:   14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
 
          if (showControls)
            Row(
              children: [
                _buildSearchBar(),
                const SizedBox(width: 16),
                UploadGuard(
                  token: widget.token,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/upload_trade_ideas',
                        arguments: widget.token,
                      ),
                      icon:  const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Trade Idea',
                        style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TradeIdeasColorStyle.addButtonBackground,
                        foregroundColor: TradeIdeasColorStyle.addButtonText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ).copyWith(
                        overlayColor: WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            if (states.contains(WidgetState.hovered)) {
                              return Colors.black.withOpacity(0.1);
                            }
                            if (states.contains(WidgetState.pressed)) {
                              return Colors.black.withOpacity(0.2);
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
 
  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart,
                size:  64,
                color: TradeIdeasColorStyle.subtitleText.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No trade ideas available',
              style: TextStyle(
                  color:      TradeIdeasColorStyle.subtitleText,
                  fontSize:   16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _perm.isAdmin
                  ? 'Click "Add Trade Idea" to publish your first setup'
                  : 'Belum ada trade ideas tersedia, coba lagi nanti',
              style: TextStyle(
                  color:    TradeIdeasColorStyle.sourceText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
 
  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      width: 280, height: 44,
      decoration: tradeIdeasCardTheme.searchBarDecoration(
          isFocused: _searchController.text.isNotEmpty),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
            color: TradeIdeasColorStyle.searchText, fontSize: 14),
        decoration: InputDecoration(
          hintText:  'Search trade ideas...',
          hintStyle: const TextStyle(
              color: TradeIdeasColorStyle.searchPlaceholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: TradeIdeasColorStyle.searchPlaceholder, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: TradeIdeasColorStyle.searchPlaceholder, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}


/// ✅ CARD DESIGN - Timeline/Feed Layout
class _TradeIdeaCard extends StatefulWidget {
  final Map<String, dynamic> tradeData;
  final VoidCallback onTap;

  const _TradeIdeaCard({
    required this.tradeData,
    required this.onTap,
  });

  @override
  State<_TradeIdeaCard> createState() => _TradeIdeaCardState();
}

class _TradeIdeaCardState extends State<_TradeIdeaCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tradeIdea = widget.tradeData['Trade_idea']?.toString() ?? 
                      widget.tradeData['trade_idea']?.toString() ?? 
                      'No Trade Idea';
    
    final tipeTrade = widget.tradeData['Tipe_trade']?.toString() ?? 
                      widget.tradeData['tipe_trade']?.toString() ?? 
                      'Unknown Type';
    
    final aktivasi = widget.tradeData['Aktivasi']?.toString() ?? 
                     widget.tradeData['aktivasi']?.toString() ?? 
                     '';
    
    final date = widget.tradeData['Date']?.toString() ?? 
                 widget.tradeData['date']?.toString() ?? 
                 '';
    
    final entry = widget.tradeData['Entry']?.toString() ?? 
                  widget.tradeData['entry']?.toString() ?? 
                  '0';
    
    final stoploss = widget.tradeData['Stoploss']?.toString() ?? 
                     widget.tradeData['stoploss']?.toString() ?? 
                     '0';
    
    final target = widget.tradeData['Target']?.toString() ?? 
                   widget.tradeData['target']?.toString() ?? 
                   '0';
    
    final status = widget.tradeData['Status']?.toString() ?? 
                   widget.tradeData['status']?.toString() ?? 
                   'false';
    
    final uploader = widget.tradeData['uploader']?.toString() ?? 
                     widget.tradeData['Uploader']?.toString() ?? 
                     'Admin';
    
    final isBuy = tipeTrade.toUpperCase().contains('BUY');
    final tradeColor = isBuy ? TradeIdeasColorStyle.greenNeon : Colors.redAccent;
    
    final entryValue = double.tryParse(entry) ?? 0;
    final stoplossValue = double.tryParse(stoploss) ?? 0;
    final targetValue = double.tryParse(target) ?? 0;
    final risk = (entryValue - stoplossValue).abs();
    final reward = (targetValue - entryValue).abs();
    final rrRatio = risk > 0 ? reward / risk : 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(0.0, isHovered ? -4.0 : 0.0),
            decoration: BoxDecoration(
              gradient: TradeIdeasColorStyle.tradeIdeasCardGradient1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered 
                    ? TradeIdeasColorStyle.greenNeon.withOpacity(0.3)
                    : TradeIdeasColorStyle.searchBorder,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: TradeIdeasColorStyle.greenNeon.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 35,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: Container(
                      height: 280,
                      color: TradeIdeasColorStyle.cardBackground,
                      child: CustomPaint(
                        painter: _TradeChartPainter(
                          entry: entryValue,
                          stoploss: stoplossValue,
                          target: targetValue,
                          isBuy: isBuy,
                        ),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 65,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: tradeIdeasCardTheme.tradeIdeasBadgeDecoration(),
                                  child: Text(
                                    'TRADE IDEAS',
                                    style: TradeIdeasColorStyle.badgeTextStyle,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status.toLowerCase() == 'true' || status == '1'
                                        ? TradeIdeasColorStyle.greenPrimary.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: status.toLowerCase() == 'true' || status == '1'
                                          ? TradeIdeasColorStyle.greenPrimary
                                          : Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        status.toLowerCase() == 'true' || status == '1'
                                            ? Icons.check_circle
                                            : Icons.pending,
                                        size: 12,
                                        color: status.toLowerCase() == 'true' || status == '1'
                                            ? TradeIdeasColorStyle.greenPrimary
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        status.toLowerCase() == 'true' || status == '1' 
                                            ? 'ACTIVE' 
                                            : 'CLOSED',
                                        style: TextStyle(
                                          color: status.toLowerCase() == 'true' || status == '1'
                                              ? TradeIdeasColorStyle.greenPrimary
                                              : Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tradeColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: tradeColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tipeTrade.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Text(
                              tradeIdea,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            if (aktivasi.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: TradeIdeasColorStyle.greenNeon.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_active_outlined,
                                      size: 14,
                                      color: TradeIdeasColorStyle.greenNeon.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      aktivasi,
                                      style: TextStyle(
                                        color: TradeIdeasColorStyle.greenNeon.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 20),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniParameter(
                                    icon: Icons.login,
                                    label: 'Entry',
                                    value: _formatPrice(entry),
                                    color: TradeIdeasColorStyle.greenNeon,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniParameter(
                                    icon: Icons.flag_outlined,
                                    label: 'Target',
                                    value: _formatPrice(target),
                                    color: Colors.amberAccent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniParameter(
                                    icon: Icons.shield_outlined,
                                    label: 'Stop',
                                    value: _formatPrice(stoploss),
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: TradeIdeasColorStyle.greenNeon.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pie_chart_outline,
                                        size: 16,
                                        color: TradeIdeasColorStyle.greenNeon,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'R:R Ratio',
                                        style: TextStyle(
                                          color: TradeIdeasColorStyle.subtitleText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '1:${rrRatio.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        rrRatio >= 2 
                                            ? Icons.check_circle
                                            : rrRatio >= 1.5
                                                ? Icons.warning_amber
                                                : Icons.error,
                                        size: 16,
                                        color: rrRatio >= 2 
                                            ? TradeIdeasColorStyle.greenNeon
                                            : rrRatio >= 1.5
                                                ? Colors.amber
                                                : Colors.redAccent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: TradeIdeasColorStyle.greenNeon.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: TradeIdeasColorStyle.greenNeon,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  uploader,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                if (date.isNotEmpty) ...[
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: TradeIdeasColorStyle.sourceText,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(date),
                                    style: const TextStyle(
                                      color: TradeIdeasColorStyle.sourceText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'View full setup',
                              style: TextStyle(
                                color: TradeIdeasColorStyle.greenNeon,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: TradeIdeasColorStyle.greenNeon,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniParameter({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: TradeIdeasColorStyle.sourceText,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatPrice(String price) {
    try {
      final value = double.parse(price);
      if (value >= 1000) {
        return value.toStringAsFixed(2);
      } else if (value >= 1) {
        return value.toStringAsFixed(4);
      } else {
        return value.toStringAsFixed(6);
      }
    } catch (e) {
      return price;
    }
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parsedDate = DateTime.parse(date);
      final now = DateTime.now();
      final difference = now.difference(parsedDate);
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
      }
    } catch (e) {
      return date;
    }
  }
}

/// ✅ CHART PAINTER
class _TradeChartPainter extends CustomPainter {
  final double entry;
  final double stoploss;
  final double target;
  final bool isBuy;

  _TradeChartPainter({
    required this.entry,
    required this.stoploss,
    required this.target,
    required this.isBuy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = TradeIdeasColorStyle.searchBorder.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final x = (size.width / 4) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxPrice = [entry, stoploss, target].reduce((a, b) => a > b ? a : b);
    final minPrice = [entry, stoploss, target].reduce((a, b) => a < b ? a : b);
    final priceRange = maxPrice - minPrice;

    double getY(double price) {
      if (priceRange == 0) return size.height * 0.5;
      return size.height - ((price - minPrice) / priceRange * size.height * 0.8) - size.height * 0.1;
    }

    final candleWidth = size.width / 10;
    for (int i = 0; i < 9; i++) {
      final x = candleWidth * i + candleWidth / 2;
      final baseY = getY(entry);
      final variation = (i * 15 % 40 - 20).toDouble();
      
      canvas.drawLine(
        Offset(x, baseY - 20 + variation),
        Offset(x, baseY + 20 + variation),
        Paint()
          ..color = i % 2 == 0 
              ? TradeIdeasColorStyle.greenLight.withOpacity(0.6)
              : Colors.redAccent.withOpacity(0.6)
          ..strokeWidth = 1.5,
      );
      
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, baseY + variation),
          width: 6,
          height: 16,
        ),
        Paint()
          ..color = i % 2 == 0 
              ? TradeIdeasColorStyle.greenPrimary
              : Colors.red.shade700
          ..style = PaintingStyle.fill,
      );
    }

    final entryY = getY(entry);
    _drawDashedLine(canvas, Offset(0, entryY), Offset(size.width, entryY),
        TradeIdeasColorStyle.greenPrimary, 2);

    final targetY = getY(target);
    _drawDashedLine(canvas, Offset(0, targetY), Offset(size.width, targetY),
        TradeIdeasColorStyle.greenLight, 1.5);

    final slY = getY(stoploss);
    _drawDashedLine(canvas, Offset(0, slY), Offset(size.width, slY),
        Colors.redAccent, 1.5);

    final profitPath = Path()
      ..moveTo(0, entryY)
      ..lineTo(size.width, entryY)
      ..lineTo(size.width, targetY)
      ..lineTo(0, targetY)
      ..close();
    canvas.drawPath(profitPath, Paint()
      ..color = TradeIdeasColorStyle.greenPrimary.withOpacity(0.15)
      ..style = PaintingStyle.fill);

    final riskPath = Path()
      ..moveTo(0, entryY)
      ..lineTo(size.width, entryY)
      ..lineTo(size.width, slY)
      ..lineTo(0, slY)
      ..close();
    canvas.drawPath(riskPath, Paint()
      ..color = Colors.redAccent.withOpacity(0.1)
      ..style = PaintingStyle.fill);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end,
      Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double distance = (end - start).distance;
    for (double i = 0; i < distance; i += dashWidth + dashSpace) {
      final x  = start.dx + (end.dx - start.dx) * (i / distance);
      final y  = start.dy + (end.dy - start.dy) * (i / distance);
      final x2 = start.dx + (end.dx - start.dx) * ((i + dashWidth) / distance);
      final y2 = start.dy + (end.dy - start.dy) * ((i + dashWidth) / distance);
      canvas.drawLine(Offset(x, y), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}