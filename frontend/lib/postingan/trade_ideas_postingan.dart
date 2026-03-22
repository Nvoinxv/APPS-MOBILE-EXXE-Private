import 'package:flutter/material.dart';
import '../style/apps_colors_trade_ideas.dart';
import 'package:url_launcher/url_launcher.dart';

class PostinganTradeIdeasScreen extends StatefulWidget {
  final Map<String, dynamic> tradeIdeasData;
  
  const PostinganTradeIdeasScreen({
    super.key,
    required this.tradeIdeasData,
  });
  
  @override
  State<PostinganTradeIdeasScreen> createState() => _PostinganTradeIdeasScreenState();
}

class _PostinganTradeIdeasScreenState extends State<PostinganTradeIdeasScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOpacity = 0.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Debug print untuk melihat data yang diterima
    print("📊 PostinganTradeIdeasScreen - Data Received:");
    print(widget.tradeIdeasData);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _scrollOpacity = (offset / 200).clamp(0.0, 1.0);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Extract data dari Trade Ideas
    final tradeIdea = widget.tradeIdeasData['Trade_idea']?.toString() ?? 
                      widget.tradeIdeasData['trade_idea']?.toString() ?? 
                      'No Trade Idea';
    
    final tipeTrade = widget.tradeIdeasData['Tipe_trade']?.toString() ?? 
                      widget.tradeIdeasData['tipe_trade']?.toString() ?? 
                      'Unknown Type';
    
    final aktivasi = widget.tradeIdeasData['Aktivasi']?.toString() ?? 
                     widget.tradeIdeasData['aktivasi']?.toString() ?? 
                     '';
    
    final date = widget.tradeIdeasData['Date']?.toString() ?? 
                 widget.tradeIdeasData['date']?.toString() ?? 
                 '';
    
    final entry = widget.tradeIdeasData['Entry']?.toString() ?? 
                  widget.tradeIdeasData['entry']?.toString() ?? 
                  '0';
    
    final stoploss = widget.tradeIdeasData['Stoploss']?.toString() ?? 
                     widget.tradeIdeasData['stoploss']?.toString() ?? 
                     '0';
    
    final target = widget.tradeIdeasData['Target']?.toString() ?? 
                   widget.tradeIdeasData['target']?.toString() ?? 
                   '0';
    
    final status = widget.tradeIdeasData['Status']?.toString() ?? 
                   widget.tradeIdeasData['status']?.toString() ?? 
                   'false';
    
    final uploader = widget.tradeIdeasData['uploader']?.toString() ?? 
                     widget.tradeIdeasData['Uploader']?.toString() ?? 
                     'Admin';
    
    final uploadDate = widget.tradeIdeasData['upload_date']?.toString() ?? 
                       widget.tradeIdeasData['created_at']?.toString() ?? 
                       date;
    
    // Determine if it's BUY or SELL based on type
    final isBuy = tipeTrade.toUpperCase().contains('BUY');
    final tradeColor = isBuy ? TradeIdeasColorStyle.greenNeon : Colors.redAccent;
    
    // Debug prints
    print("📈 Trade Idea: $tradeIdea");
    print("📊 Type: $tipeTrade");
    print("💰 Entry: $entry");
    print("🛑 Stop Loss: $stoploss");
    print("🎯 Target: $target");
    print("✅ Status: $status");
    
    return Scaffold(
      backgroundColor: TradeIdeasColorStyle.backgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Header with Trade Type Indicator
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: TradeIdeasColorStyle.backgroundColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background with Trade Type Color
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isBuy
                                ? [
                                    const Color(0xFF003311),
                                    const Color(0xFF001A0D),
                                    const Color(0xFF000A00),
                                  ]
                                : [
                                    const Color(0xFF330011),
                                    const Color(0xFF1A000D),
                                    const Color(0xFF0A0000),
                                  ],
                          ),
                        ),
                      ),
                      
                      // Chart Pattern Background (Optional)
                      Opacity(
                        opacity: 0.1,
                        child: Icon(
                          isBuy ? Icons.trending_up : Icons.trending_down,
                          size: 300,
                          color: tradeColor,
                        ),
                      ),
                      
                      // Gradient Overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xDD000000),
                            ],
                            stops: [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                      
                      // Title Overlay at Bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Trade Ideas Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: tradeIdeasCardTheme.tradeIdeasBadgeDecoration(),
                                child: Text(
                                  'TRADE IDEAS',
                                  style: TradeIdeasColorStyle.badgeTextStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Trade Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: tradeColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tradeColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tipeTrade.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Trade Idea Title
                              Text(
                                tradeIdea,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Activation Info
                              if (aktivasi.isNotEmpty)
                                Text(
                                  aktivasi,
                                  style: TextStyle(
                                    color: TradeIdeasColorStyle.greenNeon.withOpacity(0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content Section
              SliverToBoxAdapter(
                child: Container(
                  color: TradeIdeasColorStyle.backgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metadata Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: TradeIdeasColorStyle.searchBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Uploader
                            Icon(
                              Icons.person_outline,
                              size: 18,
                              color: TradeIdeasColorStyle.greenNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              uploader,
                              style: const TextStyle(
                                color: TradeIdeasColorStyle.greenNeon,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            
                            const SizedBox(width: 24),
                            
                            // Upload Date
                            if (uploadDate.isNotEmpty) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: TradeIdeasColorStyle.sourceText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(uploadDate),
                                style: const TextStyle(
                                  color: TradeIdeasColorStyle.sourceText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            
                            const Spacer(),
                            
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: status.toLowerCase() == 'true' || status == '1'
                                    ? TradeIdeasColorStyle.greenNeon.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status.toLowerCase() == 'true' || status == '1'
                                      ? TradeIdeasColorStyle.greenNeon
                                      : Colors.grey,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status.toLowerCase() == 'true' || status == '1'
                                        ? Icons.check_circle_outline
                                        : Icons.pending_outlined,
                                    size: 16,
                                    color: status.toLowerCase() == 'true' || status == '1'
                                        ? TradeIdeasColorStyle.greenNeon
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    status.toLowerCase() == 'true' || status == '1' 
                                        ? 'ACTIVE' 
                                        : 'INACTIVE',
                                    style: TextStyle(
                                      color: status.toLowerCase() == 'true' || status == '1'
                                          ? TradeIdeasColorStyle.greenNeon
                                          : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Trade Parameters Section
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Trade Setup Title
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: TradeIdeasColorStyle.greenNeon.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.analytics_outlined,
                                    color: TradeIdeasColorStyle.greenNeon,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Trade Setup',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Entry Point Card
                            _buildTradeParameterCard(
                              icon: Icons.login,
                              iconColor: TradeIdeasColorStyle.greenNeon,
                              title: 'Entry Point',
                              value: _formatPrice(entry),
                              subtitle: 'Recommended entry level',
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Stop Loss Card
                            _buildTradeParameterCard(
                              icon: Icons.shield_outlined,
                              iconColor: Colors.redAccent,
                              title: 'Stop Loss',
                              value: _formatPrice(stoploss),
                              subtitle: 'Risk management level',
                              isNegative: true,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Target Card
                            _buildTradeParameterCard(
                              icon: Icons.flag_outlined,
                              iconColor: Colors.amberAccent,
                              title: 'Target',
                              value: _formatPrice(target),
                              subtitle: 'Profit target level',
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Risk/Reward Calculation
                            _buildRiskRewardCard(
                              entry: double.tryParse(entry) ?? 0,
                              stoploss: double.tryParse(stoploss) ?? 0,
                              target: double.tryParse(target) ?? 0,
                            ),
                            
                            const SizedBox(height: 48),
                            
                            // Divider
                            Container(
                              height: 1,
                              color: TradeIdeasColorStyle.searchBorder,
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Footer Info
                            _buildFooterInfo(),
                            
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Floating Back Button (appears on scroll)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _scrollOpacity,
            child: Container(
              color: TradeIdeasColorStyle.backgroundColor.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: TradeIdeasColorStyle.greenNeon,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        tradeIdea,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTradeParameterCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    bool isNegative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: TradeIdeasColorStyle.tradeIdeasCardGradient1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TradeIdeasColorStyle.searchBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TradeIdeasColorStyle.sourceText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isNegative ? Colors.redAccent : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: TradeIdeasColorStyle.subtitleText,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRiskRewardCard({
    required double entry,
    required double stoploss,
    required double target,
  }) {
    final risk = (entry - stoploss).abs();
    final reward = (target - entry).abs();
    final rrRatio = risk > 0 ? reward / risk : 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A3A1A),
            Color(0xFF0D1F0D),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TradeIdeasColorStyle.greenNeon.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TradeIdeasColorStyle.greenNeon.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TradeIdeasColorStyle.greenNeon,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Risk/Reward Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk',
                      style: TextStyle(
                        color: TradeIdeasColorStyle.sourceText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(risk.toString()),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: TradeIdeasColorStyle.searchBorder,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reward',
                      style: TextStyle(
                        color: TradeIdeasColorStyle.sourceText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(reward.toString()),
                      style: const TextStyle(
                        color: TradeIdeasColorStyle.greenNeon,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: TradeIdeasColorStyle.searchBorder,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'R:R Ratio',
                      style: TextStyle(
                        color: TradeIdeasColorStyle.sourceText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1:${rrRatio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (rrRatio / 5).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TradeIdeasColorStyle.greenNeon,
                      TradeIdeasColorStyle.greenLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            rrRatio >= 2 
                ? '✅ Good risk/reward ratio' 
                : rrRatio >= 1.5
                    ? '⚠️ Acceptable risk/reward ratio'
                    : '❌ Poor risk/reward ratio',
            style: TextStyle(
              color: rrRatio >= 2 
                  ? TradeIdeasColorStyle.greenNeon
                  : rrRatio >= 1.5
                      ? Colors.amber
                      : Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFooterInfo() {
    final tradeIdea = widget.tradeIdeasData['Trade_idea']?.toString() ?? 
                      widget.tradeIdeasData['trade_idea']?.toString() ?? '';
    final tipeTrade = widget.tradeIdeasData['Tipe_trade']?.toString() ?? 
                      widget.tradeIdeasData['tipe_trade']?.toString() ?? '';
    final uploader = widget.tradeIdeasData['uploader']?.toString() ?? 
                     widget.tradeIdeasData['Uploader']?.toString() ?? 
                     'Admin';
    final uploadDate = widget.tradeIdeasData['upload_date']?.toString() ?? 
                       widget.tradeIdeasData['created_at']?.toString() ?? 
                       widget.tradeIdeasData['Date']?.toString() ?? '';
    final aktivasi = widget.tradeIdeasData['Aktivasi']?.toString() ?? 
                     widget.tradeIdeasData['aktivasi']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TradeIdeasColorStyle.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TradeIdeasColorStyle.searchBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TradeIdeasColorStyle.greenNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: TradeIdeasColorStyle.greenNeon,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this trade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoRow(
            icon: Icons.trending_up,
            label: 'Trade Pair',
            value: tradeIdea,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.swap_vert,
            label: 'Trade Type',
            value: tipeTrade,
          ),
          
          if (aktivasi.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.notifications_active_outlined,
              label: 'Activation',
              value: aktivasi,
            ),
          ],
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Published by',
            value: uploader,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Published on',
            value: _formatDateFull(uploadDate),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: TradeIdeasColorStyle.sourceText,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: TradeIdeasColorStyle.sourceText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: TradeIdeasColorStyle.subtitleText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
      print("❌ Error parsing date: $e");
      return date;
    }
  }
  
  String _formatDateFull(String date) {
    if (date.isEmpty) return 'Date not available';
    
    try {
      final parsedDate = DateTime.parse(date);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[parsedDate.month - 1]} ${parsedDate.day}, ${parsedDate.year}';
    } catch (e) {
      print("❌ Error parsing full date: $e");
      return date;
    }
  }
}