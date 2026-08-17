import 'api_service.dart';
import 'offline_queue.dart';
import 'session.dart';
import 'socket_service.dart';

class AuthService {

  static Future<void> register(
      String name,
      String email,
      String password,
      ) async {

    // هيبعت OTP فقط
    await ApiService.register(
      name,
      email,
      password,
    );

  }

  static Future<void> login(
      String email,
      String password,
      ) async {

    final data =
    await ApiService.login(
      email,
      password,
    );

    await _persist(data);

  }

  static Future<void> logout() async {

    // Tear down the socket for the current identity so a later login on this
    // device never sends messages under the previous account. Every logout
    // path (dashboard, chat list) goes through here.
    SocketService.instance.disconnect();

    // Drop pending messages owned by the signed-out identity so they can never
    // be delivered (with the wrong sender) after the next login.
    await OfflineQueue.instance.clear();

    await Session.clear();

  }

  static Future<void> _persist(
      Map<String, dynamic> data,
      ) async {

    final user =
    data["user"] as Map<String, dynamic>;

    await Session.save(

      token: data["token"],

      userId: user["id"].toString(),

      userName: user["name"],

      role: user["role"] ?? 'user',

      mustChangeCredentials: user["mustChangeCredentials"] == true,

    );

  }

  static Future<void> changeCredentials(String email, String password) async {
    final data = await ApiService.changeCredentials(email, password);
    // Reload token and user info if needed
    final user = data["user"] as Map<String, dynamic>;
    await Session.save(
      token: Session.token ?? '',
      userId: user["id"].toString(),
      userName: user["name"],
      role: user["role"] ?? 'user',
      mustChangeCredentials: false,
    );
  }

}