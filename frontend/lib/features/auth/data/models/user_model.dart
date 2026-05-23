class UserModel {
  final int userId;
  final String fullName;
  final String username;
  final String role;
  final bool activeStatus;

  UserModel({required this.userId, required this.fullName, required this.username, required this.role, required this.activeStatus});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'],
      fullName: json['full_name'],
      username: json['username'],
      role: json['role'],
      activeStatus: json['active_status'] ?? true,
    );
  }
}

class AuthToken {
  final String accessToken;
  final int userId;
  final String fullName;
  final String role;

  AuthToken({required this.accessToken, required this.userId, required this.fullName, required this.role});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'],
      userId: json['user_id'],
      fullName: json['full_name'],
      role: json['role'],
    );
  }
}
