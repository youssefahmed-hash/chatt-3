import 'api_service.dart';
import 'session.dart';

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

    );

  }

}