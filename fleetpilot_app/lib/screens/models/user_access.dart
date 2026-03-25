enum AccessRole {
  manager,
  comptable,
}

String accessRoleLabel(AccessRole role) {
  switch (role) {
    case AccessRole.manager:
      return 'Manager';
    case AccessRole.comptable:
      return 'Comptable';
  }
}

String accessRoleDescription(AccessRole role) {
  switch (role) {
    case AccessRole.manager:
      return 'Accès complet à toutes les fonctionnalités';
    case AccessRole.comptable:
      return 'Dépenses, facturation, URSSAF, actifs';
  }
}

/// Pages accessibles par rôle
const Map<AccessRole, Set<String>> rolePages = {
  AccessRole.manager: {
    'dashboard', 'flotte', 'chauffeurs', 'camions', 'materiel',
    'commissionnaires', 'actifs', 'depenses', 'facturation', 'urssaf',
    'administratif', 'recrutement', 'messages', 'ia_chat', 'scan', 'rapport_ia',
    'parametres', 'planning', 'tournees',
  },
  AccessRole.comptable: {
    'dashboard', 'depenses', 'facturation', 'urssaf', 'actifs',
    'commissionnaires', 'tournees',
  },
};

class UserAccess {
  final String id;
  final String name;
  final AccessRole role;
  final String pinHash;

  const UserAccess({
    required this.id,
    required this.name,
    required this.role,
    required this.pinHash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'pinHash': pinHash,
  };

  factory UserAccess.fromJson(Map<String, dynamic> json) => UserAccess(
    id: json['id'] as String,
    name: json['name'] as String,
    role: AccessRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => AccessRole.comptable,
    ),
    pinHash: json['pinHash'] as String,
  );
}
