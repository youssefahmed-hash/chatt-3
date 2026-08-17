import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();

  bool loading = false;

  String? error;

  Future<void> register() async {

    setState(() {
      loading = true;
      error = null;
    });

    try {

      final rawDomain = _domainCtrl.text.trim();
      if (rawDomain.isNotEmpty) {
        await ApiConfig.setBaseUrl(rawDomain);
      }

      await AuthService.register(

        _nameCtrl.text.trim(),

        _emailCtrl.text.trim(),

        _passCtrl.text,

      );

      if (!mounted) return;

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(

          builder: (_) => OtpScreen(

            email: _emailCtrl.text.trim(),

          ),

        ),

      );

    } catch (e) {

      setState(() {

        error = e.toString();

      });

    }

    if (mounted) {

      setState(() {

        loading = false;

      });

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Create Account"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            TextField(

              controller: _domainCtrl,

              keyboardType: TextInputType.url,

              decoration: const InputDecoration(

                hintText: "Server domain (api.example.com)",

              ),

            ),

            const SizedBox(height: 15),

            TextField(

              controller: _nameCtrl,

              decoration: const InputDecoration(

                labelText: "Name",

              ),

            ),

            const SizedBox(height: 15),

            TextField(

              controller: _emailCtrl,

              decoration: const InputDecoration(

                labelText: "Email",

              ),

            ),

            const SizedBox(height: 15),

            TextField(

              controller: _passCtrl,

              obscureText: true,

              decoration: const InputDecoration(

                labelText: "Password",

              ),

            ),

            if (error != null) ...[

              const SizedBox(height: 15),

              Text(

                error!,

                style: const TextStyle(

                  color: Colors.red,

                ),

              ),

            ],

            const SizedBox(height: 30),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(
                style:
                ElevatedButton.styleFrom(

                  backgroundColor:
                  const Color(
                    0xFF075E54,
                  ),

                  foregroundColor:
                  Colors.white,

                  padding:
                  const EdgeInsets
                      .symmetric(

                    vertical: 14,

                  ),

                ),
                onPressed: loading
                    ? null
                    : register,

                child: loading

                    ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )

                    : const Text(
                  "Create Account",
                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}