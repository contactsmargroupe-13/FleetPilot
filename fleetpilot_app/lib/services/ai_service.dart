import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'company_settings.dart';

class AiService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';

  static Map<String, String> get _headers => {
        'x-api-key': CompanySettings.claudeApiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
        'content-type': 'application/json',
      };

  /// Chat IA : envoie le contexte flotte + question, retourne la réponse
  static Future<String> chat({
    required String fleetContext,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    if (CompanySettings.claudeApiKey.isEmpty) {
      return 'Clé API non configurée. Va dans Paramètres > IA.';
    }

    try {
      final messages = <Map<String, dynamic>>[
        ...history.map((h) => {'role': h['role'], 'content': h['content']}),
        {
          'role': 'user',
          'content': userMessage,
        },
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'system':
              'Tu es l\'assistant IA de FleetPilot, une app de gestion de flotte de transport. '
              'Réponds en français, de manière concise et utile. '
              'Utilise les données fournies pour donner des réponses précises.\n\n'
              'DONNÉES DE LA FLOTTE :\n$fleetContext',
          'messages': messages,
        }),
      );

      if (response.statusCode != 200) {
        return 'Erreur API (${response.statusCode}). Vérifie ta clé.';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['content'] as List).first['text'] as String;
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  /// Scan intelligent de document (tout type)
  static Future<Map<String, dynamic>> scanDocument(
      Uint8List imageBytes, String mimeType) async {
    if (CompanySettings.claudeApiKey.isEmpty) {
      return {'error': 'Clé API non configurée.'};
    }

    try {
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 512,
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
                      'Analyse ce document professionnel. Identifie le type et extrais les infos.\n'
                      'Réponds UNIQUEMENT avec ce JSON :\n'
                      '{\n'
                      '  "type": "carburant" | "assurance" | "facture" | "contrat" | "fiche_paie" | "amende" | "autre",\n'
                      '  "montant": <nombre ou null>,\n'
                      '  "date": <"YYYY-MM-DD" ou null>,\n'
                      '  "fournisseur": <"nom" ou null>,\n'
                      '  "description": <"résumé court" ou null>,\n'
                      '  "immatriculation": <"plaque camion" ou null>,\n'
                      '  "personne": <"nom personne" ou null>,\n'
                      '  "date_debut": <"YYYY-MM-DD" ou null>,\n'
                      '  "date_fin": <"YYYY-MM-DD" ou null>,\n'
                      '  "litres": <nombre ou null>,\n'
                      '  "station": <"nom station" ou null>\n'
                      '}',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        return {'error': 'Erreur API (${response.statusCode})'};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['content'] as List).first['text'] as String;

      final jsonMatch = RegExp(r'\{[\s\S]*?\}').firstMatch(text);
      if (jsonMatch == null) return {'error': 'Réponse illisible'};

      return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Erreur : $e'};
    }
  }

  /// Génère un rapport mensuel IA
  static Future<String> generateMonthlyReport({
    required String fleetContext,
    required String monthLabel,
  }) async {
    if (CompanySettings.claudeApiKey.isEmpty) {
      return 'Clé API non configurée.';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 2048,
          'messages': [
            {
              'role': 'user',
              'content':
                  'En tant qu\'analyste de flotte transport, génère un rapport mensuel complet pour $monthLabel.\n\n'
                  'DONNÉES :\n$fleetContext\n\n'
                  'Structure du rapport :\n'
                  '1. RÉSUMÉ EXÉCUTIF (3-4 lignes)\n'
                  '2. POINTS FORTS du mois\n'
                  '3. POINTS D\'ATTENTION\n'
                  '4. ANALYSE PAR CAMION (rentabilité, consommation)\n'
                  '5. RECOMMANDATIONS CONCRÈTES\n'
                  '6. PRÉVISIONS pour le mois suivant\n\n'
                  'Sois concis, factuel, et donne des chiffres précis.',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        return 'Erreur API (${response.statusCode})';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['content'] as List).first['text'] as String;
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  /// Analyse prédictive : détecte les anomalies
  static Future<List<String>> detectAnomalies({
    required String fleetContext,
  }) async {
    if (CompanySettings.claudeApiKey.isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 512,
          'messages': [
            {
              'role': 'user',
              'content':
                  'Analyse ces données de flotte transport et détecte les anomalies ou tendances inquiétantes.\n\n'
                  'DONNÉES :\n$fleetContext\n\n'
                  'Réponds UNIQUEMENT avec un JSON array de strings, chaque string étant une alerte courte (1 ligne). '
                  'Si rien d\'anormal, retourne []. Exemple : ["Camion X : conso +20% vs moyenne", "Chauffeur Y : 5 absences"]',
            },
          ],
        }),
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['content'] as List).first['text'] as String;

      final jsonMatch = RegExp(r'\[[\s\S]*?\]').firstMatch(text);
      if (jsonMatch == null) return [];

      final list = jsonDecode(jsonMatch.group(0)!) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
