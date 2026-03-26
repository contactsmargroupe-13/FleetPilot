import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    // Créer la company
    final companyRef = _firestore.collection('companies').doc();
    await companyRef.set({
      'name': companyName,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Créer le profil utilisateur
    final appUser = AppUser(
      uid: uid,
      email: email,
      name: name,
      role: AccessRole.manager,
      companyId: companyRef.id,
    );
    await _firestore.collection('users').doc(uid).set(appUser.toJson());

    return appUser;
  }

  /// Inscription membre (chauffeur/comptable) — invité par le manager
  static Future<AppUser> registerMember({
    required String email,
    required String password,
    required String name,
    required AccessRole role,
    required String companyId,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final appUser = AppUser(
      uid: uid,
      email: email,
      name: name,
      role: role,
      companyId: companyId,
    );
    await _firestore.collection('users').doc(uid).set(appUser.toJson());

    return appUser;
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
