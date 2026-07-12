import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../sms_store.dart';
import 'home_screen.dart' show retentionLabel;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: SmsStore.instance,
        builder: (context, _) {
          final store = SmsStore.instance;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: Icon(
                  store.isDefaultSmsApp
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: store.isDefaultSmsApp
                      ? const Color(0xFF00A67E)
                      : scheme.error,
                ),
                title: const Text('Default SMS app'),
                subtitle: Text(store.isDefaultSmsApp
                    ? 'ClearSMS is your default messaging app'
                    : 'Tap to make ClearSMS the default messaging app'),
                onTap: store.isDefaultSmsApp
                    ? null
                    : store.requestDefaultSmsApp,
              ),
              const Divider(height: 24),
              _sectionHeader(context, 'FOCUSED TAB'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Choose what appears in your Focused tab — the first thing '
                  'you see when you open the app.',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in SmsCategory.values)
                      FilterChip(
                        selected: store.focusCategories.contains(cat),
                        avatar: Icon(
                          categoryStyle(cat).icon,
                          size: 18,
                          color: store.focusCategories.contains(cat)
                              ? scheme.onSecondaryContainer
                              : categoryStyle(cat).color,
                        ),
                        showCheckmark: false,
                        label: Text(categoryStyle(cat).label),
                        onSelected: (checked) {
                          final next = {...store.focusCategories};
                          checked ? next.add(cat) : next.remove(cat);
                          store.updateSettings(focusCategories: next);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              _sectionHeader(context, 'PROMOTIONS'),
              SwitchListTile(
                secondary: Icon(Icons.auto_delete_outlined,
                    color: scheme.onSurfaceVariant),
                title: const Text('Auto-delete old promotions'),
                subtitle: const Text(
                    'Promotional messages are removed automatically. '
                    'Messages from saved contacts are never touched.'),
                value: store.autoDeletePromos,
                onChanged: (v) async {
                  final deleted =
                      await store.updateSettings(autoDeletePromos: v);
                  if (deleted > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('$deleted old promotion(s) deleted')));
                  }
                },
              ),
              if (store.autoDeletePromos)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keep promotions for',
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 7, label: Text('1 wk')),
                          ButtonSegment(value: 14, label: Text('2 wks')),
                          ButtonSegment(value: 30, label: Text('1 mo')),
                          ButtonSegment(value: 90, label: Text('3 mo')),
                        ],
                        selected: {store.promoRetentionDays},
                        onSelectionChanged: (sel) async {
                          final deleted = await store.updateSettings(
                              promoRetentionDays: sel.first);
                          if (deleted > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '$deleted old promotion(s) deleted')));
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Currently: promotions older than '
                        '${retentionLabel(store.promoRetentionDays)} are deleted.',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              _sectionHeader(context, 'RCS CHATS'),
              ListTile(
                leading: Icon(Icons.forum_outlined,
                    color: scheme.onSurfaceVariant),
                title: const Text('RCS is not supported'),
                subtitle: const Text(
                    'Android gives no RCS access to third-party apps — Google '
                    'limits it to Google Messages, so no alternative SMS app can '
                    'send or receive RCS chats. While ClearSMS is your default, '
                    'RCS conversations pause and senders fall back to SMS.'),
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz_rounded,
                    color: scheme.onSurfaceVariant),
                title: const Text('Need RCS for a moment?'),
                subtitle: const Text(
                    'Switch the default messaging app back to Google Messages '
                    'in Android settings, then return here any time.'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => SmsStore.instance.openDefaultAppsSettings(),
              ),
              const Divider(height: 32),
              _sectionHeader(context, 'HOW MESSAGES ARE ORGANIZED'),
              for (final cat in SmsCategory.values) _categoryRow(context, cat),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.notifications_off_outlined,
                    color: scheme.onSurfaceVariant),
                title: const Text('Promotions are silent'),
                subtitle: const Text(
                    'Promotional messages never ring or vibrate. They wait quietly '
                    'in the Promos tab. You can adjust this per-channel in Android '
                    'notification settings.'),
              ),
              ListTile(
                leading:
                    Icon(Icons.key_rounded, color: scheme.onSurfaceVariant),
                title: const Text('Smart OTP notifications'),
                subtitle: const Text(
                    'Verification codes are surfaced in the notification title '
                    'with a one-tap Copy button.'),
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined,
                    color: scheme.onSurfaceVariant),
                title: const Text('Private by design'),
                subtitle: const Text(
                    'Classification runs entirely on this phone. No ads, no '
                    'tracking, nothing leaves the device.'),
              ),
              const Divider(height: 24),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('ClearSMS'),
                subtitle: Text('Version 1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _categoryRow(BuildContext context, SmsCategory cat) {
    final style = categoryStyle(cat);
    final description = switch (cat) {
      SmsCategory.personal => 'Messages from people and saved contacts',
      SmsCategory.otp => 'Verification codes and one-time passwords',
      SmsCategory.transaction => 'Bank alerts, bills, deliveries and services',
      SmsCategory.promotion => 'Offers and marketing — silenced by default',
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: style.color.withValues(alpha: 0.14),
        child: Icon(style.icon, color: style.color, size: 20),
      ),
      title: Text(style.label),
      subtitle: Text(description),
    );
  }
}
