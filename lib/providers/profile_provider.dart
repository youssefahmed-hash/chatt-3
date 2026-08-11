import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _profile;

  UserProfile? get profile => _profile;

  bool _loading = false;
  bool get loading => _loading;


  Future<void> loadProfile() async {
    _loading = true;
    notifyListeners();

    try {
      _profile = await ApiService.getProfile();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }




  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {

    _loading = true;
    notifyListeners();

    try {
      _profile = await ApiService.updateProfile(
        name: name,
        bio: bio,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateAvatar(XFile image) async {

    _loading = true;
    notifyListeners();

    try {

      final result =
      await ApiService.updateAvatar(image);

      _profile = UserProfile.fromJson(result['user']);

    } finally {

      _loading = false;
      notifyListeners();

    }

  }}