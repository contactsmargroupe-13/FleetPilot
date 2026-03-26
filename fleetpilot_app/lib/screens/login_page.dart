import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/design_constants.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginPage({super.key, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;
  bool _obscure = true;
  String? _error;

  // Champs inscription
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        await AuthService.registerManager(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          companyName: _companyCtrl.text.trim(),
        );
      } else {
        await AuthService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      // Succès — le StreamBuilder dans app.dart détecte le login
      // et redirige automatiquement, pas besoin de faire plus ici
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _firebaseErrorMessage(e.code));
    } catch (e) {
      // Si l'auth a réussi mais Firestore a eu un souci,
      // on laisse le StreamBuilder gérer la suite
      if (AuthService.currentFirebaseUser != null) return;
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte avec cet email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères min.)';
      case 'invalid-email':
        return 'Email invalide';
      case 'too-many-requests':
        return 'Trop de tentatives, réessayez plus tard';
      default:
        return 'Erreur : $code';
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entrez votre email pour réinitialiser');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de réinitialisation envoyé')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _firebaseErrorMessage(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DC.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    DC.logo(size: 32),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister ? 'Créer votre compte' : 'Connexion',
                      style: DC.title(20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegister
                          ? 'Inscrivez-vous pour gérer votre flotte'
                          : 'Connectez-vous à votre espace',
                      style: DC.body(14, color: DC.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // Champs inscription
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Votre nom',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _companyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom de l\'entreprise',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        if (v.length < 6) return '6 caractères minimum';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Erreur
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: DC.errorBg,
                          borderRadius: BorderRadius.circular(DC.rChip),
                          border: Border.all(color: DC.errorBorder),
                        ),
                        child: Text(_error!,
                            style: DC.body(13, color: DC.error)),
                      ),

                    // Mot de passe oublié
                    if (!_isRegister)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: Text('Mot de passe oublié ?',
                              style: DC.body(13, color: DC.primary)),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Bouton principal
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isRegister ? 'Créer le compte' : 'Se connecter'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle inscription/connexion
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegister
                              ? 'Déjà un compte ?'
                              : 'Pas encore de compte ?',
                          style: DC.body(14, color: DC.textSecondary),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          }),
                          child: Text(
                            _isRegister ? 'Se connecter' : 'S\'inscrire',
                            style: DC.body(14,
                                weight: FontWeight.w600, color: DC.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
