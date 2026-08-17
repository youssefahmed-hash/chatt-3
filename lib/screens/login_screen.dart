import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/session.dart';
import '../config/api_config.dart';
import 'chat_list_screen.dart';
import 'register_screen.dart';
import 'admin_dashboard_screen.dart';
import 'force_change_credentials_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();

  bool _loading = false;

  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final rawDomain = _domainCtrl.text.trim();
    if (rawDomain.isNotEmpty) {
      await ApiConfig.setBaseUrl(rawDomain);
    }

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;

    final domain = ApiConfig.baseUrl.replaceAll("https://", "").replaceAll("http://", "");
    final isInstalled = domain.contains('.') && !domain.contains("10.0.2.2") && !domain.contains("localhost");

    // Local Bootstrap Login Bypass if server is not installed yet
    if (!isInstalled && email == "admin@chatt.local" && password == "admin123") {
      await Session.save(
        token: "bootstrap_token",
        userId: "bootstrap_admin_id",
        userName: "Bootstrap Admin",
        role: "admin",
        mustChangeCredentials: false,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    try {
      await AuthService.login(email, password);

      SocketService.instance.connect();

      if (!mounted) return;

      if (Session.isAdmin) {
        if (Session.mustChangeCredentials) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ForceChangeCredentialsScreen(),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminDashboardScreen(),
            ),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatListScreen(),
          ),
        );
      }
    } catch (e) {

      setState(() {

        _error = e.toString();

      });

    }

    if (mounted) {

      setState(() {

        _loading = false;

      });

    }

  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(24),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                const Icon(

                  Icons.chat,

                  size: 72,

                  color: Color(0xFF075E54),

                ),

                const SizedBox(height: 12),

                const Text(

                  "chatt",

                  style: TextStyle(

                    fontSize: 28,

                    fontWeight: FontWeight.bold,

                    color: Color(0xFF075E54),

                  ),

                ),

                const SizedBox(height: 32),

                TextField(

                  controller: _domainCtrl,

                  keyboardType: TextInputType.url,

                  decoration: const InputDecoration(

                    hintText: "Server domain (api.example.com)",

                  ),

                ),

                const SizedBox(height: 12),

                TextField(

                  controller: _emailCtrl,

                  keyboardType:
                  TextInputType.emailAddress,

                  decoration:
                  const InputDecoration(

                    hintText: "Email",

                  ),

                ),

                const SizedBox(height: 12),

                TextField(

                  controller: _passCtrl,

                  obscureText: true,

                  decoration:
                  const InputDecoration(

                    hintText: "Password",

                  ),

                ),

                if (_error != null) ...[

                  const SizedBox(height: 12),

                  Text(

                    _error!,

                    style: const TextStyle(

                      color: Colors.red,

                      fontSize: 13,

                    ),

                  ),

                ],

                const SizedBox(height: 20),

                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton(

                    style:
                    ElevatedButton.styleFrom(

                      backgroundColor:
                      Theme.of(context).colorScheme.primary,

                      foregroundColor:
                      Theme.of(context).colorScheme.onPrimary,

                      padding:
                      const EdgeInsets
                          .symmetric(

                        vertical: 14,

                      ),

                    ),

                    onPressed: _loading
                        ? null
                        : _submit,

                    child: _loading

                        ? const SizedBox(

                      height: 20,

                      width: 20,

                      child:
                      CircularProgressIndicator(

                        strokeWidth: 2,

                        color: Colors.white,

                      ),

                    )

                        : const Text(
                      "Login",
                    ),

                  ),

                ),

                const SizedBox(height: 10),

                TextButton(

                  onPressed: () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                        const RegisterScreen(),

                      ),

                    );

                  },

                  child: const Text(

                    "Create Account",

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}