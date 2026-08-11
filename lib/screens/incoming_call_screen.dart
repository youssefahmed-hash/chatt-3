import 'package:flutter/material.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [

            const SizedBox(),

            Column(
              children: [

                const CircleAvatar(
                  radius: 60,
                  child: Icon(
                    Icons.person,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Incoming Call",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                FloatingActionButton(
                  heroTag: "reject",
                  backgroundColor: Colors.red,
                  onPressed: onReject,
                  child: const Icon(Icons.call_end),
                ),

                FloatingActionButton(
                  heroTag: "accept",
                  backgroundColor: Colors.green,
                  onPressed: onAccept,
                  child: const Icon(Icons.call),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}