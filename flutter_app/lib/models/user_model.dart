class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String preferredLanguage;
  final String currency;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.preferredLanguage,
    required this.currency,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        preferredLanguage: json['preferred_language'] as String? ?? 'ar',
        currency: json['currency'] as String? ?? 'IQD',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'preferred_language': preferredLanguage,
        'currency': currency,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? preferredLanguage,
    String? currency,
  }) =>
      UserModel(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        currency: currency ?? this.currency,
        isActive: isActive,
        createdAt: createdAt,
      );
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}
