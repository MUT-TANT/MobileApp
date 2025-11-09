// WalletConnect service using Reown AppKit (official WalletConnect v2)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

class WalletService extends ChangeNotifier {
  ReownAppKitModal? _appKitModal;
  ReownAppKitModal? get appKitModal => _appKitModal;

  bool get isConnected => _appKitModal?.isConnected ?? false;

  String? get walletAddress {
    if (_appKitModal?.session == null) return null;

    // Get all accounts from the session
    final accounts = _appKitModal?.session?.getAccounts();

    if (accounts == null || accounts.isEmpty) return null;

    // Accounts are in format "eip155:1:0xABCD..."
    // Extract the address part (after the second colon)
    final firstAccount = accounts.first;
    final parts = firstAccount.split(':');

    if (parts.length >= 3) {
      return parts[2]; // Return the 0x... address
    }

    return null;
  }

  String get shortenedAddress {
    final address = walletAddress;
    if (address == null || address.isEmpty) {
      return 'Not connected';
    }
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Callbacks for UI
  void Function()? onSessionConnect;
  void Function()? onSessionDelete;

  /// Initialize the Reown AppKit modal
  Future<void> init({
    required BuildContext context,
    required String projectId,
    required PairingMetadata metadata,
  }) async {
    try {
      _errorMessage = null;

      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: projectId,
        metadata: metadata,
        enableAnalytics: true,
        disconnectOnDispose: false,
      );

      // Setup event listeners
      _appKitModal!.onModalConnect.subscribe(_onModalConnect);
      _appKitModal!.onModalDisconnect.subscribe(_onModalDisconnect);
      _appKitModal!.onModalError.subscribe(_onModalError);

      // Initialize the modal
      await _appKitModal!.init();

      notifyListeners();

      if (kDebugMode) {
        print('Reown AppKit initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Reown AppKit init error: $e');
      }
      _errorMessage = 'Failed to initialize: ${e.toString()}';
      notifyListeners();
    }
  }

  void _onModalConnect(ModalConnect? event) {
    if (kDebugMode) {
      final chainId = _appKitModal?.selectedChain?.chainId ?? '1';
      print('Modal connected: ${event?.session.getAddress(chainId)}');
    }
    onSessionConnect?.call();
    notifyListeners();
  }

  void _onModalDisconnect(ModalDisconnect? event) {
    if (kDebugMode) {
      print('Modal disconnected');
    }
    onSessionDelete?.call();
    notifyListeners();
  }

  void _onModalError(ModalError? event) {
    if (kDebugMode) {
      print('Modal error: ${event?.message}');
    }
    _errorMessage = event?.message ?? 'Unknown error';
    notifyListeners();
  }

  /// Open the wallet connection modal
  Future<void> openModal() async {
    if (_appKitModal == null) {
      _errorMessage = 'AppKit not initialized. Call init() first.';
      notifyListeners();
      return;
    }

    try {
      _errorMessage = null;
      await _appKitModal!.openModalView();
    } catch (e) {
      if (kDebugMode) {
        print('Error opening modal: $e');
      }
      _errorMessage = 'Failed to open modal: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Disconnect from the wallet
  Future<void> disconnect() async {
    if (_appKitModal == null) return;

    try {
      await _appKitModal!.disconnect();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting: $e');
      }
      _errorMessage = 'Failed to disconnect: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Get current chain/network info
  ReownAppKitModalNetworkInfo? get currentNetwork => _appKitModal?.selectedChain;

  /// Check if a specific chain is selected
  bool isChainSelected(String chainId) {
    return _appKitModal?.selectedChain?.chainId == chainId;
  }

  /// Send a transaction and get it signed by the connected wallet
  Future<String> sendTransaction({
    required String to,
    required String data,
    String? value,
    String? gasLimit,
  }) async {
    if (_appKitModal == null || !isConnected) {
      throw Exception('Wallet not connected');
    }

    final address = walletAddress;
    if (address == null) {
      throw Exception('No wallet address found');
    }

    try {
      // Build transaction params
      final params = {
        'from': address,
        'to': to,
        'data': data,
        if (value != null) 'value': value,
        if (gasLimit != null) 'gas': gasLimit,
      };

      // Request signature from wallet using eth_sendTransaction
      final txHash = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:${_appKitModal!.selectedChain!.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [params],
        ),
      );

      if (kDebugMode) {
        print('Transaction sent: $txHash');
      }

      return txHash.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      throw Exception('Failed to send transaction: ${e.toString()}');
    }
  }

  /// Approve ERC20 token spending
  Future<String> approveToken({
    required String tokenAddress,
    required String spenderAddress,
    required BigInt amount,
  }) async {
    if (_appKitModal == null || !isConnected) {
      throw Exception('Wallet not connected');
    }

    try {
      // ERC20 approve function signature: approve(address,uint256)
      final function = ContractFunction(
        'approve',
        [
          FunctionParameter('spender', AddressType()),
          FunctionParameter('amount', UintType()),
        ],
      );

      final params = [
        EthereumAddress.fromHex(spenderAddress),
        amount,
      ];

      final data = function.encodeCall(params);

      // Send approval transaction
      final txHash = await sendTransaction(
        to: tokenAddress,
        data: bytesToHex(data, include0x: true),
      );

      if (kDebugMode) {
        print('Token approval sent: $txHash');
      }

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error approving token: $e');
      }
      throw Exception('Failed to approve token: ${e.toString()}');
    }
  }

  /// Call a contract function and get transaction hash
  Future<String> contractCall({
    required String contractAddress,
    required String functionName,
    required List<dynamic> params,
    required List<FunctionParameter> functionParams,
    String? value,
  }) async {
    if (_appKitModal == null || !isConnected) {
      throw Exception('Wallet not connected');
    }

    try {
      // Build function
      final function = ContractFunction(functionName, functionParams);
      final data = function.encodeCall(params);

      // Send transaction
      final txHash = await sendTransaction(
        to: contractAddress,
        data: bytesToHex(data, include0x: true),
        value: value,
      );

      if (kDebugMode) {
        print('Contract call sent: $txHash');
      }

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error calling contract: $e');
      }
      throw Exception('Failed to call contract: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    // Unsubscribe from events
    _appKitModal?.onModalConnect.unsubscribe(_onModalConnect);
    _appKitModal?.onModalDisconnect.unsubscribe(_onModalDisconnect);
    _appKitModal?.onModalError.unsubscribe(_onModalError);

    super.dispose();
  }
}
