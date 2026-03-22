import 'package:flutter/material.dart';
import '../hooks/crypto_data_hook.dart';
import '../style/apps_street_view_colors.dart';

class CryptoStreetViewScreen extends StatefulWidget {
  const CryptoStreetViewScreen({super.key});
  
  @override
  State<CryptoStreetViewScreen> createState() => _CryptoStreetViewScreenState();
}

class _CryptoStreetViewScreenState extends State<CryptoStreetViewScreen> {
  late CryptoDataHook cryptoHook;
  final TextEditingController _searchController = TextEditingController();
  List<String> filteredTickers = [];
  bool isInitialized = false;
  String selectedInterval = '15m';

  @override
  void initState() {
    super.initState();
    _initializeCryptoData();
    _searchController.addListener(_filterCoins);
    filteredTickers = TokoCryptoPairs.top100;
  }

  void _initializeCryptoData() {
    // Multi-timeframe support - fetch all common intervals
    cryptoHook = CryptoDataHook(
      tickers: TokoCryptoPairs.top100,
      intervals: Timeframes.common, 
      autoUpdateInterval: 60,
    );

    cryptoHook.onDataUpdate = (ticker, interval, candles) {
      // Only update UI if it's the selected interval and widget is still mounted
      if (!mounted) return;
      if (interval == selectedInterval) {
        // Use addPostFrameCallback to ensure safe setState timing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    };

    cryptoHook.onError = (ticker, interval, error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error $ticker $interval: $error'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };

    cryptoHook.onAllDataReady = () {
      if (mounted) {
        print('✅ All timeframes loaded for ${TokoCryptoPairs.top100.length} coins');
      }
    };

    cryptoHook.startAdaptiveUpdate();
    
    setState(() {
      isInitialized = true;
    });
  }

  void _filterCoins() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredTickers = TokoCryptoPairs.top100;
      } else {
        filteredTickers = TokoCryptoPairs.top100.where((ticker) {
          final coinName = ticker.replaceAll('-USDT', '').toLowerCase();
          return coinName.contains(query);
        }).toList();
      }
    });
  }

  void _changeInterval(String newInterval) {
    setState(() {
      selectedInterval = newInterval;
    });
  }

  @override
  void dispose() {
    cryptoHook.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StreetViewColorStyle.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title dengan Icon Logo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StreetViewColorStyle.greenNeon.withOpacity(0.2),
                              StreetViewColorStyle.greenNeon.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: StreetViewColorStyle.greenNeon.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.currency_bitcoin,
                          color: StreetViewColorStyle.greenNeon,
                          size: 32,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXXE TERMINAL',
                            style: StreetViewColorStyle.sectionTitleStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live Market Data • Multi-Timeframe',
                            style: TextStyle(
                              color: StreetViewColorStyle.subtitleText.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Controls
                  Row(
                    children: [
                      _buildIntervalSelector(),
                      const SizedBox(width: 16),
                      _buildStatsChip(),
                      const SizedBox(width: 16),
                      _buildSearchBar(),
                    ],
                  ),
                ],
              ),
            ),

            // Horizontal Scrolling Crypto Cards
            Expanded(
              child: !isInitialized
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: StreetViewColorStyle.greenNeon,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing multi-timeframe data...',
                            style: TextStyle(
                              color: StreetViewColorStyle.subtitleText,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading ${Timeframes.common.length} timeframes for ${TokoCryptoPairs.top100.length} coins',
                            style: TextStyle(
                              color: StreetViewColorStyle.descriptionText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredTickers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: StreetViewColorStyle.subtitleText.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No cryptocurrencies found',
                                style: TextStyle(
                                  color: StreetViewColorStyle.subtitleText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try searching with a different keyword',
                                style: TextStyle(
                                  color: StreetViewColorStyle.descriptionText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(48, 0, 48, 32),
                          itemCount: filteredTickers.length,
                          itemBuilder: (context, index) {
                            final ticker = filteredTickers[index];
                            final candles = cryptoHook.getCandles(ticker, selectedInterval);
                            final isReady = cryptoHook.isIntervalReady(ticker, selectedInterval);
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < filteredTickers.length - 1 ? 24 : 0,
                              ),
                              child: _CryptoCard(
                                ticker: ticker,
                                candles: candles,
                                index: index,
                                isReady: isReady,
                                interval: selectedInterval,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 320,
      height: 44,
      decoration: StreetViewCardTheme.searchBarDecoration(
        isFocused: _searchController.text.isNotEmpty,
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: StreetViewColorStyle.searchText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search cryptocurrency (BTC, ETH, SOL...)',
          hintStyle: const TextStyle(
            color: StreetViewColorStyle.searchPlaceholder,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: StreetViewColorStyle.searchPlaceholder,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: StreetViewColorStyle.searchPlaceholder,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: StreetViewColorStyle.greenNeon.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.show_chart,
            color: StreetViewColorStyle.greenNeon,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${filteredTickers.length} / ${TokoCryptoPairs.top100.length}',
            style: TextStyle(
              color: StreetViewColorStyle.greenNeon,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: StreetViewColorStyle.greenNeon.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: Timeframes.common.map((interval) {
          final isSelected = selectedInterval == interval;
          final label = Timeframes.getLabel(interval);
          
          return GestureDetector(
            onTap: () => _changeInterval(interval),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected 
                    ? StreetViewColorStyle.greenNeon.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? StreetViewColorStyle.greenNeon
                      : StreetViewColorStyle.subtitleText.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CryptoCard extends StatefulWidget {
  final String ticker;
  final List<CryptoCandle>? candles;
  final int index;
  final bool isReady;
  final String interval;

  const _CryptoCard({
    required this.ticker,
    required this.candles,
    required this.index,
    required this.isReady,
    required this.interval,
  });

  @override
  State<_CryptoCard> createState() => _CryptoCardState();
}

class _CryptoCardState extends State<_CryptoCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final coinName = widget.ticker.replaceAll('-USDT', '');
    final hasData = widget.candles != null && widget.candles!.isNotEmpty;
    
    double currentPrice = 0;
    double priceChange = 0;
    double priceChangePercent = 0;
    double volume24h = 0;
    double high24h = 0;
    double low24h = 0;

    if (hasData) {
      final latestCandle = widget.candles!.last;
      currentPrice = latestCandle.close;
      
      if (widget.candles!.length > 1) {
        final firstCandle = widget.candles!.first;
        priceChange = currentPrice - firstCandle.open;
        priceChangePercent = (priceChange / firstCandle.open) * 100;
        
        high24h = widget.candles!.map((c) => c.high).reduce((a, b) => a > b ? a : b);
        low24h = widget.candles!.map((c) => c.low).reduce((a, b) => a < b ? a : b);
        volume24h = widget.candles!.map((c) => c.volume).reduce((a, b) => a + b);
      }
    }

    final isPositive = priceChange >= 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, isHovered ? -8.0 : 0.0),
        width: 320,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: StreetViewColorStyle.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHovered 
                ? StreetViewColorStyle.greenNeon.withOpacity(0.4)
                : StreetViewColorStyle.searchBorder,
            width: isHovered ? 1.5 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: StreetViewColorStyle.greenNeon.withOpacity(0.15),
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
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: StreetViewColorStyle.greenNeon.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: StreetViewColorStyle.greenNeon.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            coinName.substring(0, coinName.length >= 3 ? 3 : 1),
                            style: TextStyle(
                              color: StreetViewColorStyle.greenNeon,
                              fontSize: coinName.length >= 3 ? 18 : 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coinName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'USDT • ${Timeframes.getLabel(widget.interval)}',
                            style: TextStyle(
                              color: StreetViewColorStyle.subtitleText.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isReady 
                          ? StreetViewColorStyle.greenNeon.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.isReady 
                                ? StreetViewColorStyle.greenNeon
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isReady ? 'LIVE' : 'LOADING',
                          style: TextStyle(
                            color: widget.isReady 
                                ? StreetViewColorStyle.greenNeon
                                : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Price Section
              if (hasData) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${_formatPrice(currentPrice)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive 
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up : Icons.trending_down,
                            color: isPositive ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isPositive ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(\$${_formatPrice(priceChange.abs())})',
                            style: TextStyle(
                              color: isPositive 
                                  ? Colors.green.withOpacity(0.8)
                                  : Colors.red.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: StreetViewColorStyle.greenNeon.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('High', '\$${_formatPrice(high24h)}', Colors.green),
                      const SizedBox(height: 16),
                      Divider(
                        color: StreetViewColorStyle.greenNeon.withOpacity(0.1),
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('Low', '\$${_formatPrice(low24h)}', Colors.red),
                      const SizedBox(height: 16),
                      Divider(
                        color: StreetViewColorStyle.greenNeon.withOpacity(0.1),
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('Volume', _formatVolume(volume24h), StreetViewColorStyle.greenNeon),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: StreetViewColorStyle.greenNeon,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fetching ${Timeframes.getLabel(widget.interval)} data...',
                          style: TextStyle(
                            color: StreetViewColorStyle.subtitleText.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: StreetViewColorStyle.subtitleText.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return price.toStringAsFixed(2);
    } else if (price >= 1) {
      return price.toStringAsFixed(4);
    } else if (price >= 0.01) {
      return price.toStringAsFixed(6);
    } else {
      return price.toStringAsFixed(8);
    }
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000000) {
      return '\$${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '\$${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '\$${(volume / 1000).toStringAsFixed(2)}K';
    } else {
      return '\$${volume.toStringAsFixed(2)}';
    }
  }
}