import 'package:flutter/material.dart';
import 'models/tour.dart';

class TourDetailPage extends StatelessWidget {
  final Tour tour;

  const TourDetailPage({
    super.key,
    required this.tour,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tournée ${tour.tourNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Informations générales'),
            _row('Date', _fmt(tour.date)),
            _row('Numéro tournée', tour.tourNumber),
            _row('Statut', tour.status),
            _row('Chauffeur', tour.driverName),
            _row('Camion', tour.truckPlate),
            _row('Entreprise', tour.companyName ?? '—'),

            const SizedBox(height: 20),

            _sectionTitle('Horaires'),
            _row('Heure début', tour.startTime ?? '—'),
            _row('Heure fin', tour.endTime ?? '—'),
            _row('Pause', tour.breakTime ?? '—'),

            const SizedBox(height: 20),

            _sectionTitle('Transport'),
            _row('KM total', '${tour.kmTotal.toStringAsFixed(0)} km'),
            _row('Clients', '${tour.clientsCount}'),
            _row('Poids',
                tour.weightKg != null
                    ? '${tour.weightKg!.toStringAsFixed(0)} kg'
                    : '—'),
            _row('Secteur', tour.sector ?? '—'),

            const SizedBox(height: 20),

            _sectionTitle('Manutention'),
            _row('Manutention', tour.hasHandling ? 'Oui' : 'Non'),
            if (tour.hasHandling) ...[
              _row('Client manutention', tour.handlingClientName ?? '—'),
              _row('Date manutention',
                  tour.handlingDate != null ? _fmt(tour.handlingDate!) : '—'),
            ],

            const SizedBox(height: 20),

            _sectionTitle('Extras'),
            _row('Extra KM', '${tour.extraKm.toStringAsFixed(0)} km'),
            _row('Tour supplémentaire', tour.extraTour ? 'Oui' : 'Non'),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text('$label :',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
