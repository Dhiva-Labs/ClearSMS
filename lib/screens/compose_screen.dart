import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../sms_store.dart';
import 'thread_screen.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _toController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<Conversation> get _suggestions {
    final q = _toController.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return SmsStore.instance.conversations
        .where((c) =>
            c.displayName.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  Future<void> _send() async {
    final to = _toController.text.trim();
    final body = _bodyController.text.trim();
    if (to.isEmpty || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final threadId = await SmsStore.instance.sendSms(to, body);
      if (!mounted) return;
      final store = SmsStore.instance;
      Conversation? conv;
      for (final c in store.conversations) {
        if (c.threadId == threadId) {
          conv = c;
          break;
        }
      }
      final navigator = Navigator.of(context);
      navigator.pop();
      if (conv != null) {
        final target = conv;
        navigator.push(
          MaterialPageRoute(builder: (_) => ThreadScreen(conversation: target)),
        );
      }
    } on PlatformException {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not send. Check that ClearSMS has SMS permission and a SIM is active.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestions = _suggestions;

    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _toController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'To',
                hintText: 'Name or phone number',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: suggestions.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, i) {
                      final c = suggestions[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            c.displayName.isNotEmpty
                                ? c.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ),
                        title: Text(c.displayName),
                        subtitle:
                            c.displayName == c.address ? null : Text(c.address),
                        onTap: () {
                          _toController.text = c.address;
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
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
          ),
        ],
      ),
    );
  }
}
