import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatt/config/api_config.dart';
import 'package:chatt/models/message.dart';
import 'package:chatt/models/message_type.dart';
import 'package:chatt/services/api_service.dart';
import 'package:chatt/services/session.dart';

class CapturedFile {
  final String field;
  final String filename;
  final Uint8List bytes;
  CapturedFile(this.field, this.filename, this.bytes);
}

class CapturedRequest {
  final List<CapturedFile> files = [];
  final Map<String, String> fields = {};
  String? authorization;
}

bool _matchesAt(List<int> data, List<int> seq, int at) {
  for (var i = 0; i < seq.length; i++) {
    if (at + i >= data.length || data[at + i] != seq[i]) return false;
  }
  return true;
}

List<List<int>> _splitBy(List<int> data, List<int> delim) {
  final out = <List<int>>[];
  var start = 0;
  var i = 0;
  while (i + delim.length <= data.length) {
    if (_matchesAt(data, delim, i)) {
      out.add(data.sublist(start, i));
      start = i + delim.length;
      i = start;
    } else {
      i++;
    }
  }
  out.add(data.sublist(start));
  return out;
}

/// Parses a multipart/form-data body exactly the way multer does on the
/// Express side: each file part = one `upload.single(<field>)` candidate,
/// text fields (duration, replyToId) come in request.fields.
CapturedRequest parseMultipart(List<int> body, String boundary) {
  final request = CapturedRequest();
  final delim = utf8.encode('--$boundary');
  final parts = _splitBy(body, delim);
  for (final part in parts) {
    if (part.isEmpty) continue;
    // Closing `--` marker of the final boundary.
    if (part.length >= 2 && part[0] == 0x2d && part[1] == 0x2d) continue;
    final sep = _indexOf(part, const [13, 10, 13, 10]);
    if (sep == -1) continue;
    final header = utf8.decode(part.sublist(0, sep));
    var content = part.sublist(sep + 4);
    if (content.length >= 2 &&
        content[content.length - 2] == 13 &&
        content[content.length - 1] == 10) {
      content = content.sublist(0, content.length - 2);
    }
    final nameMatch = RegExp('name="([^"]*)"').firstMatch(header);
    if (nameMatch == null) continue;
    final fileMatch = RegExp('filename="([^"]*)"').firstMatch(header);
    if (fileMatch != null) {
      request.files.add(CapturedFile(
        nameMatch.group(1)!,
        fileMatch.group(1)!,
        Uint8List.fromList(content),
      ));
    } else {
      request.fields[nameMatch.group(1)!] = utf8.decode(content);
    }
  }
  return request;
}

int _indexOf(List<int> data, List<int> seq) {
  for (var i = 0; i + seq.length <= data.length; i++) {
    if (_matchesAt(data, seq, i)) return i;
  }
  return -1;
}

Map<String, dynamic> _jsonMessage(
  String type,
  Map<String, dynamic> extra,
) => {
      'id': 'msg-$type',
      'type': type,
      'text': '',
      'sender': {'id': 'user-1', 'name': 'Tester', 'avatarUrl': null},
      'createdAt': '2026-01-01T00:00:00.000Z',
      'readBy': ['user-1'],
      'reactions': {},
      'myReactions': [],
      ...extra,
    };

void main() {
  late HttpServer server;
  late Directory tempDir;
  final received = <String, CapturedRequest>{};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.save(
      token: 'test-token',
      userId: 'user-1',
      userName: 'Tester',
      role: 'user',
      mustChangeCredentials: false,
    );

    tempDir = await Directory.systemTemp.createTemp('chatt_upload_test');

    final fileDefs = <String, String>{
      'photo.jpg': 'image',
      'clip.mp4': 'video',
      'note.m4a': 'voice',
      'doc.pdf': 'file',
    };
    for (final entry in fileDefs.entries) {
      await File('${tempDir.path}/${entry.key}')
          .writeAsBytes(List.filled(2048 + entry.value.length, 0x41));
    }

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) async {
      final body = await req.fold<Uint8List>(
        Uint8List(0),
        (acc, chunk) => Uint8List.fromList([...acc, ...chunk]),
      );
      final contentType = req.headers.contentType;
      final captures = parseMultipart(
        body,
        contentType!.parameters['boundary']!,
      );
      captures.authorization = req.headers.value('authorization');
      received[req.uri.path] = captures;

      final fileName = captures.files.isNotEmpty
          ? captures.files.first.filename
          : 'none.bin';
      final Map<String, dynamic> message;
      if (req.uri.path.endsWith('/messages/image')) {
        message = _jsonMessage('image', {
          'imageUrl': '/uploads/messages/$fileName',
        });
      } else if (req.uri.path.endsWith('/messages/video')) {
        message = _jsonMessage('video', {
          'videoUrl': '/uploads/videos/$fileName',
          'videoThumbUrl': null,
        });
      } else if (req.uri.path.endsWith('/messages/voice')) {
        message = _jsonMessage('voice', {
          'voiceUrl': '/uploads/voices/$fileName',
          'voiceDuration': int.tryParse(captures.fields['duration'] ?? '0') ?? 0,
        });
      } else {
        message = _jsonMessage('file', {
          'fileUrl': '/uploads/files/$fileName',
          'fileName': fileName,
          'fileSize': captures.files.first.bytes.length,
          'fileType': 'application/octet-stream',
        });
      }

      req.response.headers.contentType = ContentType.json;
      req.response.statusCode = HttpStatus.created;
      req.response.write(jsonEncode({'message': message}));
      await req.response.close();
    });

    await ApiConfig.setBaseUrl('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
    ApiConfig.setBaseUrl(null);
  });

  Future<void> expectUpload(
    String suffix,
    String expectedField,
    String expectedFilename,
    Message message,
  ) async {
    final captures = received['/api/conversations/conv-1/messages/$suffix'];
    expect(captures, isNotNull, reason: 'server should have received the request');
    expect(captures!.authorization, 'Bearer test-token');
    expect(captures.files.length, 1);
    expect(captures.files.first.field, expectedField);
    expect(captures.files.first.filename, expectedFilename);
    expect(captures.files.first.bytes.length, greaterThan(0));
    expect(message.type, isNotNull);
  }

  test('sendImage uploads with field "image"', () async {
    final msg = await ApiService.sendImage(
      'conv-1',
      XFile('${tempDir.path}/photo.jpg'),
      replyToId: '00000000-0000-0000-0000-000000000001',
    );
    await expectUpload('image', 'image', 'photo.jpg', msg);
    expect(received['/api/conversations/conv-1/messages/image']!.fields['replyToId'],
        '00000000-0000-0000-0000-000000000001');
    expect(msg.type, MessageType.image);
    expect(msg.imageUrl, isNotNull);
  });

  test('sendVideo uploads with field "video"', () async {
    final msg = await ApiService.sendVideo(
      'conv-1',
      XFile('${tempDir.path}/clip.mp4'),
    );
    await expectUpload('video', 'video', 'clip.mp4', msg);
    expect(msg.type, MessageType.video);
    expect(msg.videoUrl, isNotNull);
  });

  test('sendVoice uploads with field "voice" + duration', () async {
    final msg = await ApiService.sendVoice(
      'conv-1',
      XFile('${tempDir.path}/note.m4a'),
      12,
    );
    await expectUpload('voice', 'voice', 'note.m4a', msg);
    expect(received['/api/conversations/conv-1/messages/voice']!.fields['duration'], '12');
    expect(msg.type, MessageType.voice);
    expect(msg.voiceUrl, isNotNull);
    expect(msg.voiceDuration, 12);
  });

  test('sendFile uploads with field "file"', () async {
    final msg = await ApiService.sendFile(
      'conv-1',
      XFile('${tempDir.path}/doc.pdf'),
      replyToId: '00000000-0000-0000-0000-000000000002',
    );
    await expectUpload('file', 'file', 'doc.pdf', msg);
    expect(msg.type, MessageType.file);
    expect(msg.fileUrl, isNotNull);
    expect(msg.fileName, 'doc.pdf');
    expect(msg.fileSize, greaterThan(0));
  });
}