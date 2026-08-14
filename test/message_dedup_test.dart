import 'package:chatt/models/message.dart';
import 'package:chatt/models/message_type.dart';
import 'package:chatt/screens/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end verification of the ChatScreen send->echo dedup, using the REAL
/// `upsertIntoList` function from production code so these tests cannot drift
/// from the actual implementation.
void main() {
  List<String> peerIds = ['user-peer'];

  Map<String, dynamic> echoJson(String suffix) => <String, dynamic>{
        'id': '8c5f4f4a-0000-4000-8000-00000000000$suffix',
        'text': 'hello',
        'type': 'text',
        'clientId': 'local_171700000000$suffix',
        'sender': <String, dynamic>{
          'id': 'user-me',
          'name': 'Me',
        },
        'createdAt': '2026-08-14T10:00:00.000Z',
        'readBy': ['user-me'],
        'reactions': <String, dynamic>{},
      };

  Message pending(String suffix) => Message(
        id: 'local_171700000000$suffix',
        clientId: 'local_171700000000$suffix',
        text: 'hello',
        isMe: true,
        type: MessageType.text,
        status: MessageStatus.pending,
      );

  test('echo round-trip preserves clientId and marks isMe', () {
    final echo = Message.fromJson(echoJson('1'), 'user-me');
    expect(echo.isMe, isTrue);
    expect(echo.clientId, 'local_1717000000001');
    expect(echo.status, MessageStatus.delivered);
  });

  test('online send + echo yields exactly ONE message', () {
    final messages = <Message>[pending('1')];
    upsertIntoList(messages, Message.fromJson(echoJson('1'), 'user-me'),
        peerIds);
    expect(messages.length, 1);
    expect(messages.single.id, '8c5f4f4a-0000-4000-8000-000000000001');
  });

  test('echo arriving multiple times never duplicates', () {
    final messages = <Message>[pending('2')];
    for (var i = 0; i < 3; i++) {
      upsertIntoList(messages, Message.fromJson(echoJson('2'), 'user-me'),
          peerIds);
    }
    expect(messages.length, 1);
  });

  test('stale pending placeholder (status flipped) is not kept as a ghost', () {
    final messages = <Message>[pending('3')];
    // Pretend the placeholder already switched to delivered (e.g. a read
    // receipt arrived before the echo): it must still collapse to one item.
    messages[0] =
        pending('3').copyWith(status: MessageStatus.delivered, id: 'other-id');
    upsertIntoList(messages, Message.fromJson(echoJson('3'), 'user-me'),
        peerIds);
    expect(messages.length, 1);
    expect(messages.single.id, isNot('other-id'));
  });

  test('echo without clientId adopts the FIFO pending placeholder', () {
    final messages = <Message>[pending('4')];
    final noClientId = echoJson('4')..remove('clientId');
    upsertIntoList(messages, Message.fromJson(noClientId, 'user-me'), peerIds);
    expect(messages.length, 1);
    expect(messages.single.id, '8c5f4f4a-0000-4000-8000-000000000004');
  });

  test('offline queued message + flush echo still yields ONE', () {
    final messages = <Message>[pending('5')];
    final echoOffline = echoJson('5');
    upsertIntoList(messages, Message.fromJson(echoOffline, 'user-me'),
        peerIds);
    expect(messages.length, 1);
  });

  test('remote (not mine) message appends once, read ticks preserved', () {
    final messages = <Message>[];
    final json =
        echoJson('6')..remove('clientId');
    json['sender'] = <String, dynamic>{
      'id': 'user-peer',
      'name': 'Peer',
    };
    json['readBy'] = ['user-peer'];
    final remote = Message.fromJson(json, 'user-me');
    expect(remote.isMe, isFalse);
    upsertIntoList(messages, remote, peerIds);
    expect(messages.length, 1);
    expect(messages.single.isMe, isFalse);
    expect(messages.single.status, MessageStatus.delivered);
  });

  test('two identical texts are still two distinct messages', () {
    final a = Message.fromJson(echoJson('7'), 'user-me');
    final b = Message.fromJson(echoJson('8'), 'user-me');
    final messages = <Message>[a];
    upsertIntoList(messages, b, peerIds);
    expect(messages.length, 2, reason: 'never dedup by message text');
  });
}