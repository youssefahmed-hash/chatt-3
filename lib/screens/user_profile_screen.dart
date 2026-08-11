import 'package:flutter/material.dart';
import '../../utils/date_formatter.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() =>
      _UserProfileScreenState();
}

class _UserProfileScreenState
    extends State<UserProfileScreen> {

  UserProfile? profile;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      profile = await ApiService.getUserProfile(
        widget.userId,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Profile"),
        ),
        body: const Center(
          child: Text("User not found"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [

              CircleAvatar(
                radius: 60,
                backgroundImage:
                profile!.avatarUrl.isNotEmpty
                    ? NetworkImage(
                  "${ApiConfig.baseUrl}${profile!.avatarUrl}",
                )
                    : null,
                child: profile!.avatarUrl.isEmpty
                    ? const Icon(
                  Icons.person,
                  size: 60,
                )
                    : null,
              ),

              const SizedBox(height: 25),

              Text(
                profile!.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                profile!.email,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 25),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("About"),
                  subtitle: Text(
                    profile!.bio.isEmpty
                        ? "No bio"
                        : profile!.bio,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Card(
                child: ListTile(
                  leading: Icon(
                    profile!.online
                        ? Icons.circle
                        : Icons.access_time,
                    color: profile!.online
                        ? Colors.green
                        : Colors.grey,
                  ),
                  title: Text(
                    profile!.online
                        ? "Online"
                        : "Last seen",
                  ),
                    subtitle: Text(
                      profile!.online
                          ? "Active now"
                          : DateFormatter.formatLastSeen(
                        profile!.lastSeen,
                      ),
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}