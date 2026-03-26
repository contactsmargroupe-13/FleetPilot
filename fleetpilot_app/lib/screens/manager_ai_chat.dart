import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import 'models/expense.dart';

class ManagerAiChatPage extends ConsumerStatefulWidget {
  const ManagerAiChatPage({super.key});

  @override
  ConsumerState<ManagerAiChatPage> createState() => _ManagerAiChatPageState();
}

class _ManagerAiChatPageState extends ConsumerState<ManagerAiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  // Suggestions rapides
  static const _quickQuestions = [
    'Quel camion est le plus rentable ?',
    'Résume les dépenses du mois',
    'Quels chauffeurs ont le plus de km ?',
    'Des anomalies à signaler ?',
    'Compare ce mois au précédent',
    'Conseils pour réduire les coûts',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildFleetContext() {
    final state = ref.read(appStateProvider);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);

    final monthTours = state.tours
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();
    final monthExpenses = state.expenses
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();

    final totalKm = monthTours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = monthTours.fold(0, (s, t) => s + t.clientsCount);
    final totalExpenses = monthExpenses.fold(0.0, (s, e) => s + e.amount);
    final fuelExpenses = monthExpenses
        .where((e) => e.type == ExpenseType.fuel)
        .fold(0.0, (s, e) => s + e.amount);

    final buf = StringBuffer();
    buf.writeln('Mois en cours : ${now.month}/${now.year}');
    buf.writeln('Nombre de camions : ${state.trucks.length}');
    buf.writeln('Nombre de chauffeurs : ${state.drivers.length}');
    buf.writeln('Tournées ce mois : ${monthTours.length}');
    buf.writeln('Km total ce mois : ${totalKm.toStringAsFixed(0)}');
    buf.writeln('Clients livrés : $totalClients');
    buf.writeln('Dépenses totales : ${totalExpenses.toStringAsFixed(0)} €');
    buf.writeln('Dont carburant : ${fuelExpenses.toStringAsFixed(0)} €');
    buf.writeln();

    // Détail par camion
    buf.writeln('CAMIONS :');
    for (final truck in state.trucks) {
      final truckTours = monthTours.where((t) => t.truckPlate == truck.plate);
      final truckKm = truckTours.fold(0.0, (s, t) => s + t.kmTotal);
      final truckExp = monthExpenses
          .where((e) => e.truckPlate == truck.plate)
          .fold(0.0, (s, e) => s + e.amount);
      // Revenu via tarifs commissionnaires des tournées réelles
      double revenue = 0;
      for (final tour in truckTours) {
        final pricing = state.getClientPricing(tour.companyName);
        if (pricing != null) revenue += pricing.dailyRate;
      }
      buf.writeln(
          '- ${truck.plate} (${truck.model}) : ${truckTours.length} tournées, '
          '${truckKm.toStringAsFixed(0)} km, dépenses ${truckExp.toStringAsFixed(0)} €, '
          'revenu estimé ${revenue.toStringAsFixed(0)} €');
    }
    buf.writeln();

    // Détail par chauffeur
    buf.writeln('CHAUFFEURS :');
    for (final driver in state.drivers) {
      final driverTours = monthTours
          .where((t) => t.driverName.toLowerCase() == driver.name.toLowerCase());
      final driverKm = driverTours.fold(0.0, (s, t) => s + t.kmTotal);
      buf.writeln(
          '- ${driver.name} (${driver.status.name}) : ${driverTours.length} tournées, '
          '${driverKm.toStringAsFixed(0)} km, salaire ${driver.totalSalary.toStringAsFixed(0)} €');
    }

    return buf.toString();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text.trim()));
      _loading = true;
    });
    _controller.clear();
    _scrollDown();

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    // Remove last user message from history (it's in the userMessage param)
    if (history.isNotEmpty) history.removeLast();

    final response = await AiService.chat(
      fleetContext: _buildFleetContext(),
      userMessage: text.trim(),
      history: history,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', content: response));
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, size: 22, color: Colors.blue),
            SizedBox(width: 8),
            Text('Assistant IA'),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Effacer la conversation',
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length && _loading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[i]);
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Center(
          child: Icon(Icons.smart_toy_outlined, size: 48, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Assistant FleetPilote',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Posez une question sur votre flotte',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 28),
        const Text('Suggestions :',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickQuestions
              .map((q) => ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 13)),
                    avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                    onPressed: () => _send(q),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: SelectableText(
          msg.content,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Analyse en cours...',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Posez une question...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _loading ? null : _send,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  _loading ? null : () => _send(_controller.text),
              child: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  const _ChatMessage({required this.role, required this.content});
}
