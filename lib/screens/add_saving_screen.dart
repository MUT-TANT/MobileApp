import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:stacksave/constants/colors.dart';
import 'package:stacksave/services/api_service.dart';
import 'package:stacksave/services/wallet_service.dart';
import 'package:stacksave/services/price_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';

class AddSavingScreen extends StatefulWidget {
  final bool showNavBar;
  final bool fromNavBar;

  const AddSavingScreen({
    super.key,
    this.showNavBar = true,
    this.fromNavBar = false,
  });

  @override
  State<AddSavingScreen> createState() => _AddSavingScreenState();
}

class _AddSavingScreenState extends State<AddSavingScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();

  double _scrollOffset = 0.0;
  String _savingMode = 'Lite Mode'; // 'Lite Mode' or 'Pro Mode'
  int? _selectedGoalId; // Changed to int goalId
  String? _selectedPaymentMethod;

  // Real-time data from backend
  List<Map<String, dynamic>> _realGoals = [];
  bool _isLoadingGoals = true;

  // USD to DAI conversion
  double _daiExchangeRate = 1.0;
  double _daiEquivalent = 0.0;
  bool _isLoadingPrice = false;
  final PriceService _priceService = PriceService();

  // Get mode info
  Map<String, dynamic> get _modeInfo {
    if (_savingMode == 'Lite Mode') {
      return {
        'title': 'Lite Mode',
        'desc': 'Auto-stake in stablecoins',
        'risk': 'Low Risk',
        'apy': '5-8%',
        'color': const Color(0xFF4CAF50),
      };
    } else {
      return {
        'title': 'Pro Mode',
        'desc': 'High-yield staking instruments',
        'risk': 'High Risk',
        'apy': '15-30%',
        'color': const Color(0xFFFF9800),
      };
    }
  }

  // Calculate projected returns
  String _calculateProjectedReturns() {
    if (_amountController.text.isEmpty) return '\$0.00';

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      final apy = _savingMode == 'Lite Mode' ? 0.065 : 0.225; // Average APY
      final monthlyReturn = amount * (apy / 12);
      return '\$${monthlyReturn.toStringAsFixed(2)}';
    } catch (e) {
      return '\$0.00';
    }
  }

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Wallet',
      'icon': Icons.account_balance_wallet,
      'description': 'Connect your crypto wallet',
    },
    {
      'name': 'Mastercard',
      'icon': Icons.credit_card,
      'description': 'Pay with your credit card',
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    // Listen to amount changes for real-time calculation AND conversion
    _amountController.addListener(() {
      _updateDaiConversion();
      setState(() {});
    });
    // Fetch real data from backend
    _loadUserGoals();
    // Fetch DAI exchange rate
    _fetchDaiExchangeRate();
  }

  // Fetch user's goals from database
  Future<void> _loadUserGoals() async {
    final walletService = context.read<WalletService>();

    print('🔍 AddSaving: Loading goals...');
    print('🔍 AddSaving: Wallet address: ${walletService.walletAddress}');

    if (walletService.walletAddress == null) {
      print('❌ AddSaving: Wallet address is null');
      setState(() => _isLoadingGoals = false);
      return;
    }

    try {
      final apiService = ApiService();
      print('📡 AddSaving: Calling API with address: ${walletService.walletAddress}');
      final response = await apiService.getUserGoals(walletService.walletAddress!);

      print('✅ AddSaving: API Response: $response');

      if (response['success'] == true) {
        final data = response['data'];
        if (data != null && data['goals'] != null) {
          final goalsList = List<Map<String, dynamic>>.from(data['goals']);
          print('✅ AddSaving: Found ${goalsList.length} goals');
          setState(() {
            _realGoals = goalsList;
            _isLoadingGoals = false;
          });
        } else {
          print('⚠️ AddSaving: No goals data in response');
          setState(() => _isLoadingGoals = false);
        }
      } else {
        print('⚠️ AddSaving: API returned success=false');
        setState(() => _isLoadingGoals = false);
      }
    } catch (e) {
      print('❌ AddSaving Error loading goals: $e');
      setState(() => _isLoadingGoals = false);
    }
  }

  /// Fetch DAI/USD exchange rate from CoinGecko
  Future<void> _fetchDaiExchangeRate() async {
    setState(() => _isLoadingPrice = true);

    try {
      _daiExchangeRate = await _priceService.getDaiUsdRate();
      _updateDaiConversion();
    } catch (e) {
      print('❌ Error fetching exchange rate: $e');
      // Use fallback rate
      _daiExchangeRate = 1.0;
    } finally {
      setState(() => _isLoadingPrice = false);
    }
  }

  /// Update DAI equivalent when USD amount changes
  void _updateDaiConversion() {
    if (_amountController.text.isEmpty) {
      setState(() => _daiEquivalent = 0.0);
      return;
    }

    try {
      final usdAmount = double.parse(_amountController.text.replaceAll(',', ''));
      setState(() {
        _daiEquivalent = usdAmount / _daiExchangeRate;
      });
    } catch (e) {
      setState(() => _daiEquivalent = 0.0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountController.dispose();
    _cardNumberController.dispose();
    _cvcController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    // Validation
    if (_selectedGoalId == null ||
        _amountController.text.isEmpty ||
        _selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final walletService = context.read<WalletService>();

    if (!walletService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect your wallet first'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get selected goal details
    final selectedGoal = _realGoals.firstWhere(
      (goal) => goal['id'] == _selectedGoalId,
      orElse: () => {},
    );

    if (selectedGoal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected goal not found'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Get contract addresses from .env
      final stackSaveAddress = dotenv.env['STACKSAVE_CONTRACT']!;

      // Currency from API is already the token address (e.g., 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
      final tokenAddress = selectedGoal['currency'] as String;

      // Get display name for UI (USDC, DAI, or WETH)
      final currencySymbol = _getCurrencySymbol(tokenAddress);

      // Convert USD to DAI amount (user enters USD, we transact in DAI)
      final usdAmount = double.parse(_amountController.text.replaceAll(',', ''));
      final daiAmount = _daiEquivalent; // Already calculated
      final amountWei = BigInt.from(daiAmount * 1e18);

      print('💰 Depositing: \$$usdAmount USD = $daiAmount DAI = $amountWei wei');
      print('🔍 VERIFICATION: Sending $amountWei wei to contract');
      print('🔍 This equals: ${daiAmount.toStringAsFixed(6)} DAI (NOT ${usdAmount.toStringAsFixed(6)} DAI)');
      print('📍 StackSave: $stackSaveAddress');
      print('📍 Token: $tokenAddress');
      print('🎯 Goal ID: $_selectedGoalId');

      // Pre-transaction validation: Check token balance
      // TODO: Add balance check via wallet service or API

      String? approveTxHash;
      String? depositTxHash;
      bool isWaitingDepositConfirmation = false;

      // Show two-step transaction dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Confirm Deposit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Depositing: ${daiAmount.toStringAsFixed(2)} $currencySymbol',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You entered: \$${usdAmount.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.grayText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Wei amount: $amountWei',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: AppColors.grayText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step 1: Approval
                  _buildTransactionStep(
                    stepNumber: 1,
                    title: 'Approve Token',
                    description: 'After signing, close wallet and return to app',
                    txHash: approveTxHash,
                    isActive: approveTxHash == null,
                    isCompleted: approveTxHash != null,
                  ),

                  const SizedBox(height: 12),

                  // Step 2: Deposit
                  _buildTransactionStep(
                    stepNumber: 2,
                    title: 'Deposit to Morpho',
                    description: 'After signing, close wallet and return to app',
                    txHash: depositTxHash,
                    isActive: approveTxHash != null && depositTxHash == null,
                    isCompleted: depositTxHash != null,
                    isWaitingConfirmation: isWaitingDepositConfirmation,
                  ),

                  if (depositTxHash != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your funds are now earning yield on Morpho v2!',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (depositTxHash == null)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                if (approveTxHash == null)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // Step 1: Approve
                        setDialogState(() {});
                        final txHash = await walletService.approveToken(
                          tokenAddress: tokenAddress,
                          spenderAddress: stackSaveAddress,
                          amount: amountWei,
                        );
                        approveTxHash = txHash;
                        setDialogState(() {});
                        print('✅ Approval TX: $txHash');
                      } catch (e) {
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Approval failed: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sign Approval'),
                  )
                else if (depositTxHash == null)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        // Step 2: Deposit (with blockchain confirmation)
                        setDialogState(() {});

                        // Call contractCall which will:
                        // 1. Launch wallet and get user signature
                        // 2. Wait for blockchain confirmation
                        // We need to update UI after signature but before confirmation
                        final txHashFuture = walletService.contractCall(
                          contractAddress: stackSaveAddress,
                          functionName: 'deposit',
                          params: [
                            BigInt.from(_selectedGoalId!),
                            amountWei,
                          ],
                          functionParams: [
                            FunctionParameter('goalId', UintType()),
                            FunctionParameter('amount', UintType()),
                          ],
                          waitForConfirmation: true, // Wait for blockchain confirmation
                        );

                        // Add a small delay for wallet signature, then show confirmation waiting
                        Future.delayed(const Duration(seconds: 3), () {
                          if (depositTxHash == null && !isWaitingDepositConfirmation) {
                            setDialogState(() {
                              isWaitingDepositConfirmation = true;
                            });
                          }
                        });

                        final txHash = await txHashFuture;
                        isWaitingDepositConfirmation = false;
                        depositTxHash = txHash;
                        setDialogState(() {});
                        print('✅ Deposit confirmed on blockchain: $txHash');

                        // Sync goal from blockchain to update streak and progress immediately
                        try {
                          print('🔄 Syncing goal ${_selectedGoalId!} from blockchain...');
                          await ApiService().syncGoalFromBlockchain(_selectedGoalId!);
                          print('✅ Goal synced - streak and progress updated');
                        } catch (syncError) {
                          print('⚠️ Sync failed: $syncError (goal will update via event listener)');
                          // Don't show error to user - this is a best-effort sync
                          // Event listener will eventually update the goal
                        }
                        // Close the dialog and navigate back (or return a refresh signal)
                        // so the app doesn't leave the user stuck on the same screen.
                        if (mounted) {
                          // Close the confirm dialog
                          Navigator.pop(dialogContext);

                          // If this screen was pushed onto the navigation stack, pop it
                          // and return true to signal the caller to refresh.
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop(true);
                          } else {
                            // If embedded (e.g. in a TabView), show a success snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deposit successful'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        isWaitingDepositConfirmation = false;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;

                        // Show specific error message
                        String errorMsg = 'Deposit failed: ${e.toString()}';
                        if (e.toString().contains('failed on blockchain')) {
                          errorMsg = 'Transaction failed on blockchain. The contract may have reverted.';
                        } else if (e.toString().contains('timeout')) {
                          errorMsg = 'Transaction confirmation timeout. Please check your wallet and blockchain explorer.';
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sign Deposit'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext); // Close the dialog

                      // Only pop if this screen was pushed to navigation stack
                      // (not embedded in TabView)
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop(true); // Return with refresh signal
                      }
                      // If embedded in TabView, just closing dialog is enough
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
                  ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Helper to get currency symbol for display from token address
  String _getCurrencySymbol(String tokenAddress) {
    final address = tokenAddress.toLowerCase();

    // Map token addresses to display symbols
    if (address == '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48') {
      return 'USDC';
    } else if (address == '0x6b175474e89094c44da98b954eedeac495271d0f') {
      return 'DAI';
    } else if (address == '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2') {
      return 'WETH';
    }

    // Fallback: return first 6 chars of address if unknown
    return '${address.substring(0, 6)}...';
  }

  // Build transaction step UI
  Widget _buildTransactionStep({
    required int stepNumber,
    required String title,
    required String description,
    String? txHash,
    required bool isActive,
    required bool isCompleted,
    bool isWaitingConfirmation = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primary
                : isActive
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
                  )
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : Colors.grey,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive || isCompleted
                      ? AppColors.black
                      : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              if (txHash != null) ...[
                const SizedBox(height: 4),
                Text(
                  'TX: ${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (isWaitingConfirmation) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Confirming on blockchain...',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ] else if (isActive && txHash == null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Waiting for signature...',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate scroll-based animations
    const double maxHeaderHeight = 72.0;
    final double headerOpacity = (1 - (_scrollOffset / 100)).clamp(0.0, 1.0);
    final double headerTranslateY = -(_scrollOffset * 0.5).clamp(0.0, maxHeaderHeight);
    final double borderRadius = (32.0 - (_scrollOffset / 8)).clamp(16.0, 32.0);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: VisibilityDetector(
        key: const Key('add-saving-screen'),
        onVisibilityChanged: (info) {
          // Reload goals when screen becomes visible (>50% visible)
          if (info.visibleFraction > 0.5 && mounted) {
            _loadUserGoals();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
            // (Header removed - intentionally hidden to avoid duplicate title below the top bar)

            // Form Container (scrollable white card)
            RefreshIndicator(
              onRefresh: _loadUserGoals,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                // Space for header
                SliverToBoxAdapter(
                  child: SizedBox(height: maxHeaderHeight),
                ),

                // White Card Content
                SliverToBoxAdapter(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 80,
                    ),
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
                          // Saving Mode Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Saving Mode',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildModeButton('Lite Mode'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildModeButton('Pro Mode'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Mode Description
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _savingMode == 'Lite Mode'
                                          ? Icons.shield_outlined
                                          : Icons.trending_up,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _modeInfo['desc'],
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${_modeInfo['risk']} • APY ${_modeInfo['apy']}',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Goals
                          const Text(
                            'Goals',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: _isLoadingGoals
                                  ? const Center(child: CircularProgressIndicator())
                                  : DropdownButton<int>(
                                      value: _selectedGoalId,
                                      hint: Text(
                                        _realGoals.isEmpty ? 'No goals available' : 'Select the goals',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: AppColors.grayText,
                                        ),
                                      ),
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: AppColors.black,
                                      ),
                                      items: _realGoals.map((goal) {
                                        return DropdownMenuItem<int>(
                                          value: goal['id'] as int,
                                          child: Text(goal['name'] as String),
                                        );
                                      }).toList(),
                                      onChanged: (int? newValue) {
                                        setState(() {
                                          _selectedGoalId = newValue;
                                        });
                                      },
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Amount
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: AppColors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: '30.00',
                              prefixText: '\$ ',
                              suffixText: 'USD',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: AppColors.black.withOpacity(0.5),
                              ),
                              prefixStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: AppColors.black,
                                fontWeight: FontWeight.w600,
                              ),
                              suffixStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: AppColors.grayText,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFE8F5E9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // DAI Conversion Display
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.swap_horiz,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You\'ll pay ${_daiEquivalent.toStringAsFixed(2)} DAI',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (_isLoadingPrice)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Analysis Section
                          const Text(
                            'Analysis',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Projected Monthly Returns
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Projected Monthly Returns',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: AppColors.grayText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _calculateProjectedReturns(),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _modeInfo['color'],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _modeInfo['apy'],
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Info Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Risk Level',
                                        _modeInfo['risk'],
                                        _savingMode == 'Lite Mode'
                                          ? Icons.shield_outlined
                                          : Icons.warning_amber_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Strategy',
                                        _savingMode == 'Lite Mode' ? 'Stablecoin' : 'High Yield',
                                        Icons.analytics_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Payment Method
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Payment Method Options
                          ..._paymentMethods.map((method) {
                            final isSelected = _selectedPaymentMethod == method['name'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentMethod = method['name'];
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.2)
                                            : Colors.black.withOpacity(0.05),
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
                                          color: isSelected
                                              ? AppColors.primary.withOpacity(0.1)
                                              : const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          method['icon'],
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.grayText,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              method['name'],
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              method['description'],
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: AppColors.grayText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                          // Dynamic Payment Form Fields
                          if (_selectedPaymentMethod != null) ...[
                            const SizedBox(height: 16),
                            if (_selectedPaymentMethod == 'Wallet') ...[
                              const Text(
                                'Connected Wallet',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Consumer<WalletService>(
                                builder: (context, walletService, child) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            walletService.walletAddress ?? 'Not connected',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: AppColors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ] else if (_selectedPaymentMethod == 'Mastercard') ...[
                              const Text(
                                'Card Number',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _cardNumberController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: AppColors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: '1234 5678 9012 3456',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: AppColors.black.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFE8F5E9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Expiry Date',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _expiryController,
                                          keyboardType: TextInputType.datetime,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: AppColors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'MM/YY',
                                            hintStyle: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: AppColors.black.withOpacity(0.5),
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFE8F5E9),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'CVC',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _cvcController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: AppColors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '123',
                                            hintStyle: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: AppColors.black.withOpacity(0.5),
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFE8F5E9),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],

                          const SizedBox(height: 24),

                          // Proceed Button
                          Center(
                            child: SizedBox(
                              width: 170,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _proceed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Proceed',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildModeButton(String mode) {
    final isSelected = _savingMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _savingMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            mode,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.grayText,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
