// Deep Link Handler for WalletConnect redirects
// This dispatches deep links to Reown AppKit so transaction responses work

import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

class DeepLinkHandler {
  static const _eventChannel = EventChannel('deep_link_events');
  static const _methodChannel = MethodChannel('deep_link_channel');

  ReownAppKitModal? _appKitModal;

  /// Initialize the deep link handler with AppKit modal
  void init(ReownAppKitModal appKitModal) {
    _appKitModal = appKitModal;

    // Listen to deep link stream from MainActivity
    _eventChannel.receiveBroadcastStream().listen(
      _onLink,
      onError: _onLinkError,
    );

    print('✅ DeepLinkHandler initialized');
  }

  /// Check if app was launched via deep link
  Future<void> checkInitialLink() async {
    try {
      final link = await _methodChannel.invokeMethod<String>('initialLink');
      if (link != null) {
        print('🔗 Initial deep link detected: $link');
        _onLink(link);
      }
    } catch (e) {
      print('❌ Error checking initial link: $e');
    }
  }

  /// Handle incoming deep link by dispatching to AppKit
  void _onLink(dynamic link) {
    if (link == null || _appKitModal == null) return;

    final linkStr = link.toString();
    print('📱 Deep link received: $linkStr');

    // THIS IS THE CRITICAL FIX: Dispatch the deep link to AppKit
    // Without this, transaction responses from wallets never reach the SDK
    _appKitModal!.dispatchEnvelope(linkStr);

    print('✅ Deep link dispatched to AppKit');
  }

  /// Handle deep link errors
  void _onLinkError(dynamic error) {
    print('❌ Deep link error: $error');
  }
}
