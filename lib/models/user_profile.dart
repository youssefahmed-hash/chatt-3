class UserProfile {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String bio;
  final bool online;
  final String? lastSeen;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    required this.online,
    this.lastSeen,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      bio: json['bio'] ?? '',
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'],
    );
  }
}