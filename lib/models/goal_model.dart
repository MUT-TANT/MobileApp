class DailySave {
  final int date; // Timestamp
  final String amount;

  DailySave({
    required this.date,
    required this.amount,
  });

  factory DailySave.fromJson(Map<String, dynamic> json) {
    return DailySave(
      date: json['date'] ?? 0,
      amount: json['amount']?.toString() ?? '0',
    );
  }
}

class GoalModel {
  final int id;
  final String name;
  final String owner;
  final String currency;
  final int mode; // 0 = Lite, 1 = Pro
  final String targetAmount;
  final int duration;
  final int donationPercentage;
  final String depositedAmount;
  final int createdAt;
  final int lastDepositTime;
  final int status; // 0 = Active, 1 = Completed, 2 = Abandoned, 3 = Withdrawn
  final String statusText;
  final String currentValue;
  final String yieldEarned;
  final int currentStreak;
  final int longestStreak;
  final List<DailySave> dailySaves;

  GoalModel({
    required this.id,
    required this.name,
    required this.owner,
    required this.currency,
    required this.mode,
    required this.targetAmount,
    required this.duration,
    required this.donationPercentage,
    required this.depositedAmount,
    required this.createdAt,
    required this.lastDepositTime,
    required this.status,
    required this.statusText,
    required this.currentValue,
    required this.yieldEarned,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailySaves,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final dailySavesData = json['dailySaves'] as List? ?? [];
    final dailySavesList = dailySavesData
        .map((save) => DailySave.fromJson(save as Map<String, dynamic>))
        .toList();

    return GoalModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unnamed Goal',
      owner: json['owner'] ?? '',
      currency: json['currency'] ?? '',
      mode: json['mode'] ?? 0,
      targetAmount: json['targetAmount']?.toString() ?? '0',
      duration: json['duration'] ?? 0,
      donationPercentage: json['donationPercentage'] ?? 0,
      depositedAmount: json['depositedAmount']?.toString() ?? '0',
      createdAt: json['createdAt'] ?? 0,
      lastDepositTime: json['lastDepositTime'] ?? 0,
      status: json['status'] ?? 0,
      statusText: json['statusText'] ?? 'Unknown',
      currentValue: json['currentValue']?.toString() ?? '0',
      yieldEarned: json['yieldEarned']?.toString() ?? '0',
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      dailySaves: dailySavesList,
    );
  }

  // Helper methods
  double get targetAmountDouble {
    try {
      // Convert from wei to regular units (assuming 6 decimals for USDC)
      return double.parse(targetAmount) / 1e6;
    } catch (e) {
      return 0.0;
    }
  }

  double get depositedAmountDouble {
    try {
      return double.parse(depositedAmount) / 1e6;
    } catch (e) {
      return 0.0;
    }
  }

  double get currentValueDouble {
    try {
      return double.parse(currentValue) / 1e6;
    } catch (e) {
      return 0.0;
    }
  }

  double get yieldEarnedDouble {
    try {
      return double.parse(yieldEarned) / 1e6;
    } catch (e) {
      return 0.0;
    }
  }

  double get progress {
    if (targetAmountDouble == 0) return 0.0;
    return (depositedAmountDouble / targetAmountDouble).clamp(0.0, 1.0);
  }

  String get currencySymbol {
    // Map currency address to symbol
    if (currency.toLowerCase() == '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48') {
      return 'USDC';
    } else if (currency.toLowerCase() == '0x6b175474e89094c44da98b954eedeac495271d0f') {
      return 'DAI';
    } else if (currency.toLowerCase() == '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2') {
      return 'WETH';
    }
    return 'Unknown';
  }

  String get modeText {
    return mode == 0 ? 'Lite Mode' : 'Pro Mode';
  }

  bool get isActive {
    return status == 0;
  }

  bool get isCompleted {
    return status == 1;
  }
}
