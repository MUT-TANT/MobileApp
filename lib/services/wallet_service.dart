// WalletConnect service using Reown AppKit (official WalletConnect v2)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/reown_appkit.dart';
import 'package:stacksave/utils/deep_link_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

class WalletService extends ChangeNotifier {
  ReownAppKitModal? _appKitModal;
  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();
  Web3Client? _web3client;
  // Track whether we've already signaled an initial connect to the UI
  bool _hasSignaledConnect = false;

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

      // Configure custom chain (Tenderly fork = chain 8) BEFORE creating modal
      // This adds chain 8 to the WalletConnect session during handshake
      ReownAppKitModalNetworks.removeSupportedNetworks('solana');
      ReownAppKitModalNetworks.removeTestNetworks();
      ReownAppKitModalNetworks.removeSupportedNetworks('eip155');

      // Add ONLY chain 8 (Tenderly fork) with RPC from .env
      ReownAppKitModalNetworks.addSupportedNetworks('eip155', [
        ReownAppKitModalNetworkInfo(
          name: 'Tenderly Fork',
          chainId: '8',
          currency: 'ETH',
          rpcUrl: dotenv.env['RPC_URL']!,
          explorerUrl: 'https://dashboard.tenderly.co/explorer/vnet',
          isTestNetwork: true,
        ),
      ]);

      if (kDebugMode) {
        print('✅ Configured Tenderly fork (chain 8) as supported network');
        print('📡 RPC: ${dotenv.env['RPC_URL']}');
      }

      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: projectId,
        metadata: metadata,
        enableAnalytics: true,
        disconnectOnDispose: false,
      );

      // Initialize Web3 client for transaction receipt queries
      _web3client = Web3Client(
        dotenv.env['RPC_URL']!,
        http.Client(),
      );

      if (kDebugMode) {
        print('✅ Web3Client initialized with RPC: ${dotenv.env['RPC_URL']}');
      }

      // Initialize deep link handler so that wallet callbacks are dispatched
      // to the Reown AppKit modal. This ensures wallet responses return to
      // the app instead of staying inside the wallet's in-app browser.
      _deepLinkHandler.init(_appKitModal!);
      // Check if the app was launched via a deep link before Flutter was
      // ready (initialLink) and dispatch it to AppKit.
      await _deepLinkHandler.checkInitialLink();

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
      print('✅ Wallet connected!');
      print('📍 Address: ${event?.session.getAddress(chainId)}');
      print('🔗 Selected Chain ID: $chainId');

      // VERIFY: Check if chain 8 is in the session
      final accounts = _appKitModal?.session?.getAccounts();
      final namespaces = _appKitModal?.session?.namespaces;
      print('📋 Session accounts: $accounts');
      print('🌐 Session namespaces: $namespaces');

      if (chainId == '8') {
        print('✅ SUCCESS: Chain 8 is supported in session!');
      } else {
        print('⚠️  WARNING: Selected chain is $chainId, not 8!');
      }
    }
    // Only call the UI callback the first time a session connects. This avoids
    // showing a "wallet connected" UI message during subsequent internal
    // connect events (for example after a transaction callback) which can
    // confuse users when they're returned from the wallet.
    if (!_hasSignaledConnect) {
      onSessionConnect?.call();
      _hasSignaledConnect = true;
    } else {
      if (kDebugMode) {
        print('ℹ️ _onModalConnect: connect event ignored (already signaled)');
      }
    }
    notifyListeners();
  }

  void _onModalDisconnect(ModalDisconnect? event) {
    if (kDebugMode) {
      print('Modal disconnected');
    }
    // Reset the connect signal so future connections will notify the UI again
    _hasSignaledConnect = false;
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

  /// Manually launch wallet app (workaround for broken auto-launch on Android)
  Future<void> _launchWalletManually() async {
    try {
      // Get wallet deep link from session metadata
      final redirect = _appKitModal?.session?.peer?.metadata.redirect?.native;

      if (redirect != null && redirect.isNotEmpty) {
        if (kDebugMode) {
          print('🚀 Manually launching wallet: $redirect');
        }

        // Launch wallet app using url_launcher
        final uri = Uri.parse(redirect);
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (kDebugMode) {
          print('✅ Wallet launched successfully');
        }
      } else {
        if (kDebugMode) {
          print('⚠️  No wallet redirect URL found in session metadata');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error launching wallet manually: $e');
      }
      // Don't throw - wallet might already be open or launch might happen differently
    }
  }

  /// Wait for a transaction to be mined and return its receipt
  /// Polls the blockchain every 2 seconds for up to 60 seconds
  /// Returns the transaction receipt, throws if transaction fails or times out
  Future<TransactionReceipt> waitForTransactionReceipt(String txHash) async {
    if (_web3client == null) {
      throw Exception('Web3Client not initialized');
    }

    if (kDebugMode) {
      print('⏳ Waiting for transaction to be mined: $txHash');
    }

    const maxAttempts = 30; // 30 attempts * 2 seconds = 60 seconds timeout
    const pollInterval = Duration(seconds: 2);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final receipt = await _web3client!.getTransactionReceipt(txHash);

        if (receipt != null) {
          // Transaction has been mined
          final isSuccess = receipt.status ?? false;

          if (kDebugMode) {
            print('✅ Transaction mined in block ${receipt.blockNumber}');
            print('📊 Status: ${isSuccess ? "SUCCESS" : "FAILED"}');
            print('⛽ Gas used: ${receipt.gasUsed}');
          }

          // Check if transaction was successful (status = true)
          if (!isSuccess) {
            throw Exception(
                'Transaction failed on blockchain. The contract may have reverted.');
          }

          return receipt;
        }

        // Transaction not yet mined, wait and retry
        if (kDebugMode && attempt % 5 == 0) {
          // Log every 10 seconds
          print('⏳ Still waiting for transaction... (${attempt * 2}s elapsed)');
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        if (e.toString().contains('failed on blockchain')) {
          rethrow; // Rethrow transaction failure
        }
        // Other errors (network issues, etc.) - continue retrying
        if (kDebugMode) {
          print('⚠️  Error checking receipt (attempt $attempt): $e');
        }
      }
    }

    // Timeout reached
    throw Exception(
        'Transaction confirmation timeout. Transaction may still be pending. Hash: $txHash');
  }

  /// Send a transaction and get it signed by the connected wallet
  /// If waitForConfirmation is true, waits for the transaction to be mined on-chain
  /// Returns the transaction hash
  Future<String> sendTransaction({
    required String to,
    required String data,
    String? value,
    String? gasLimit,
    bool waitForConfirmation = false,
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

      // Log transaction details for debugging
      if (kDebugMode) {
        print('📤 Sending transaction request to wallet via AppKit...');
        print('   From: $address');
        print('   To: $to');
        print('   Data: ${data.substring(0, 10)}... (${data.length} chars)');
        print('   Value: ${value ?? "0"}');
        print('   Chain: eip155:${dotenv.env['CHAIN_ID']}');
      }

      // Request signature from wallet using eth_sendTransaction
      // Use chain ID from .env (Tenderly fork = chain 8)
      // Add timeout to prevent indefinite hanging
      final txHash = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:${dotenv.env['CHAIN_ID']}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [params],
        ),
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw Exception('Transaction request timed out - please check your wallet');
        },
      );

      final txHashStr = txHash.toString();

      if (kDebugMode) {
        print('✅ Transaction signed: $txHashStr');
      }

      // If waitForConfirmation is true, wait for the transaction to be mined
      if (waitForConfirmation) {
        if (kDebugMode) {
          print('⏳ Waiting for transaction confirmation on blockchain...');
        }

        // Wait for the transaction to be mined and confirmed
        await waitForTransactionReceipt(txHashStr);

        if (kDebugMode) {
          print('✅ Transaction confirmed on blockchain');
        }
      }

      return txHashStr;
    } catch (e) {
      // Enhanced error logging to see the ACTUAL error
      if (kDebugMode) {
        print('❌ ========================================');
        print('❌ TRANSACTION ERROR DETAILS:');
        print('❌ Error Type: ${e.runtimeType}');
        print('❌ Error Message: ${e.toString()}');

        // Check if it's a JsonRpcError with additional data
        if (e is JsonRpcError) {
          print('❌ RPC Error Code: ${e.code}');
          print('❌ RPC Error Message: ${e.message}');
        }

        print('❌ ========================================');
      }

      // Rethrow the original error so the UI can handle it
      rethrow;
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
  /// If waitForConfirmation is true, waits for the transaction to be mined on-chain
  Future<String> contractCall({
    required String contractAddress,
    required String functionName,
    required List<dynamic> params,
    required List<FunctionParameter> functionParams,
    String? value,
    bool waitForConfirmation = false,
  }) async {
    if (_appKitModal == null || !isConnected) {
      throw Exception('Wallet not connected');
    }

    try {
      // Build function
      final function = ContractFunction(functionName, functionParams);
      final data = function.encodeCall(params);

      // Send transaction with optional confirmation waiting
      final txHash = await sendTransaction(
        to: contractAddress,
        data: bytesToHex(data, include0x: true),
        value: value,
        waitForConfirmation: waitForConfirmation,
      );

      if (kDebugMode) {
        print('✅ Contract call completed: $txHash');
      }

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error calling contract: $e');
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
