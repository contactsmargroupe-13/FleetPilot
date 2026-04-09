import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/models/driver.dart';
import '../screens/models/user_access.dart';

/// Profil utilisateur stocké dans Firestore /users/{uid}
class AppUser {
  final String uid;
  final String email;
  final String name;
  final AccessRole role;
  final String companyId;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': role.name,
    'companyId': companyId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    uid: json['uid'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    role: AccessRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => AccessRole.chauffeur,
    ),
    companyId: json['companyId'] as String,
  );
}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Utilisateur Firebase actuel
  static User? get currentFirebaseUser => _auth.currentUser;

  /// Stream d'état d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inscription manager (crée le compte + la company + le profil)
  static Future<AppUser> registerManager({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    // Créer la company d'abord (ID généré)
    final companyRef = _firestore.collection('companies').doc();

    // Créer le profil utilisateur EN PREMIER (les rules en dépendent)
    final appUser = AppUser(
      uid: uid,
      email: email,
      name: name,
      role: AccessRole.manager,
      companyId: companyRef.id,
    );
    await _firestore.collection('users').doc(uid).set(appUser.toJson());

    // Puis créer la company
    await companyRef.set({
      'name': companyName,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return appUser;
  }

  /// Créer une invitation pour un membre (chauffeur/comptable)
  /// L'invitation est stockée dans Firestore, le membre crée son compte lui-même
  static Future<void> inviteMember({
    required String email,
    required String name,
    required AccessRole role,
    required String companyId,
  }) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('invitations')
        .doc(email.toLowerCase())
        .set({
      'email': email.toLowerCase(),
      'name': name,
      'role': role.name,
      'companyId': companyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Inscription membre — rattachement automatique à la company.
  ///
  /// Cherche dans l'ordre :
  /// 1. Une fiche chauffeur avec cet email (collection `drivers`) → rôle chauffeur
  /// 2. Une invitation explicite (collection `invitations`) → rôle comptable/manager
  ///
  /// Dans le cas 1 aucun "invite" n'est nécessaire côté manager : créer la fiche
  /// chauffeur avec son email suffit à lui donner accès.
  static Future<AppUser> registerWithInvite({
    required String email,
    required String password,
  }) async {
    final lower = email.toLowerCase();

    // Crée d'abord le compte Firebase — nécessaire pour que les règles
    // `request.auth.token.email` autorisent la lecture des drivers/invitations.
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    try {
      // 1. Cherche une fiche chauffeur correspondante dans n'importe quelle company
      final driverQuery = await _firestore
          .collectionGroup('drivers')
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        final driverDoc = driverQuery.docs.first;
        // Chemin : companies/{companyId}/drivers/{driverId}
        final companyId = driverDoc.reference.parent.parent!.id;
        final driver = Driver.fromJson(driverDoc.data());
        final appUser = AppUser(
          uid: uid,
          email: lower,
          name: driver.fullName,
          role: AccessRole.chauffeur,
          companyId: companyId,
        );
        await _firestore.collection('users').doc(uid).set(appUser.toJson());
        return appUser;
      }

      // 2. Sinon, cherche une invitation explicite (comptable / co-manager)
      final inviteQuery = await _firestore
          .collectionGroup('invitations')
          .where('email', isEqualTo: lower)
          .limit(1)
          .get();

      if (inviteQuery.docs.isEmpty) {
        throw Exception('Aucun accès trouvé pour cet email. '
            'Demandez à votre manager de vous ajouter comme chauffeur ou comptable.');
      }

      final invite = inviteQuery.docs.first.data();
      final appUser = AppUser(
        uid: uid,
        email: lower,
        name: invite['name'] as String,
        role: AccessRole.values.firstWhere(
          (e) => e.name == invite['role'],
          orElse: () => AccessRole.chauffeur,
        ),
        companyId: invite['companyId'] as String,
      );
      await _firestore.collection('users').doc(uid).set(appUser.toJson());
      await inviteQuery.docs.first.reference.delete();
      return appUser;
    } catch (e) {
      // Rollback du compte Firebase si le rattachement a échoué
      try {
        await cred.user?.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Connexion email/password
  static Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return await getAppUser(cred.user!.uid);
  }

  /// Récupérer le profil AppUser depuis Firestore
  static Future<AppUser> getAppUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('Profil utilisateur introuvable');
    }
    return AppUser.fromJson(doc.data()!);
  }

  /// Déconnexion
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Réinitialisation mot de passe
  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
