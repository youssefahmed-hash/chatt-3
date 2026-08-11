import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../services/socket_service.dart';
import 'chat_list_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {

  final List<TextEditingController> controllers =
  List.generate(
    6,
        (_) => TextEditingController(),
  );

  final List<FocusNode> nodes =
  List.generate(
    6,
        (_) => FocusNode(),
  );

  String get otp =>
      controllers
          .map((e) => e.text)
          .join();

  @override
  void dispose() {

    for (final c in controllers) {
      c.dispose();
    }

    for (final n in nodes) {
      n.dispose();
    }

    super.dispose();
  }

  Widget buildBox(int index) {

    return SizedBox(

      width: 48,

      child: TextField(

        controller: controllers[index],

        focusNode: nodes[index],

        textAlign: TextAlign.center,

        keyboardType: TextInputType.number,

        maxLength: 1,

        decoration: const InputDecoration(
          counterText: "",
        ),

        onChanged: (value) {

          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context)
                .requestFocus(
              nodes[index + 1],
            );
          }

          if (value.isEmpty && index > 0) {
            FocusScope.of(context)
                .requestFocus(
              nodes[index - 1],
            );
          }

        },

      ),

    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("OTP Verification"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.center,

          children: [

            const SizedBox(height: 30),

            const Text(
              "Enter OTP",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              widget.email,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,

              children: List.generate(
                6,
                    (index) => buildBox(index),
              ),

            ),

            const SizedBox(height: 40),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(

                onPressed: () async {

                  if (otp.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Enter complete OTP",
                        ),
                      ),
                    );
                    return;
                  }

                  try {

                    final result =
                    await ApiService.verifyOtp(
                      email: widget.email,
                      otp: otp,
                    );

                    await Session.save(

                      token: result["token"],

                      userId: result["user"]["id"],

                      userName: result["user"]["name"],

                    );

                    SocketService.instance.connect();

                    if (!mounted) return;

                    Navigator.pushAndRemoveUntil(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                        const ChatListScreen(),

                      ),

                          (route) => false,

                    );

                  } catch (e) {

                    ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(

                        content: Text(e.toString()),

                      ),

                    );

                  }

                },

                child: const Text(
                  "Verify",
                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}