class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.cin,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String cin;
  final String? avatarUrl;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'cin': cin,
      'avatarUrl': avatarUrl,
    };
  }

  factory AppUser.fromJson(Map<String, Object?> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      cin: json['cin'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
