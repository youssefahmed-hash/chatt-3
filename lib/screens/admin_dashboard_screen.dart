import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'chat_list_screen.dart';
import 'login_screen.dart';
import 'server_setup_wizard_screen.dart';
import 'package:http/http.dart' as http;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Service statuses
  bool _postgresRunning = false;
  bool _nodeRunning = false;
  bool _cloudflareRunning = false;
  bool _apiHealthy = false;
  bool _checkingStatus = true;
  Timer? _statusTimer;

  // Settings form states
  final _smtpEmailCtrl = TextEditingController();
  final _smtpPassCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _testEmailCtrl = TextEditingController();

  // Admin credentials form states
  final _adminEmailChangeCtrl = TextEditingController();
  final _adminPassChangeCtrl = TextEditingController();
  bool _savingAdminCreds = false;
  String? _adminCredsError;
  String? _adminCredsSuccess;

  bool _loadingSettings = false;
  bool _savingSettings = false;
  bool _sendingTestOtp = false;
  String? _settingsError;
  String? _settingsSuccess;

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _loadSettings();
    // Poll status every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkServerStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _smtpEmailCtrl.dispose();
    _smtpPassCtrl.dispose();
    _adminEmailCtrl.dispose();
    _testEmailCtrl.dispose();
    _adminEmailChangeCtrl.dispose();
    _adminPassChangeCtrl.dispose();
    super.dispose();
  }

  bool _isChecking = false;

  Future<void> _checkServerStatus() async {
    if (!mounted) return;
    if (_isChecking) return;
    _isChecking = true;

    final domain = ApiConfig.baseUrl.replaceAll("https://", "").replaceAll("http://", "");
    final isInstalled = domain.contains('.') && !domain.contains("10.0.2.2") && !domain.contains("localhost");

    if (!isInstalled) {
      if (mounted) {
        setState(() {
          _postgresRunning = false;
          _nodeRunning = false;
          _cloudflareRunning = false;
          _apiHealthy = false;
          _checkingStatus = false;
        });
      }
      _isChecking = false;
      return;
    }
    
    bool pg = false;
    bool node = false;
    bool cf = false;
    bool api = false;

    try {
      // 1. Check Node.js local health via http request
      try {
        final nodeResponse = await http.get(Uri.parse("http://127.0.0.1:4000/health")).timeout(const Duration(seconds: 2));
        node = nodeResponse.statusCode == 200 && nodeResponse.body.contains('"status":"ok"');
      } catch (_) {}

      // 2. Check Public API Health
      api = await ApiService.getProfile().then((_) => true).catchError((_) => false);

      // 3. Infer Database and Cloudflared statuses (resilient, no Termux permission needed)
      pg = node || api;
      cf = api;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _postgresRunning = pg;
        _nodeRunning = node;
        _cloudflareRunning = cf;
        _apiHealthy = api;
        _checkingStatus = false;
      });
    }
    _isChecking = false;
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loadingSettings = true;
      _settingsError = null;
    });

    try {
      final settings = await ApiService.getSettings();
      _smtpEmailCtrl.text = settings['email'] ?? '';
      _adminEmailCtrl.text = settings['adminEmail'] ?? '';
      _smtpPassCtrl.text = ""; // Passwords are not returned

      // Load profile info for credentials editing
      final profile = await ApiService.getProfile();
      _adminEmailChangeCtrl.text = profile.email;
    } catch (e) {
      setState(() {
        _settingsError = "Failed to load SMTP settings: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSettings = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _savingSettings = true;
      _settingsError = null;
      _settingsSuccess = null;
    });

    try {
      await ApiService.updateSettings(
        email: _smtpEmailCtrl.text.trim(),
        password: _smtpPassCtrl.text.isNotEmpty ? _smtpPassCtrl.text : null,
        adminEmail: _adminEmailCtrl.text.trim(),
      );
      setState(() {
        _settingsSuccess = "SMTP settings updated successfully.";
        _smtpPassCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _settingsError = "Failed to update SMTP settings: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingSettings = false;
        });
      }
    }
  }

  Future<void> _saveAdminCreds() async {
    if (_adminEmailChangeCtrl.text.trim().isEmpty || _adminPassChangeCtrl.text.isEmpty) {
      setState(() {
        _adminCredsError = "Email and password cannot be empty.";
      });
      return;
    }

    setState(() {
      _savingAdminCreds = true;
      _adminCredsError = null;
      _adminCredsSuccess = null;
    });

    try {
      await AuthService.changeCredentials(
        _adminEmailChangeCtrl.text.trim(),
        _adminPassChangeCtrl.text,
      );
      setState(() {
        _adminCredsSuccess = "Administrator credentials updated successfully.";
        _adminPassChangeCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _adminCredsError = "Failed to update credentials: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingAdminCreds = false;
        });
      }
    }
  }

  Future<void> _sendTestOtp() async {
    if (_testEmailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a destination email address.")),
      );
      return;
    }

    setState(() {
      _sendingTestOtp = true;
      _settingsError = null;
      _settingsSuccess = null;
    });

    try {
      await ApiService.testOtp(_testEmailCtrl.text.trim());
      setState(() {
        _settingsSuccess = "Test OTP sent successfully to ${_testEmailCtrl.text.trim()}.";
      });
    } catch (e) {
      setState(() {
        _settingsError = "Failed to send Test OTP: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingTestOtp = false;
        });
      }
    }
  }



  Widget _buildStatusRow(String name, bool isOnline, {String? extraInfo}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.check_circle : Icons.error,
            color: isOnline ? const Color(0xFF25D366) : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            extraInfo ?? (isOnline ? "Running" : "Stopped"),
            style: TextStyle(
              color: isOnline ? const Color(0xFF25D366) : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domain = ApiConfig.baseUrl.replaceAll("https://", "").replaceAll("http://", "");
    final isInstalled = domain.contains('.') && !domain.contains("10.0.2.2") && !domain.contains("localhost");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatt Server Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Operational Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF075E54), const Color(0xFF1F2E2C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Server Node Platform",
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isInstalled ? "Self-Hosted" : "Dev Mock",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isInstalled ? "https://$domain" : "Local Developer Environment",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (_checkingStatus)
                      const Center(child: CircularProgressIndicator(color: Colors.white))
                    else ...[
                      _buildStatusRow("PostgreSQL Database", _postgresRunning),
                      _buildStatusRow("Node.js Backend", _nodeRunning),
                      _buildStatusRow("Cloudflare Tunnel", _cloudflareRunning),
                      _buildStatusRow("API Routing Integration", _apiHealthy, extraInfo: _apiHealthy ? "Healthy" : "Unhealthy"),
                    ],
                    const SizedBox(height: 20),
                    if (isInstalled) ...[
                      const Center(
                        child: Text(
                          "Manage server state manually inside the Termux app.",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      )
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ServerSetupWizardScreen()),
                                );
                              },
                              icon: const Icon(Icons.install_mobile),
                              label: const Text("Install Server Platform"),
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Open Client App Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF075E54), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF075E54)),
                label: const Text("Open Chat Client UI", style: TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),

            // SMTP settings title
            const Text("Gmail OTP & SMTP Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            if (_loadingSettings)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _smtpEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: "Gmail Sender Address",
                          hintText: "example@gmail.com",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smtpPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Gmail App Password",
                          hintText: "•••••••••••••••• (Leave blank to keep current)",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _adminEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: "Administrator Alert Email",
                          hintText: "admin@example.com",
                        ),
                      ),
                      if (_settingsError != null) ...[
                        const SizedBox(height: 12),
                        Text(_settingsError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      if (_settingsSuccess != null) ...[
                        const SizedBox(height: 12),
                        Text(_settingsSuccess!, style: const TextStyle(color: Color(0xFF25D366), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _savingSettings ? null : _saveSettings,
                          child: _savingSettings
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Save SMTP Configuration"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Admin Account Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _adminEmailChangeCtrl,
                        decoration: const InputDecoration(
                          labelText: "Admin Username / Email",
                          hintText: "admin@example.com",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _adminPassChangeCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "New Password",
                          hintText: "••••••••",
                        ),
                      ),
                      if (_adminCredsError != null) ...[
                        const SizedBox(height: 12),
                        Text(_adminCredsError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      if (_adminCredsSuccess != null) ...[
                        const SizedBox(height: 12),
                        Text(_adminCredsSuccess!, style: const TextStyle(color: Color(0xFF25D366), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _savingAdminCreds ? null : _saveAdminCreds,
                          child: _savingAdminCreds
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Save Account Settings"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SMTP test card
              const Text("Test SMTP Delivery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _testEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: "Test Destination Email",
                            hintText: "test@example.com",
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                        onPressed: _sendingTestOtp ? null : _sendTestOtp,
                        child: _sendingTestOtp
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Send OTP"),
                      )
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
