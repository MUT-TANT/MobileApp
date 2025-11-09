class TransactionModel {
  final int id;
  final int goalId;
  final String txHash;
  final String type; // 'deposit', 'withdraw', 'withdrawEarly'
  final String amount;
  final String status;
  final int? blockNumber;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.goalId,
    required this.txHash,
    required this.type,
    required this.amount,
    required this.status,
    this.blockNumber,
    required this.timestamp,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? 0,
      goalId: json['goalId'] ?? 0,
      txHash: json['txHash'] ?? '',
      type: json['type'] ?? 'deposit',
      amount: json['amount']?.toString() ?? '0',
      status: json['status'] ?? 'completed',
      blockNumber: json['blockNumber'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  // Convert amount string to double (assuming 18 decimals for DAI/USDC/WETH)
  double get amountDouble {
    try {
      // Amount is stored as wei (string), convert to readable format
      final bigIntAmount = BigInt.tryParse(amount);
      if (bigIntAmount == null) return 0.0;
      return bigIntAmount / BigInt.from(10).pow(18);
    } catch (e) {
      return 0.0;
    }
  }

  // Check transaction type
  bool get isDeposit => type.toLowerCase() == 'deposit';
  bool get isWithdraw =>
      type.toLowerCase() == 'withdraw' ||
      type.toLowerCase() == 'withdrawearly';

  // Format amount for display
  String getFormattedAmount() {
    return amountDouble.toStringAsFixed(2);
  }

  // Get blockchain explorer URL (Tenderly)
  String get explorerUrl {
    return 'https://dashboard.tenderly.co/tx/$txHash';
  }

  // Get transaction type display name
  String get typeDisplay {
    if (type.toLowerCase() == 'deposit') return 'Deposit';
    if (type.toLowerCase() == 'withdraw') return 'Withdraw';
    if (type.toLowerCase() == 'withdrawearly') return 'Early Withdraw';
    return type;
  }
}
