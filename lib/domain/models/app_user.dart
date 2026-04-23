class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.cin,
  });

  final String id;
  final String fullName;
  final String email;
  final String cin;

  Map<String, Object?> toJson() {
    return {'id': id, 'fullName': fullName, 'email': email, 'cin': cin};
  }

  factory AppUser.fromJson(Map<String, Object?> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      cin: json['cin'] as String,
    );
  }
}
