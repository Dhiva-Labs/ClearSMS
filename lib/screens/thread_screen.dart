import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../main.dart';
import '../models.dart';
import '../sms_store.dart';

class ThreadScreen extends StatefulWidget {
  final Conversation conversation;
  const ThreadScreen({super.key, required this.conversation});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastEpoch = SmsStore.instance.smsEpoch;

  @override
  void initState() {
    super.initState();
    SmsStore.instance.addListener(_onStoreChanged);
    _load();
    SmsStore.instance.markThreadRead(widget.conversation.threadId);
  }

  @override
  void dispose() {
    SmsStore.instance.removeListener(_onStoreChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final store = SmsStore.instance;
    if (store.smsEpoch != _lastEpoch) {
      _lastEpoch = store.smsEpoch;
      if (store.lastReceivedThreadId == widget.conversation.threadId) {
        _load();
        store.markThreadRead(widget.conversation.threadId);
      }
    }
  }

  Future<void> _load() async {
    try {
      final messages =
          await SmsStore.instance.getMessages(widget.conversation.threadId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _jumpToBottom();
    } on PlatformException {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SmsStore.instance.sendSms(widget.conversation.address, text);
      _inputController.clear();
      await _load();
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final style = categoryStyle(c.category);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: style.color.withValues(alpha: 0.14),
              child: (c.isContact || c.category == SmsCategory.personal) &&
                      c.displayName.isNotEmpty &&
                      RegExp(r'[A-Za-z]').hasMatch(c.displayName[0])
                  ? Text(
                      c.displayName[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: style.color),
                    )
                  : Icon(style.icon, size: 18, color: style.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (c.displayName != c.address)
                    Text(
                      c.address,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final showHeader = i == 0 ||
                          !_sameDay(_messages[i - 1].date, m.date);
                      return Column(
                        children: [
                          if (showHeader) _DayHeader(date: m.date),
                          _Bubble(message: m),
                        ],
                      );
                    },
                  ),
          ),
          _inputBar(scheme),
        ],
      ),
    );
  }

  Widget _inputBar(ColorScheme scheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Text message',
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeader extends StatelessWidget {
  final DateTime date;
  const _DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        dayHeader(date),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final scheme = Theme.of(context).colorScheme;
    final incoming = m.isIncoming;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: incoming ? scheme.surfaceContainerHigh : scheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(incoming ? 6 : 20),
          bottomRight: Radius.circular(incoming ? 20 : 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            m.body,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.35,
              color: incoming ? scheme.onSurface : scheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bubbleTimestamp(m.date),
            style: TextStyle(
              fontSize: 11,
              color: (incoming ? scheme.onSurfaceVariant : scheme.onPrimary)
                  .withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            incoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Align(
            alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
            child: bubble,
          ),
          if (m.otp != null && incoming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ActionChip(
                avatar: const Icon(Icons.copy_rounded, size: 16),
                label: Text('Copy ${m.otp}'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: m.otp!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code ${m.otp} copied'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
