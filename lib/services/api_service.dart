import 'dart:convert';
import 'package:http/http.dart' as http_orig;
import '../models/group_member.dart';
import '../config/api_config.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_type.dart';
import 'session.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import 'package:http_parser/http_parser.dart';

/// Thin wrapper around the chatt REST API. Every call attaches the saved
/// Bearer token. Throws [ApiException] on non-2xx responses.
class ApiService {
  static Map<String, String> get _headers =>
      {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  static Uri _uri(String path) => Uri.parse('${ApiConfig.apiUrl}$path');

  static dynamic _decode(http_orig.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg);
  }

  // ===== Auth =====

  /// Returns the raw { token, user } map.
  static Future<Map<String, dynamic>> register(String name, String email,
      String password) async {
    final res = await http.post(
      _uri('/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final res = await http.post(
      _uri('/auth/verify'),
      headers: _headers,
      body: jsonEncode({
        "email": email,
        "otp": otp,
      }),
    );

    return _decode(res);
  }

  // ===== Create Group =====

  static Future<Chat> createGroup({
    required String name,
    required List<String> members,
    XFile? image,
  }) async {
    final request = http.MultipartRequest(

      'POST',

      _uri('/conversations/group'),

    );

    request.headers.addAll(_headers);

    request.fields['name'] = name;

    request.fields['members'] = jsonEncode(members);

    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();

        request.files.add(

          http.MultipartFile.fromBytes(

            'image',

            bytes,

            filename: image.name,

          ),

        );
      } else {
        request.files.add(

          await http.MultipartFile.fromPath(

            'image',

            image.path,

          ),

        );
      }
    }

    final response = await http.send(request);

    final body = await response.stream.bytesToString();

    if (response.statusCode >= 400) {
      throw Exception(body);
    }

    final json = jsonDecode(body);

    return Chat.fromJson(

      json['conversation'],

    );
  }

  static Future<List<GroupMember>> getUsers({
    String? search,
  }) async {
    final uri = search == null || search.isEmpty
        ? _uri('/users')
        : _uri('/users?search=$search');

    final res = await http.get(
      uri,
      headers: _headers,
    );

    final body = _decode(res);

    return (body['users'] as List)
        .map(
          (e) => GroupMember.fromJson(e),
    )
        .toList();
  }

  static Future<Map<String, dynamic>> login(String email,
      String password) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> changeCredentials(String email, String password) async {
    final res = await http.post(
      _uri('/auth/change-credentials'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  // ===== Users =====

  /// Other users you can start a chat with.
  static Future<List<Map<String, dynamic>>> listUsers({String? search}) async {
    final q = (search != null && search.isNotEmpty) ? '?search=$search' : '';
    final res = await http.get(_uri('/users$q'), headers: _headers);
    final body = _decode(res) as Map<String, dynamic>;
    return (body['users'] as List).cast<Map<String, dynamic>>();
  }

  // ===== Conversations =====

  static Future<List<Chat>> getConversations() async {
    final res = await http.get(_uri('/conversations'), headers: _headers);
    final body = _decode(res) as Map<String, dynamic>;
    return (body['conversations'] as List)
        .map((c) => Chat.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Open (or create) a 1-on-1 conversation with [userId].
  static Future<Chat> startConversation(String userId) async {
    final res = await http.post(
      _uri('/conversations'),
      headers: _headers,
      body: jsonEncode({'userId': userId}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    return Chat.fromJson(body['conversation'] as Map<String, dynamic>);
  }

  // ===== Messages =====

  static Future<List<Message>> getMessages(String conversationId) async {
    final res = await http.get(
      _uri('/conversations/$conversationId/messages'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return (body['messages'] as List)
        .map((m) => Message.fromJson(m as Map<String, dynamic>, myId))
        .toList();
  }

  /// REST fallback for sending (the socket is the primary path).
  static Future<Message> sendMessage(String conversationId, {
    required String text,
    MessageType type = MessageType.text,
    String? callUrl,
    String? replyToId,
    String? forwardedFrom,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/messages'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'type': type.asString,
        'callUrl': ?callUrl,
        'replyToId': ?replyToId,
        'forwardedFrom': ?forwardedFrom,
      }),
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return Message.fromJson(body['message'] as Map<String, dynamic>, myId);
  }

  static Future<Message> sendImage(String conversationId,
      XFile image, {
        String? replyToId,
      }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/conversations/$conversationId/messages/image'),
    );

    if (Session.token != null) {
      request.headers['Authorization'] =
      'Bearer ${Session.token}';
    }

    if (replyToId != null) {
      request.fields['replyToId'] = replyToId;
    }

    if (kIsWeb) {
      Uint8List bytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
        ),
      );
    }

    final streamedResponse = await http.send(request);
    final response = await http_orig.Response.fromStream(streamedResponse);

    final body = _decode(response) as Map<String, dynamic>;
    final myId = Session.userId ?? '';

    return Message.fromJson(
      body['message'] as Map<String, dynamic>,
      myId,
    );
  }

  static Future<List<GroupMember>> addMembers({
    required String conversationId,
    required List<String> members,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/members'),
      headers: _headers,
      body: jsonEncode({
        'members': members,
      }),
    );

    final body = _decode(res) as Map<String, dynamic>;

    return (body['members'] as List)
        .map(
          (e) =>
          GroupMember.fromJson(
            e as Map<String, dynamic>,
          ),
    )
        .toList();
  }

  static Future<void> deleteMessage(String messageId) async {
    final res = await http.delete(
      _uri('/auth/messages/$messageId'),
      headers: _headers,
    );

    _decode(res);
  }

  static Future<List<GroupMember>> removeMember({
    required String conversationId,
    required String memberId,
  }) async {
    final res = await http.delete(
      _uri('/conversations/$conversationId/members/$memberId'),
      headers: _headers,
    );

    final body = _decode(res) as Map<String, dynamic>;

    return (body['members'] as List)
        .map((e) => GroupMember.fromJson(e))
        .toList();
  }

  static Future<List<String>> makeAdmin({
    required String conversationId,
    required String memberId,
  }) async {
    final res = await http.patch(
      _uri('/conversations/$conversationId/admins/$memberId'),
      headers: _headers,
    );

    final body = _decode(res);

    return (body['admins'] as List)
        .map((e) => e.toString())
        .toList();
  }

  static Future<List<String>> removeAdmin({
    required String conversationId,
    required String memberId,
  }) async {
    final res = await http.delete(
      _uri('/conversations/$conversationId/admins/$memberId'),
      headers: _headers,
    );

    final body = _decode(res);

    return (body['admins'] as List)
        .map((e) => e.toString())
        .toList();
  }


  static Future<void> leaveGroup({
    required String conversationId,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/leave'),
      headers: _headers,
    );

    _decode(res);
  }

  static Future<void> updateGroupName({
    required String conversationId,
    required String name,
  }) async {
    final response = await http.patch(
      _uri('/conversations/$conversationId/name'),
      headers: _headers,
      body: jsonEncode({
        "name": name,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update group name");
    }
  }

  static Future<String> updateGroupImage({
    required String conversationId,
    required XFile image,
  }) async {
    final request = http.MultipartRequest(
      "PATCH",
      _uri("/conversations/$conversationId/image"),
    );

    if (Session.token != null) {
      request.headers["Authorization"] =
      "Bearer ${Session.token}";
    }

    if (kIsWeb) {
      final bytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: image.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          "image",
          image.path,
        ),
      );
    }

    final response = await http.send(request);

    final body = await response.stream.bytesToString();

    if (response.statusCode >= 400) {
      throw Exception(body);
    }

    final json = jsonDecode(body);

    return json["groupImage"];
  }


// ===== Profile =====

  static Future<UserProfile> getProfile() async {
    final res = await http.get(
      _uri('/users/profile'),
      headers: _headers,
    );

    final body = _decode(res) as Map<String, dynamic>;

    return UserProfile.fromJson(
      body['user'] as Map<String, dynamic>,
    );
  }


  static Future<UserProfile> updateProfile({
    required String name,
    required String bio,
  }) async {
    final res = await http.put(
      _uri('/users/profile'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'bio': bio,
      }),
    );

    final body = _decode(res) as Map<String, dynamic>;

    return UserProfile.fromJson(
      body['user'] as Map<String, dynamic>,
    );
  }

  static Future<Map<String, dynamic>> updateAvatar(XFile image,) async {
    final request = http.MultipartRequest(
      'PUT',
      _uri('/users/avatar'),
    );


    request.headers['Authorization'] =
    'Bearer ${Session.token}';


    if (kIsWeb) {
      final bytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: image.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          image.path,
        ),
      );
    }


    final response = await http.send(request);

    final body =
    await response.stream.bytesToString();


    if (response.statusCode >= 400) {
      throw Exception(body);
    }


    return jsonDecode(body);
  }

  static Future<UserProfile> getUserProfile(String userId) async {
    final res = await http.get(
      _uri('/users/$userId'),
      headers: _headers,
    );

    final body = _decode(res) as Map<String, dynamic>;

    return UserProfile.fromJson(body['user']);
  }

  static Future<Message> sendVoice(
      String conversationId,
      XFile audio,
      int duration,
      {
        String? replyToId,
      }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/conversations/$conversationId/messages/voice'),
    );

    request.fields["duration"] = duration.toString();

    if (replyToId != null) {
      request.fields["replyToId"] = replyToId;
    }

    if (Session.token != null) {
      request.headers['Authorization'] =
      'Bearer ${Session.token}';
    }
    if (kIsWeb) {
      final bytes = await audio.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'voice',
          bytes,
          filename: "voice.m4a",
          contentType: MediaType("audio", "mp4"),
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'voice',
          audio.path,
        ),
      );
    }


    final streamed = await http.send(request);
    final response = await http_orig.Response.fromStream(streamed);

    final body = _decode(response) as Map<String, dynamic>;
    print(body);
    final myId = Session.userId ?? '';

    return Message.fromJson(
      body['message'] as Map<String, dynamic>,
      myId,
    );
  }

// last {

  // ============================================================
  // FILES
  // ============================================================

  static Future<Message> sendFile(
    String conversationId,
    XFile file, {
    String? replyToId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/conversations/$conversationId/messages/file'),
    );

    if (Session.token != null) {
      request.headers['Authorization'] =
      'Bearer ${Session.token}';
    }

    if (replyToId != null) {
      request.fields['replyToId'] = replyToId;
    }

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.name,
        ),
      );
    }

    final streamed = await http.send(request);
    final response = await http_orig.Response.fromStream(streamed);

    final body = _decode(response) as Map<String, dynamic>;
    final myId = Session.userId ?? '';

    return Message.fromJson(
      body['message'] as Map<String, dynamic>,
      myId,
    );
  }

  // ============================================================
  // VIDEOS
  // ============================================================

  static Future<Message> sendVideo(
    String conversationId,
    XFile video, {
    String? replyToId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/conversations/$conversationId/messages/video'),
    );

    if (Session.token != null) {
      request.headers['Authorization'] =
      'Bearer ${Session.token}';
    }

    if (replyToId != null) {
      request.fields['replyToId'] = replyToId;
    }

    if (kIsWeb) {
      final bytes = await video.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'video',
          bytes,
          filename: video.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          video.path,
          filename: video.name,
        ),
      );
    }

    final streamed = await http.send(request);
    final response = await http_orig.Response.fromStream(streamed);

    final body = _decode(response) as Map<String, dynamic>;
    final myId = Session.userId ?? '';

    return Message.fromJson(
      body['message'] as Map<String, dynamic>,
      myId,
    );
  }

  // ============================================================
  // EDIT MESSAGE
  // ============================================================

  static Future<Message> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async {
    final res = await http.patch(
      _uri('/conversations/$conversationId/messages/$messageId'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return Message.fromJson(body['message'] as Map<String, dynamic>, myId);
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  static Future<Map<String, dynamic>> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/messages/$messageId/reactions'),
      headers: _headers,
      body: jsonEncode({'emoji': emoji}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    return body;
  }

  static Future<Map<String, dynamic>> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final res = await http.delete(
      _uri(
        '/conversations/$conversationId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}',
      ),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    return body;
  }

  // ============================================================
  // FORWARD
  // ============================================================

  static Future<Message> forwardMessage({
    required String targetConversationId,
    required String messageId,
  }) async {
    final res = await http.post(
      _uri('/conversations/$targetConversationId/messages/forward'),
      headers: _headers,
      body: jsonEncode({'messageId': messageId}),
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return Message.fromJson(body['message'] as Map<String, dynamic>, myId);
  }

  // ============================================================
  // SEARCH MESSAGES
  // ============================================================

  static Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    final res = await http.get(
      _uri('/conversations/$conversationId/messages/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return (body['messages'] as List)
        .map((m) => Message.fromJson(m as Map<String, dynamic>, myId))
        .toList();
  }

  // ============================================================
  // MESSAGE CONTEXT (for scroll-to-message)
  // ============================================================

  static Future<List<Message>> getMessageContext({
    required String conversationId,
    required String messageId,
  }) async {
    final res = await http.get(
      _uri('/conversations/$conversationId/messages/context?around=$messageId'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return (body['messages'] as List)
        .map((m) => Message.fromJson(m as Map<String, dynamic>, myId))
        .toList();
  }

  // ============================================================
  // STAR
  // ============================================================

  static Future<void> starMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/messages/$messageId/star'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<void> unstarMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final res = await http.delete(
      _uri('/conversations/$conversationId/messages/$messageId/star'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<List<Map<String, dynamic>>> getStarredMessages() async {
    final res = await http.get(
      _uri('/conversations/starred'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    return (body['messages'] as List).cast<Map<String, dynamic>>();
  }

  // ============================================================
  // PIN
  // ============================================================

  static Future<void> pinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/pins/$messageId'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<void> unpinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final res = await http.delete(
      _uri('/conversations/$conversationId/pins/$messageId'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<List<Message>> getPinnedMessages(String conversationId) async {
    final res = await http.get(
      _uri('/conversations/$conversationId/pins'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    final myId = Session.userId ?? '';
    return (body['messages'] as List)
        .map((m) => Message.fromJson(m as Map<String, dynamic>, myId))
        .toList();
  }

  // ============================================================
  // ARCHIVE
  // ============================================================

  static Future<void> archiveConversation(String conversationId) async {
    final res = await http.post(
      _uri('/conversations/$conversationId/archive'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<void> unarchiveConversation(String conversationId) async {
    final res = await http.delete(
      _uri('/conversations/$conversationId/archive'),
      headers: _headers,
    );
    _decode(res);
  }

  static Future<List<Chat>> getArchivedConversations() async {
    final res = await http.get(
      _uri('/conversations?archived=1'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    return (body['conversations'] as List)
        .map((c) => Chat.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // CALL HISTORY
  // ============================================================

  static Future<List<Map<String, dynamic>>> getCalls() async {
    final res = await http.get(
      _uri('/calls'),
      headers: _headers,
    );
    final body = _decode(res) as Map<String, dynamic>;
    return (body['calls'] as List).cast<Map<String, dynamic>>();
  }

  // ===== Dynamic Settings =====
  static Future<Map<String, dynamic>> getSettings() async {
    final res = await http.get(
      _uri('/settings'),
      headers: _headers,
    );
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSettings({
    required String email,
    String? password,
    required String adminEmail,
  }) async {
    final res = await http.put(
      _uri('/settings'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
        'adminEmail': adminEmail,
      }),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> testOtp(String email) async {
    final res = await http.post(
      _uri('/settings/test-otp'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    return _decode(res) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class FriendlyHttpClient extends http_orig.BaseClient {
  final http_orig.Client _inner = http_orig.Client();

  @override
  Future<http_orig.StreamedResponse> send(http_orig.BaseRequest request) async {
    try {
      return await _inner.send(request).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException(
        503,
        "Unable to connect to the server. Please check the server URL and make sure the backend is running.",
      );
    }
  }
}

class http {
  static final _inner = FriendlyHttpClient();

  static Future<http_orig.Response> get(Uri url, {Map<String, String>? headers}) => _inner.get(url, headers: headers);
  static Future<http_orig.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => _inner.post(url, headers: headers, body: body, encoding: encoding);
  static Future<http_orig.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => _inner.put(url, headers: headers, body: body, encoding: encoding);
  static Future<http_orig.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => _inner.patch(url, headers: headers, body: body, encoding: encoding);
  static Future<http_orig.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => _inner.delete(url, headers: headers, body: body, encoding: encoding);

  // Helper to construct a MultipartRequest
  static http_orig.MultipartRequest MultipartRequest(String method, Uri url) {
    return http_orig.MultipartRequest(method, url);
  }

  // Delegate for MultipartFile
  static get MultipartFile => http_orig.MultipartFile;

  // Custom proxy send method
  static Future<http_orig.StreamedResponse> send(http_orig.BaseRequest request) {
    return _inner.send(request);
  }
}
