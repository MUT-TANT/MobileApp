import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stacksave/constants/colors.dart';
import 'package:stacksave/services/api_service.dart';
import 'package:stacksave/services/wallet_service.dart';
import 'package:stacksave/models/goal_model.dart';
import 'dart:math' as math;

class PortfolioScreen extends StatefulWidget {
  final bool showNavBar;

  const PortfolioScreen({super.key, this.showNavBar = true});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // Real data from blockchain
  List<GoalModel> _goals = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Wallet balances from Tenderly fork
  double _ethBalance = 0.0;
  double _daiBalance = 0.0;
  double _usdcBalance = 0.0;
  double _wethBalance = 0.0;

  // Calculated portfolio data
  double get totalBalance {
    // Total = wallet balances + goals current value
    final walletTotal = _ethBalance + _daiBalance + _usdcBalance + _wethBalance;
    final goalsTotal = _goals.fold(0.0, (sum, goal) => sum + goal.currentValueDouble);
    return walletTotal + goalsTotal;
  }

  double get totalDeposited {
    return _goals.fold(0.0, (sum, goal) => sum + goal.depositedAmountDouble);
  }

  double get totalEarnings {
    return _goals.fold(0.0, (sum, goal) => sum + goal.yieldEarnedDouble);
  }

  double get totalProfit {
    if (totalDeposited == 0) return 0.0;
    return ((totalEarnings / totalDeposited) * 100);
  }

  double get goalProgress {
    if (_goals.isEmpty) return 0.0;
    final totalTarget = _goals.fold(0.0, (sum, goal) => sum + goal.targetAmountDouble);
    if (totalTarget == 0) return 0.0;
    return (totalDeposited / totalTarget).clamp(0.0, 1.0);
  }

  double get goalTarget {
    return _goals.fold(0.0, (sum, goal) => sum + goal.targetAmountDouble);
  }

  double get averageAPY {
    // Calculate from goals (simplified)
    if (_goals.isEmpty) return 0.0;
    // Assuming 5-8% APY for now
    return 6.5;
  }

  // Weekly earnings data (calculated from goals' daily saves)
  List<Map<String, dynamic>> get weeklyEarnings {
    // Simplified: Get last 7 days from goals
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (index) {
      double amount = 0.0;
      // Sum up deposits from all goals for this day
      for (var goal in _goals) {
        if (goal.dailySaves != null && index < goal.dailySaves!.length) {
          amount += double.tryParse(goal.dailySaves![index].amount) ?? 0.0;
        }
      }
      return {'day': days[index], 'amount': amount};
    });
  }

  // Portfolio allocation data (calculated from wallet balances)
  List<Map<String, dynamic>> get portfolioAllocation {
    final walletTotal = _ethBalance + _daiBalance + _usdcBalance + _wethBalance;
    if (walletTotal == 0) return [];

    return [
      if (_ethBalance > 0) {
        'name': 'ETH',
        'percentage': (_ethBalance / walletTotal) * 100,
        'amount': _ethBalance,
        'color': const Color(0xFF627EEA),
        'icon': Icons.currency_bitcoin,
      },
      if (_daiBalance > 0) {
        'name': 'DAI',
        'percentage': (_daiBalance / walletTotal) * 100,
        'amount': _daiBalance,
        'color': const Color(0xFFF4B731),
        'icon': Icons.account_balance_wallet,
      },
      if (_usdcBalance > 0) {
        'name': 'USDC',
        'percentage': (_usdcBalance / walletTotal) * 100,
        'amount': _usdcBalance,
        'color': const Color(0xFF2775CA),
        'icon': Icons.shield_outlined,
      },
      if (_wethBalance > 0) {
        'name': 'WETH',
        'percentage': (_wethBalance / walletTotal) * 100,
        'amount': _wethBalance,
        'color': const Color(0xFF4CAF50),
        'icon': Icons.water_drop,
      },
    ];
  }

  // Pools data (mapped from user's actual goals)
  List<Map<String, dynamic>> get pools {
    return _goals.map((goal) {
      final statusText = ['Active', 'Completed', 'Abandoned', 'Withdrawn'][goal.status ?? 0];
      return {
        'name': goal.name,
        'icon': Icons.savings_outlined,
        'staked': goal.depositedAmountDouble,
        'apy': 6.5, // Could fetch from API
        'earnings': goal.yieldEarnedDouble,
        'status': statusText,
        'color': goal.mode == 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });

    // Load goals from API - defer until after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGoals();
    });
  }

  Future<void> _loadGoals() async {
    final walletService = context.read<WalletService>();

    if (!walletService.isConnected || walletService.walletAddress == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please connect your wallet';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiService = ApiService();

      // Fetch portfolio data (includes wallet balances + goals summary)
      final portfolioResponse = await apiService.getUserPortfolio(walletService.walletAddress!);
      final portfolioData = portfolioResponse['data'];

      // Extract wallet balances
      final ethData = portfolioData['balances']['eth'];
      final tokensData = portfolioData['balances']['tokens'] as List;

      double ethBalance = 0.0;
      double daiBalance = 0.0;
      double usdcBalance = 0.0;
      double wethBalance = 0.0;

      try {
        ethBalance = double.parse(ethData['balance'].toString());
      } catch (e) {
        print('Error parsing ETH balance: $e');
      }

      for (var token in tokensData) {
        try {
          final symbol = token['symbol'].toString().toUpperCase();
          final balance = double.parse(token['balance'].toString());

          if (symbol == 'DAI') {
            daiBalance = balance;
          } else if (symbol == 'USDC') {
            usdcBalance = balance;
          } else if (symbol == 'WETH') {
            wethBalance = balance;
          }
        } catch (e) {
          print('Error parsing token balance: $e');
        }
      }

      // Fetch goals separately to get full details with dailySaves
      final goalsResponse = await apiService.getUserGoals(walletService.walletAddress!);
      final goalsData = goalsResponse['data']['goals'] as List;
      final goals = goalsData.map((json) => GoalModel.fromJson(json)).toList();

      setState(() {
        _ethBalance = ethBalance;
        _daiBalance = daiBalance;
        _usdcBalance = usdcBalance;
        _wethBalance = wethBalance;
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load portfolio: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate scroll-based animations
    const double maxHeaderHeight = 200.0;
    final double headerOpacity = (1 - (_scrollOffset / 150)).clamp(0.0, 1.0);
    final double headerTranslateY = -(_scrollOffset * 0.5).clamp(0.0, maxHeaderHeight);
    final double borderRadius = (32.0 - (_scrollOffset / 8)).clamp(16.0, 32.0);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            // Header Section (will fade out on scroll)
            Positioned(
              top: headerTranslateY,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: headerOpacity,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Title
                      const Text(
                        'Portofolio',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Balance & Profit
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Total Balance',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${totalBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Total Profit',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${totalProfit.toInt()}%',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Progress bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${(goalProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                value: goalProgress.isFinite ? goalProgress.clamp(0.0, 1.0) : 0.0,
                                backgroundColor: Colors.grey[300],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${goalTarget.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Progress text
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'You are ${(goalProgress * 100).toInt()}% to reach your goals',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Content
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Space for header
                SliverToBoxAdapter(
                  child: SizedBox(height: maxHeaderHeight),
                ),

                // White Card Content
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Earnings Section
                          const Text(
                            'Earnings',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildEarningsChart(),

                          const SizedBox(height: 24),

                          // APY and Earnings cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Average APY',
                                  '${averageAPY.toInt()}%',
                                  Icons.trending_up,
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Earnings',
                                  '\$${totalEarnings.toStringAsFixed(2)}',
                                  Icons.attach_money,
                                  const Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Portfolio Allocation
                          const Text(
                            'Portofolio Allocation',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPortfolioAllocation(),

                          const SizedBox(height: 32),

                          // Your Pools
                          const Text(
                            'Your Pools',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...pools.map((pool) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPoolCard(pool),
                          )),

                          const SizedBox(height: 100),
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
    );
  }

  Widget _buildEarningsChart() {
    final maxAmount = weeklyEarnings.map((e) => e['amount'] as double).reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Chart
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyEarnings.map((data) {
                final height = (data['amount'] as double) / maxAmount * 130;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                        height: height.isFinite ? height.clamp(0.0, 130.0) : 0.0,
                        decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['day'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: AppColors.grayText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioAllocation() {
    return Column(
      children: portfolioAllocation.map((asset) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: asset['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    asset['icon'],
                    color: asset['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset['name'],
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${asset['amount'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: asset['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${asset['percentage'].toInt()}%',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: asset['color'],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPoolCard(Map<String, dynamic> pool) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pool['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pool['icon'],
                  color: pool['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pool['name'],
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pool['status'] == 'Active'
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pool['status'],
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: pool['status'] == 'Active'
                                  ? AppColors.primary
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'APY ${pool['apy']}%',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staked',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.grayText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${pool['staked'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Earnings',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.grayText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${pool['earnings'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: pool['color'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
