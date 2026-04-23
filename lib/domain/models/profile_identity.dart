import 'app_user.dart';

class ProfileIdentity {
  const ProfileIdentity({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.institution,
    required this.levelClass,
    required this.avatarPath,
  });

  final String userId;
  final String fullName;
  final String email;
  final String institution;
  final String levelClass;
  final String? avatarPath;

  static const defaultAvatar = 'images/cc.jpg';

  factory ProfileIdentity.fromUser(AppUser? user) {
    return ProfileIdentity(
      userId: user?.id ?? 'guest',
      fullName: user?.fullName ?? 'Student',
      email: user?.email ?? 'student@studyflow.local',
      institution: 'University of Technology',
      levelClass: 'Computer Science - Year 3',
      avatarPath: defaultAvatar,
    );
  }

  ProfileIdentity copyWith({
    String? fullName,
    String? email,
    String? institution,
    String? levelClass,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return ProfileIdentity(
      userId: userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      institution: institution ?? this.institution,
      levelClass: levelClass ?? this.levelClass,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'institution': institution,
      'levelClass': levelClass,
      'avatarPath': avatarPath,
    };
  }

  factory ProfileIdentity.fromJson(Map<String, Object?> json) {
    return ProfileIdentity(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      institution:
          (json['institution'] as String?) ?? 'University of Technology',
      levelClass:
          (json['levelClass'] as String?) ?? 'Computer Science - Year 3',
      avatarPath: json['avatarPath'] as String?,
    );
  }
}
