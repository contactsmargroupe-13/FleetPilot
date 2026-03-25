import 'package:flutter/material.dart';
import '../utils/design_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/message.dart';

/// Écran de conversation entre un chauffeur et le manager.
/// [isManager] détermine quel côté envoie.
class ChatScreen extends ConsumerStatefulWidget {
  final String driverName;
  final bool isManager;
  final bool showAppBar;

  const ChatScreen({
    super.key,
    required this.driverName,
    this.isManager = false,
    this.showAppBar = true,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Marquer les messages reçus comme lus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).markConversationRead(
            widget.driverName,
            asManager: widget.isManager,
          );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final msg = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      senderName: widget.isManager ? 'manager' : widget.driverName,
      receiverName: widget.isManager ? widget.driverName : 'manager',
      content: text,
      date: DateTime.now(),
    );

    ref.read(appStateProvider).addMessage(msg);
    _ctrl.clear();

    // Scroll en bas
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Marquer comme lus les messages de l'interlocuteur
    ref.read(appStateProvider).markConversationRead(
          widget.driverName,
          asManager: widget.isManager,
        );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(appStateProvider).messagesForDriver(widget.driverName);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Marquer comme lus à chaque rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).markConversationRead(
            widget.driverName,
            asManager: widget.isManager,
          );
    });

    final body = Column(
        children: [
          // Messages
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: DC.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun message',
                          style: TextStyle(color: DC.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Envoyez le premier message !',
                          style: TextStyle(
                              fontSize: 12, color: DC.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final isMe = widget.isManager
                          ? m.isFromManager
                          : !m.isFromManager;

                      // Séparateur de date
                      final showDate = i == 0 ||
                          !_sameDay(msgs[i - 1].date, m.date);

                      return Column(
                        children: [
                          if (showDate) _dateSeparator(m.date),
                          _bubble(m, isMe, primary),
                        ],
                      );
                    },
                  ),
          ),

          // Zone de saisie
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                  top: BorderSide(color: DC.surface2)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        filled: true,
                        fillColor: DC.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isManager ? widget.driverName : 'Manager'),
      ),
      body: body,
    );
  }

  Widget _bubble(Message m, bool isMe, Color primary) {
    final time =
        '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? primary.withValues(alpha: 0.12)
              : DC.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.content,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontSize: 10, color: DC.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    final String label;
    if (diff == 0) {
      label = "Aujourd'hui";
    } else if (diff == 1) {
      label = 'Hier';
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: DC.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, color: DC.textSecondary)),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
