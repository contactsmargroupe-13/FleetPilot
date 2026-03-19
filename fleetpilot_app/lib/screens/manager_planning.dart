import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/tour.dart';

class ManagerPlanningPage extends ConsumerStatefulWidget {
  const ManagerPlanningPage({super.key});

  @override
  ConsumerState<ManagerPlanningPage> createState() => _ManagerPlanningPageState();
}

class _ManagerPlanningPageState extends ConsumerState<ManagerPlanningPage> {
  late DateTime _selectedDate;
  bool _weekView = false;

  String? _driverFilter;
  String? _truckFilter;
  String? _statusFilter;

  static const List<String> _statusOptions = [
    'planifiée',
    'en cours',
    'terminée',
    'annulée',
  ];

  static const Map<String, Color> _statusColors = {
    'planifiée': Color(0xFF1565C0),
    'en cours': Color(0xFFE65100),
    'terminée': Color(0xFF2E7D32),
    'annulée': Color(0xFFB71C1C),
  };

  static const List<String> _dayLabels = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // ── Utilitaires date ──────────────────────────────────────────────────────

  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInsideSelectedWeek(DateTime date) {
    final start = _startOfWeek(_selectedDate);
    final end = start.add(const Duration(days: 7));
    return !date.isBefore(start) && date.isBefore(end);
  }

  String _fmt(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _fmtShort(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  // ── Filtrage ──────────────────────────────────────────────────────────────

  List<Tour> _filteredTours(bool forWeek) {
    return ref.read(appStateProvider).tours.where((tour) {
      final date = DateTime(tour.date.year, tour.date.month, tour.date.day);
      final matchesPeriod = forWeek
          ? _isInsideSelectedWeek(date)
          : _isSameDay(date, _selectedDate);
      if (!matchesPeriod) return false;
      if (_driverFilter != null && tour.driverName != _driverFilter) {
        return false;
      }
      if (_truckFilter != null && tour.truckPlate != _truckFilter) {
        return false;
      }
      if (_statusFilter != null && tour.status != _statusFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.tourNumber.compareTo(b.tourNumber);
      });
  }

  // ── Réaffectation rapide ──────────────────────────────────────────────────

  void _openEditDialog(Tour tour) {
    String driver = tour.driverName;
    String truck = tour.truckPlate;
    String status = tour.status;
    final sectorCtrl = TextEditingController(text: tour.sector ?? '');

    final drivers = ref.read(appStateProvider).drivers.map((d) => d.name).toList()..sort();
    final trucks = ref.read(appStateProvider).trucks.map((t) => t.plate).toList()..sort();

    if (!drivers.contains(driver)) drivers.add(driver);
    if (!trucks.contains(truck)) trucks.add(truck);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Tournée ${tour.tourNumber} — ${_fmt(tour.date)}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: _statusColors[s],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(s),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialog(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: driver,
                  decoration: const InputDecoration(
                    labelText: 'Chauffeur',
                    border: OutlineInputBorder(),
                  ),
                  items: drivers
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialog(() => driver = v ?? driver),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: truck,
                  decoration: const InputDecoration(
                    labelText: 'Camion',
                    border: OutlineInputBorder(),
                  ),
                  items: trucks
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialog(() => truck = v ?? truck),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Secteur',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(appStateProvider).updateTour(
                  tour.id,
                  tour.copyWith(
                    driverName: driver,
                    truckPlate: truck,
                    status: status,
                    sector: sectorCtrl.text.trim().isEmpty
                        ? null
                        : sectorCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final drivers = ref.read(appStateProvider).drivers.map((d) => d.name).toSet().toList()
      ..sort();
    final trucks =
        ref.read(appStateProvider).trucks.map((t) => t.plate).toSet().toList()..sort();

    final tours = _filteredTours(_weekView);
    final planned = tours.where((t) => t.status == 'planifiée').length;
    final running = tours.where((t) => t.status == 'en cours').length;
    final done = tours.where((t) => t.status == 'terminée').length;
    final cancelled = tours.where((t) => t.status == 'annulée').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Titre + bascule vue ──────────────────────────────────────────
        Row(
          children: [
            const Expanded(
              child: Text('Planning exploitation',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.view_day, size: 18),
                  label: Text('Jour'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.view_week, size: 18),
                  label: Text('Semaine'),
                ),
              ],
              selected: {_weekView},
              onSelectionChanged: (s) =>
                  setState(() => _weekView = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Navigation date ──────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _selectedDate = _selectedDate
                        .subtract(Duration(days: _weekView ? 7 : 1));
                  }),
                  child: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Text(
                        _weekView
                            ? '${_fmtShort(_startOfWeek(_selectedDate))} → ${_fmtShort(_startOfWeek(_selectedDate).add(const Duration(days: 6)))}'
                            : _fmt(_selectedDate),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _selectedDate = _selectedDate
                        .add(Duration(days: _weekView ? 7 : 1));
                  }),
                  child: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() => _selectedDate =
                        DateTime(now.year, now.month, now.day));
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text("Aujourd'hui"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Filtres ──────────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _driverFilter,
                    decoration: const InputDecoration(
                      labelText: 'Chauffeur',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Tous')),
                      ...drivers.map((d) => DropdownMenuItem<String>(
                            value: d,
                            child: Text(d),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _driverFilter = v),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _truckFilter,
                    decoration: const InputDecoration(
                      labelText: 'Camion',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Tous')),
                      ...trucks.map((t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _truckFilter = v),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Tous')),
                      ..._statusOptions
                          .map((s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              )),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v),
                  ),
                ),
                if (_driverFilter != null ||
                    _truckFilter != null ||
                    _statusFilter != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _driverFilter = null;
                      _truckFilter = null;
                      _statusFilter = null;
                    }),
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('Effacer'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Compteurs ────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatChip('Total', tours.length, Colors.blueGrey),
              const SizedBox(width: 8),
              _StatChip('Planifiées', planned,
                  _statusColors['planifiée']!),
              const SizedBox(width: 8),
              _StatChip(
                  'En cours', running, _statusColors['en cours']!),
              const SizedBox(width: 8),
              _StatChip(
                  'Terminées', done, _statusColors['terminée']!),
              const SizedBox(width: 8),
              _StatChip(
                  'Annulées', cancelled, _statusColors['annulée']!),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Contenu principal ────────────────────────────────────────────
        if (_weekView)
          _buildWeekGrid()
        else
          _buildDayList(tours),
      ],
    );
  }

  // ── Vue JOUR : liste de cartes ────────────────────────────────────────────

  Widget _buildDayList(List<Tour> tours) {
    if (tours.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Aucune tournée ce jour.')),
        ),
      );
    }

    return Column(
      children: tours.map((t) => _TourCard(
        tour: t,
        statusColors: _statusColors,
        onTap: () => _openEditDialog(t),
        onStatusChange: (s) {
          ref.read(appStateProvider).updateTour(t.id, t.copyWith(status: s));
          setState(() {});
        },
        statusOptions: _statusOptions,
      )).toList(),
    );
  }

  // ── Vue SEMAINE : grille chauffeur × jour ─────────────────────────────────

  Widget _buildWeekGrid() {
    final weekStart = _startOfWeek(_selectedDate);
    final weekDays = List.generate(
        7, (i) => weekStart.add(Duration(days: i)));

    // Tous les chauffeurs qui ont des tournées cette semaine + liste complète
    final allDriverNames = {
      ...ref.read(appStateProvider).drivers.map((d) => d.name),
      ...ref.read(appStateProvider).tours
          .where((t) => _isInsideSelectedWeek(
              DateTime(t.date.year, t.date.month, t.date.day)))
          .map((t) => t.driverName),
    }.toList()
      ..sort();

    // Si filtre chauffeur actif
    final displayDrivers = _driverFilter != null
        ? allDriverNames.where((n) => n == _driverFilter).toList()
        : allDriverNames;

    if (displayDrivers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('Aucun chauffeur à afficher.')),
        ),
      );
    }

    final today = DateTime.now();
    final todayNorm =
        DateTime(today.year, today.month, today.day);

    const colW = 130.0;
    const rowH = 80.0;
    const labelW = 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : labels jours
              Row(
                children: [
                  const SizedBox(width: labelW), // colonne chauffeur
                  ...weekDays.map((day) {
                    final isToday = _isSameDay(day, todayNorm);
                    final isSelected =
                        _isSameDay(day, _selectedDate);
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedDate = day;
                        _weekView = false;
                      }),
                      child: Container(
                        width: colW,
                        height: 44,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Colors.blue.withValues(alpha: 0.15)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.blue, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              _dayLabels[day.weekday - 1],
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color:
                                    isToday ? Colors.blue : null,
                              ),
                            ),
                            Text(
                              '${day.day}/${day.month}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isToday
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const Divider(height: 1),

              // Lignes chauffeurs
              ...displayDrivers.map((driverName) {
                return _WeekRow(
                  driverName: driverName,
                  weekDays: weekDays,
                  truckFilter: _truckFilter,
                  statusFilter: _statusFilter,
                  statusColors: _statusColors,
                  colW: colW,
                  rowH: rowH,
                  labelW: labelW,
                  onTourTap: _openEditDialog,
                  isSameDay: _isSameDay,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget ligne semaine (1 chauffeur × 7 jours) ──────────────────────────────

class _WeekRow extends ConsumerWidget {
  const _WeekRow({
    required this.driverName,
    required this.weekDays,
    required this.truckFilter,
    required this.statusFilter,
    required this.statusColors,
    required this.colW,
    required this.rowH,
    required this.labelW,
    required this.onTourTap,
    required this.isSameDay,
  });

  final String driverName;
  final List<DateTime> weekDays;
  final String? truckFilter;
  final String? statusFilter;
  final Map<String, Color> statusColors;
  final double colW;
  final double rowH;
  final double labelW;
  final void Function(Tour) onTourTap;
  final bool Function(DateTime, DateTime) isSameDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0x15000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label chauffeur
          SizedBox(
            width: labelW,
            height: rowH,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  driverName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // Cellules jours
          ...weekDays.map((day) {
            final toursOnDay = ref.read(appStateProvider).tours.where((t) {
              if (t.driverName != driverName) return false;
              if (!isSameDay(
                  DateTime(t.date.year, t.date.month, t.date.day),
                  day)) return false;
              if (truckFilter != null &&
                  t.truckPlate != truckFilter) return false;
              if (statusFilter != null &&
                  t.status != statusFilter) return false;
              return true;
            }).toList();

            return Container(
              width: colW,
              height: rowH,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: toursOnDay.isEmpty
                  ? const Center(
                      child: Icon(Icons.remove,
                          size: 16, color: Color(0x30000000)),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      children: toursOnDay
                          .map((t) => _TourChip(
                                tour: t,
                                statusColors: statusColors,
                                onTap: () => onTourTap(t),
                              ))
                          .toList(),
                    ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Chip compact pour la grille semaine ───────────────────────────────────────

class _TourChip extends StatelessWidget {
  const _TourChip({
    required this.tour,
    required this.statusColors,
    required this.onTap,
  });

  final Tour tour;
  final Map<String, Color> statusColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColors[tour.status] ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tour.tourNumber,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
            Text(
              tour.truckPlate,
              style:
                  const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte tournée (vue jour) ──────────────────────────────────────────────────

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.statusColors,
    required this.statusOptions,
    required this.onTap,
    required this.onStatusChange,
  });

  final Tour tour;
  final Map<String, Color> statusColors;
  final List<String> statusOptions;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final color = statusColors[tour.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                // Barre couleur statut
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournée ${tour.tourNumber}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      if (tour.companyName != null)
                        Text(tour.companyName!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Sélecteur statut rapide
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: DropdownButton<String>(
                    value: tour.status,
                    isDense: true,
                    underline: const SizedBox(),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    items: statusOptions
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s,
                                  style: TextStyle(
                                      color: statusColors[s],
                                      fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onStatusChange(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Infos
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _infoChip(Icons.person_outline, tour.driverName),
                _infoChip(
                    Icons.local_shipping_outlined, tour.truckPlate),
                if (tour.sector != null)
                  _infoChip(Icons.map_outlined, tour.sector!),
                _infoChip(Icons.speed_outlined,
                    '${tour.kmTotal.toStringAsFixed(0)} km'),
                _infoChip(Icons.people_alt_outlined,
                    '${tour.clientsCount} clients'),
                if (tour.weightKg != null)
                  _infoChip(Icons.scale_outlined,
                      '${tour.weightKg!.toStringAsFixed(0)} kg'),
                if (tour.hasHandling)
                  _infoChip(Icons.handshake_outlined, 'Manutention'),
                if (tour.startTime != null)
                  _infoChip(Icons.schedule_outlined,
                      '${tour.startTime}${tour.endTime != null ? ' → ${tour.endTime}' : ''}'),
              ],
            ),
            const SizedBox(height: 10),

            // Bouton modifier
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ── Compteur stat ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
