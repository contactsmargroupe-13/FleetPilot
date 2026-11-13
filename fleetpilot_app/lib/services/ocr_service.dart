import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'company_settings.dart';

class OcrResult {
  final double? amount;
  final double? liters;
  final double? pricePerLiter;
  final DateTime? date;
  final String? station;
  final String? error;

  const OcrResult({
    this.amount,
    this.liters,
    this.pricePerLiter,
    this.date,
    this.station,
    this.error,
  });
}

class OcrService {
  static Future<OcrResult> analyze(Uint8List imageBytes, String mimeType) async {
    final apiKey = CompanySettings.claudeApiKey;
    if (apiKey.isEmpty) {
      return const OcrResult(
        error: 'Clé API non configurée. Va dans Paramètres > IA pour l\'ajouter.',
      );
    }

    try {
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 256,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mimeType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text':
                      'Analyse ce ticket de carburant. Réponds UNIQUEMENT avec ce JSON (sans texte autour) :\n'
                      '{"montant_total": <nombre ou null>, "litres": <nombre ou null>, "prix_par_litre": <nombre ou null>, "date": <"YYYY-MM-DD" ou null>, "station": <"nom" ou null>}',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        return OcrResult(
          error: 'Erreur API ${response.statusCode}. Vérifie ta clé dans Paramètres.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['content'] as List).first['text'] as String;

      final jsonMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
      if (jsonMatch == null) {
        return const OcrResult(error: 'Réponse IA illisible. Réessaie.');
      }

      final extracted = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      DateTime? date;
      if (extracted['date'] != null) {
        try {
          date = DateTime.parse(extracted['date'] as String);
        } catch (_) {}
      }

      return OcrResult(
        amount: extracted['montant_total'] != null
            ? (extracted['montant_total'] as num).toDouble()
            : null,
        liters: extracted['litres'] != null
            ? (extracted['litres'] as num).toDouble()
            : null,
        pricePerLiter: extracted['prix_par_litre'] != null
            ? (extracted['prix_par_litre'] as num).toDouble()
            : null,
        date: date,
        station: extracted['station'] as String?,
      );
    } catch (e) {
      return OcrResult(error: 'Erreur réseau : $e');
    }
  }

  /// Lit le compteur kilométrique total (pas le compteur journalier) sur la
  /// photo d'un tableau de bord. Null si illisible : le chauffeur tape alors
  /// le chiffre lui-même.
  static Future<OdometerOcr> readOdometer(
      Uint8List imageBytes, String mimeType) async {
    final apiKey = CompanySettings.claudeApiKey;
    if (apiKey.isEmpty) {
      return const OdometerOcr(error: 'Lecture automatique indisponible.');
    }
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 64,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mimeType,
                    'data': base64Encode(imageBytes),
                  },
                },
                {
                  'type': 'text',
                  'text':
                      'Photo du tableau de bord d\'un utilitaire. Lis le compteur '
                      'kilométrique TOTAL (odomètre), pas le compteur journalier '
                      '(trip) ni l\'autonomie. Réponds UNIQUEMENT avec ce JSON :\n'
                      '{"km": <nombre entier ou null si illisible>}',
                },
              ],
            },
          ],
        }),
      );
      if (response.statusCode != 200) {
        return OdometerOcr(error: 'Erreur API ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['content'] as List).first['text'] as String;
      final m = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
      if (m == null) return const OdometerOcr(error: 'Compteur illisible.');
      final km = (jsonDecode(m.group(0)!) as Map<String, dynamic>)['km'];
      return km is num
          ? OdometerOcr(km: km.round())
          : const OdometerOcr(error: 'Compteur illisible.');
    } catch (e) {
      return OdometerOcr(error: 'Erreur réseau : $e');
    }
  }
}

class OdometerOcr {
  final int? km;
  final String? error;
  const OdometerOcr({this.km, this.error});
}
