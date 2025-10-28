import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'user_plan.dart';
import 'usuario.dart' as db_user;

class User {
  final String id;
  final String email;
  final String? displayName;
  final String? alias;
  final DateTime? birthDate;
  final String? nationality;
  final String? profileImageUrl;
  final UserPlan userPlan;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.alias,
    this.birthDate,
    this.nationality,
    this.profileImageUrl,
    this.userPlan = UserPlan.premium,
    required this.createdAt,
    required this.updatedAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? alias,
    DateTime? birthDate,
    String? nationality,
    String? profileImageUrl,
    UserPlan? userPlan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      alias: alias ?? this.alias,
      birthDate: birthDate ?? this.birthDate,
      nationality: nationality ?? this.nationality,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      userPlan: userPlan ?? this.userPlan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'alias': alias,
      'birthDate': birthDate?.toIso8601String(),
      'nationality': nationality,
      'profileImageUrl': profileImageUrl,
      'userPlan': userPlan.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      displayName: map['displayName'],
      alias: map['alias'],
      birthDate: map['birthDate'] != null
          ? DateTime.parse(map['birthDate'])
          : null,
      nationality: map['nationality'],
      profileImageUrl: map['profileImageUrl'],
      userPlan: map['userPlan'] != null
          ? UserPlan.values.firstWhere(
              (plan) => plan.name == map['userPlan'],
              orElse: () => UserPlan.premium,
            )
          : UserPlan.premium,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  factory User.fromFirebaseUser(firebase_auth.User firebaseUser) {
    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName:
          firebaseUser.displayName ?? firebaseUser.email?.split('@')[0],
      alias: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0],
      profileImageUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: firebaseUser.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  factory User.fromUsuario(
    db_user.Usuario usuario,
    firebase_auth.User firebaseUser,
  ) {
    return User(
      id: firebaseUser.uid,
      email: usuario.email,
      alias: usuario.alias,
      birthDate: usuario.fechaNacimiento,
      createdAt: usuario.fechaCreacion,
      updatedAt: usuario.fechaActualizacion,
    );
  }
}
