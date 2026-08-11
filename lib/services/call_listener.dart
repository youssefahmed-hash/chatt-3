import 'package:flutter/material.dart';

import '../screens/incoming_call_screen.dart';
import 'jitsi_service.dart';
import 'socket_service.dart';

class CallListener {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void init() {
    SocketService.instance.onIncomingCall.listen((event) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            callerName: event.caller['name'] ?? 'Unknown',
            onAccept: () async {

              Navigator.pop(context);

              SocketService.instance.acceptCall(
                callerId: event.caller['id'].toString(),
                roomName: event.roomName,
              );

              await JitsiService.joinRoom(event.roomName);

            },

            onReject: () {

              Navigator.pop(context);

              SocketService.instance.rejectCall(
                callerId: event.caller['id'].toString(),
              );

            },
          ),
        ),
      );
    });
  }
}