import 'package:flutter/material.dart';

import '../format.dart';
import '../main.dart';
import '../models.dart';
import '../sms_store.dart';
import 'compose_screen.dart';
import 'settings_screen.dart';
import 'thread_screen.dart';

const _kTabFocused = 'focused';
const _kTabAll = 'all';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _tab = _kTabFocused;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Default-app status and the message store can change while we're in the
    // background (settings toggle, other apps); re-sync on return.
    if (state == AppLifecycleState.resumed) {
      SmsStore.instance.refreshDefaultStatus();
      SmsStore.instance.refresh();
    }
  }

  bool _inTab(SmsStore store, Conversation c) => switch (_tab) {
        _kTabFocused => store.focusCategories.contains(c.category),
        _kTabAll => true,
        _ => c.category == categoryFromString(_tab),
      };

  List<Conversation> _visible(SmsStore store) {
    var list = store.conversations.where((c) => _inTab(store, c)).toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) =>
              c.displayName.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q) ||
              c.snippet.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  int _unreadIn(SmsStore store, String tab) {
    final prev = _tab;
    _tab = tab;
    final n = store.conversations
        .where((c) => _inTab(store, c))
        .fold(0, (n, c) => n + c.unread);
    _tab = prev;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SmsStore.instance,
      builder: (context, _) {
        final store = SmsStore.instance;
        final conversations = _visible(store);
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ComposeScreen()),
            ),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Compose'),
          ),
          body: RefreshIndicator(
            onRefresh: store.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('Messages',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search conversations',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _tabChips(store)),
                if (!store.isDefaultSmsApp)
                  SliverToBoxAdapter(child: _defaultAppBanner(context, store)),
                if (_tab == _kTabFocused)
                  SliverToBoxAdapter(child: _focusedInfoRow(store)),
                if (_tab == 'promotion' && store.autoDeletePromos)
                  SliverToBoxAdapter(child: _promoInfoRow(store)),
                if (store.loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (conversations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 96),
                    sliver: SliverList.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, i) =>
                          _ConversationTile(conversation: conversations[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabChips(SmsStore store) {
    final entries = <(String, String, IconData?)>[
      (_kTabFocused, 'Focused', Icons.bolt_rounded),
      ('personal', 'Personal', Icons.person_rounded),
      ('transaction', 'Transactions', Icons.account_balance_rounded),
      ('otp', 'OTP', Icons.key_rounded),
      ('promotion', 'Promos', Icons.campaign_rounded),
      (_kTabAll, 'All', null),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label, icon) = entries[i];
          final selected = _tab == id;
          final unread = _unreadIn(store, id);
          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: icon == null
                ? null
                : Icon(icon,
                    size: 18,
                    color: selected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : null),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (unread > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unread',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide.none,
            ),
            onSelected: (_) => setState(() => _tab = id),
          );
        },
      ),
    );
  }

  /// Slim strip under the chips: what Focused currently shows + edit.
  Widget _focusedInfoRow(SmsStore store) {
    final scheme = Theme.of(context).colorScheme;
    final ordered = [
      SmsCategory.personal,
      SmsCategory.transaction,
      SmsCategory.otp,
      SmsCategory.promotion,
    ].where(store.focusCategories.contains);
    final labels = ordered.map((c) => categoryStyle(c).label).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              labels.isEmpty ? 'Nothing selected' : labels,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => showFocusEditSheet(context),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  /// Slim strip on the Promos tab: retention notice + shortcut to change it.
  Widget _promoInfoRow(SmsStore store) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      child: Row(
        children: [
          Icon(Icons.auto_delete_outlined,
              size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Auto-deleted after ${retentionLabel(store.promoRetentionDays)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _defaultAppBanner(BuildContext context, SmsStore store) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.sms_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Make ClearSMS your default messaging app to receive and send texts.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: store.requestDefaultSmsApp,
                child: const Text('Set'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, text) = switch (_tab) {
      _kTabFocused => (Icons.bolt_rounded, 'No focused messages'),
      'personal' => (Icons.person_rounded, 'No personal messages'),
      'transaction' => (Icons.account_balance_rounded, 'No transactions'),
      'otp' => (Icons.key_rounded, 'No verification codes'),
      'promotion' => (Icons.campaign_rounded, 'No promotions — enjoy the quiet'),
      _ => (Icons.forum_outlined, 'No messages yet'),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            _query.isNotEmpty ? 'No matches' : text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String retentionLabel(int days) => switch (days) {
      7 => '1 week',
      14 => '2 weeks',
      30 => '1 month',
      90 => '3 months',
      _ => '$days days',
    };

/// Bottom sheet for choosing which categories the Focused tab shows.
Future<void> showFocusEditSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: SmsStore.instance,
      builder: (context, _) {
        final store = SmsStore.instance;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text('Focused tab shows',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              for (final cat in SmsCategory.values)
                CheckboxListTile(
                  value: store.focusCategories.contains(cat),
                  secondary: Icon(categoryStyle(cat).icon,
                      color: categoryStyle(cat).color),
                  title: Text(categoryStyle(cat).label),
                  onChanged: (checked) {
                    final next = {...store.focusCategories};
                    checked == true ? next.add(cat) : next.remove(cat);
                    store.updateSettings(focusCategories: next);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final scheme = Theme.of(context).colorScheme;
    final style = categoryStyle(c.category);
    final hasUnread = c.unread > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(conversation: c, style: style),
      title: Text(
        c.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        c.snippet.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            listTimestamp(c.date),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${c.unread}',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ThreadScreen(conversation: c)),
        );
      },
      onLongPress: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
            'All messages with ${conversation.displayName} will be deleted from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await SmsStore.instance.deleteThread(conversation.threadId);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not delete. ClearSMS must be the default SMS app to delete messages.'),
          ),
        );
      }
    }
  }
}

class _Avatar extends StatelessWidget {
  final Conversation conversation;
  final CategoryStyle style;
  const _Avatar({required this.conversation, required this.style});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    // Named contacts get an initial, unsaved numbers a person glyph,
    // businesses their category glyph.
    final isPerson = c.isContact || c.category == SmsCategory.personal;
    final initial = c.displayName.isNotEmpty ? c.displayName[0] : '';
    final child = isPerson && RegExp(r'[A-Za-z]').hasMatch(initial)
        ? Text(
            initial.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: style.color,
            ),
          )
        : Icon(style.icon, color: style.color, size: 24);
    return CircleAvatar(
      radius: 26,
      backgroundColor: style.color.withValues(alpha: 0.14),
      child: child,
    );
  }
}
