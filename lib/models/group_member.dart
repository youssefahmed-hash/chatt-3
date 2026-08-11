class GroupMember {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  GroupMember({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }
}