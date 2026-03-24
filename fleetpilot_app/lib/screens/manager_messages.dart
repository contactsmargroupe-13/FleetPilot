import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'chat_screen.dart';
import 'models/message.dart';

/// Liste des conversations du manager avec les chauffeurs.
class ManagerMessagesPage extends ConsumerWidget {
  const ManagerMessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final drivers = state.drivers;
    final allMessages = state.messages;

    // Construire la liste des conversations avec dernier message
    final conversations = <_ConversationInfo>[];
    for (final driver in drivers) {
      final driverMsgs = allMessages
          .where((m) =>
              m.conversationId.toLowerCase() ==
              driver.name.toLowerCase())
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final unread = state.unreadManagerMessagesFor(driver.name);

      conversations.add(_ConversationInfo(
        driverName: driver.name,
        lastMessage: driverMsgs.isNotEmpty ? driverMsgs.first : null,
        unreadCount: unread,
      ));
    }

    // Trier : non lus d'abord, puis par date du dernier message
    conversations.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (b.unreadCount > 0 && a.unreadCount == 0) return 1;
      final aDate = a.lastMessage?.date ?? DateTime(2000);
      final bDate = b.lastMessage?.date ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversations.isEmpty
          ? const Center(
              child: Text('Aucun chauffeur.',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final conv = conversations[i];
                return _ConversationTile(
                  conv: conv,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          driverName: conv.driverName,
                          isManager: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ConversationInfo {
  final String driverName;
  final Message? lastMessage;
  final int unreadCount;

  const _ConversationInfo({
    required this.driverName,
    this.lastMessage,
    this.unreadCount = 0,
  });
}

class _ConversationTile extends StatelessWidget {
  final _ConversationInfo conv;
  final VoidCallback onTap;

  const _ConversationTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    final lastMsg = conv.lastMessage;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: hasUnread
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        child: Text(
          conv.driverName[0].toUpperCase(),
          style: TextStyle(
            color: hasUnread ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        conv.driverName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: lastMsg != null
          ? Text(
              '${lastMsg.isFromManager ? 'Vous : ' : ''}${lastMsg.content}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: hasUnread ? Colors.black87 : Colors.grey,
                fontWeight:
                    hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            )
          : const Text('Pas de message',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMsg != null)
            Text(
              _formatTime(lastMsg.date),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conv.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } else if (diff == 1) {
      return 'Hier';
    } else {
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    }
  }
}
