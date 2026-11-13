import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../screens/models/driver.dart';

/// Ce qu'un QR code collé dans un camion contient.
class QrLink {
  final String key;
  final String? plate;
  const QrLink(this.key, this.plate);
}

/// Un chauffeur proposé après le scan.
class QrDriver {
  final String name, label, loginEmail;
  const QrDriver(this.name, this.label, this.loginEmail);
}

class QrRoster {
  final String companyId, companyName;
  final List<QrDriver> drivers;
  const QrRoster(this.companyId, this.companyName, this.drivers);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Accès chauffeur « QR + PIN ».
///
/// Chaque chauffeur a un vrai compte Firebase Auth dont l'identifiant est
/// généré et le mot de passe dérivé de son PIN. Le PIN n'est donc vérifié
/// que par Firebase, qui bloque les tentatives répétées, et toutes les
/// règles Firestore existantes (`driverEmail == token.email`) s'appliquent
/// telles quelles.
/// ─────────────────────────────────────────────────────────────────────────
class QrAccessService {
  static const hostingUrl = 'https://fleetpilote.web.app';
  static const _loginDomain = 'chauffeurs.fleetpilote.app';

  static String _password(String pin) => 'fleetpilote-pin:$pin';

  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  // ── Lien ─────────────────────────────────────────────────────────────

  static String truckUrl(String key, String plate) => Uri.parse(hostingUrl)
      .replace(queryParameters: {'qr': key, 'camion': plate})
      .toString();

  static QrLink? parse(Uri uri) {
    final key = uri.queryParameters['qr'];
    if (key == null || key.isEmpty) return null;
    final plate = uri.queryParameters['camion'];
    return QrLink(key, (plate == null || plate.isEmpty) ? null : plate);
  }

  // ── Côté chauffeur ───────────────────────────────────────────────────

  /// Lisible sans être connecté : la clé du QR suffit.
  static Future<QrRoster?> loadRoster(String key) async {
    final doc =
        await FirebaseFirestore.instance.collection('qr_access').doc(key).get();
    final data = doc.data();
    if (data == null) return null;
    final list = (data['drivers'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => QrDriver(
              m['name'] as String,
              (m['label'] as String?) ?? m['name'] as String,
              m['loginEmail'] as String,
            ))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return QrRoster(
      data['companyId'] as String,
      (data['companyName'] as String?) ?? '',
      list,
    );
  }

  static Future<void> signIn(String loginEmail, String pin) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: _password(pin),
      );

  // ── Côté manager ─────────────────────────────────────────────────────

  /// Crée le compte de connexion d'un chauffeur et renvoie son identifiant.
  ///
  /// Le compte est créé dans une seconde instance Firebase, sinon la
  /// création connecterait ce nouveau compte à la place du manager.
  ///
  /// Un mot de passe Firebase ne peut pas être changé par un tiers : changer
  /// le PIN crée donc un nouveau compte. L'ancien n'a plus accès à rien, car
  /// ses documents portent désormais le nouvel identifiant.
  ///
  /// [linkToDriver] enregistre l'identifiant sur la fiche chauffeur. Il est
  /// appelé avant la création du profil `users/{uid}` : les règles Firestore
  /// n'acceptent ce profil que si la fiche porte déjà cet identifiant.
  static Future<String> createPinAccount({
    required String companyId,
    required Driver driver,
    required String pin,
    required Future<void> Function(String loginEmail) linkToDriver,
  }) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('Le PIN doit faire 4 à 6 chiffres.');
    }
    final app = await _provisioningApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final email = '${_randomId()}@$_loginDomain';

    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: _password(pin),
    );
    try {
      await linkToDriver(email);
      // Écrit en tant que le nouveau compte : la règle `users/{uid}` l'exige.
      await FirebaseFirestore.instanceFor(app: app)
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'uid': cred.user!.uid,
        'email': email,
        'name': driver.fullName,
        'role': 'chauffeur',
        'companyId': companyId,
        'driverName': driver.name,
      });
    } catch (e) {
      await cred.user?.delete();
      rethrow;
    } finally {
      await auth.signOut();
    }
    return email;
  }

  static Future<FirebaseApp> _provisioningApp() async {
    const name = 'pin-provisioning';
    for (final a in Firebase.apps) {
      if (a.name == name) return a;
    }
    return Firebase.initializeApp(
      name: name,
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  static String _randomId() {
    const alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return 'c-${List.generate(16, (_) => alphabet[rnd.nextInt(alphabet.length)]).join()}';
  }
}
