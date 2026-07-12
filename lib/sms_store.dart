import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Single source of truth for conversations + the platform channel.
class SmsStore extends ChangeNotifier {
  SmsStore._();
  static final SmsStore instance = SmsStore._();

  static const _channel = MethodChannel('clear_sms/core');

  List<Conversation> conversations = [];
  bool loading = true;
  bool isDefaultSmsApp = false;

  /// Bumped whenever a new SMS lands, so open thread screens can reload.
  int smsEpoch = 0;
  int? lastReceivedThreadId;

  /// Set when the app is asked to open a specific thread (notification tap).
  int? pendingOpenThreadId;

  // Settings (mirrored from Android SharedPreferences).
  Set<SmsCategory> focusCategories = {
    SmsCategory.personal,
    SmsCategory.transaction,
    SmsCategory.otp,
  };
  bool autoDeletePromos = true;
  int promoRetentionDays = 14;

  Future<void> init() async {
    _channel.setMethodCallHandler(_onPlatformCall);
    await _channel.invokeMethod('requestPermissions');
    await loadSettings();
    await refreshDefaultStatus();
    await refresh();
    final launchThread =
        await _channel.invokeMethod<int>('consumeLaunchThreadId');
    if (launchThread != null) {
      pendingOpenThreadId = launchThread;
      notifyListeners();
    }
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        lastReceivedThreadId =
            ((call.arguments as Map?)?['threadId'] as num?)?.toInt();
        smsEpoch++;
        await refresh();
      case 'onOpenThread':
        pendingOpenThreadId =
            ((call.arguments as Map?)?['threadId'] as num?)?.toInt();
        notifyListeners();
      case 'onDefaultSmsAppChanged':
      case 'onPermissionsChanged':
        await refreshDefaultStatus();
        await refresh();
    }
  }

  Future<void> refreshDefaultStatus() async {
    try {
      isDefaultSmsApp =
          await _channel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
    } on PlatformException {
      isDefaultSmsApp = false;
    }
    notifyListeners();
  }

  Future<void> requestDefaultSmsApp() =>
      _channel.invokeMethod('requestDefaultSmsApp');

  /// Opens Android's default-apps settings (e.g. to switch back to Google
  /// Messages temporarily for RCS).
  Future<void> openDefaultAppsSettings() =>
      _channel.invokeMethod('openDefaultAppsSettings');

  Future<void> refresh() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getConversations');
      conversations = (raw ?? [])
          .map((e) => Conversation.fromMap(e as Map))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } on PlatformException {
      conversations = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<List<Message>> getMessages(int threadId) async {
    final raw = await _channel
        .invokeMethod<List<dynamic>>('getMessages', {'threadId': threadId});
    return (raw ?? []).map((e) => Message.fromMap(e as Map)).toList();
  }

  Future<int> sendSms(String address, String body) async {
    final threadId = await _channel
        .invokeMethod<int>('sendSms', {'address': address, 'body': body});
    await refresh();
    return threadId ?? -1;
  }

  Future<void> markThreadRead(int threadId) async {
    await _channel.invokeMethod('markThreadRead', {'threadId': threadId});
    final i = conversations.indexWhere((c) => c.threadId == threadId);
    if (i != -1 && conversations[i].unread > 0) {
      await refresh();
    }
  }

  Future<void> loadSettings() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getSettings');
      if (raw == null) return;
      autoDeletePromos = raw['autoDeletePromos'] as bool? ?? true;
      promoRetentionDays = (raw['promoRetentionDays'] as num?)?.toInt() ?? 14;
      final focus = raw['focusCategories'] as List?;
      if (focus != null) {
        focusCategories =
            focus.map((e) => categoryFromString(e as String)).toSet();
      }
    } on PlatformException {
      // Keep defaults.
    }
    notifyListeners();
  }

  /// Persists changed settings; returns how many old promos were deleted as
  /// a result (retention shortened / auto-delete enabled).
  Future<int> updateSettings({
    bool? autoDeletePromos,
    int? promoRetentionDays,
    Set<SmsCategory>? focusCategories,
  }) async {
    if (autoDeletePromos != null) this.autoDeletePromos = autoDeletePromos;
    if (promoRetentionDays != null) this.promoRetentionDays = promoRetentionDays;
    if (focusCategories != null) this.focusCategories = focusCategories;
    notifyListeners();
    int deleted = 0;
    try {
      deleted = await _channel.invokeMethod<int>('updateSettings', {
            'autoDeletePromos': ?autoDeletePromos,
            'promoRetentionDays': ?promoRetentionDays,
            'focusCategories':
                ?focusCategories?.map(categoryToString).toList(),
          }) ??
          0;
    } on PlatformException {
      // Settings stay applied locally; platform will re-sync next launch.
    }
    if (deleted > 0) await refresh();
    return deleted;
  }

  Future<bool> deleteThread(int threadId) async {
    final ok =
        await _channel.invokeMethod<bool>('deleteThread', {'threadId': threadId}) ??
            false;
    await refresh();
    return ok;
  }
}
