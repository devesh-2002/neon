import 'dart:convert';

import 'package:built_collection/built_collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:neon_framework/blocs.dart';
import 'package:neon_framework/models.dart';
import 'package:neon_framework/testing.dart';
import 'package:neon_talk/src/blocs/room.dart';
import 'package:neon_talk/src/blocs/talk.dart';

import 'testing.dart';

Account mockTalkAccount() {
  var messageCount = 3;

  return mockServer({
    RegExp(r'/ocs/v2\.php/apps/spreed/api/v4/room/abcd/participants/active'): {
      'post': (match, queryParameters) => Response(
            json.encode({
              'ocs': {
                'meta': {'status': '', 'statuscode': 0},
                'data': getRoom(
                  token: 'abcd',
                ),
              },
            }),
            200,
          ),
      'delete': (match, queryParameters) => Response(
            json.encode({
              'ocs': {
                'meta': {'status': '', 'statuscode': 0},
                'data': <dynamic>[],
              },
            }),
            200,
          ),
    },
    RegExp(r'/ocs/v2\.php/apps/spreed/api/v1/chat/abcd'): {
      'get': (match, queryParameters) async {
        final lookIntoFuture = queryParameters['lookIntoFuture']!.single == '1';
        if (lookIntoFuture) {
          // Simulate a new message received after some time
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return Response(
            json.encode({
              'ocs': {
                'meta': {'status': '', 'statuscode': 0},
                'data': List.generate(2, (i) => getChatMessage(id: messageCount++)),
              },
            }),
            200,
            headers: {
              'x-chat-last-common-read': '0',
            },
          );
        } else {
          return Response(
            json.encode({
              'ocs': {
                'meta': {'status': '', 'statuscode': 0},
                'data': List.generate(messageCount, (i) => getChatMessage(id: messageCount - i - 1)),
              },
            }),
            200,
            headers: {
              'x-chat-last-common-read': '0',
            },
          );
        }
      },
      'post': (match, queryParameters) => Response(
            json.encode({
              'ocs': {
                'meta': {'status': '', 'statuscode': 0},
                'data': getChatMessage(id: messageCount++),
              },
            }),
            201,
            headers: {
              'x-chat-last-common-read': '1',
            },
          ),
    },
  });
}

void main() {
  late Account account;
  late TalkBloc talkBloc;
  late TalkRoomBloc roomBloc;

  setUpAll(() {
    registerFallbackValue(MockRoom());
  });

  setUp(() {
    FakeNeonStorage.setup();
  });

  setUp(() {
    final room = MockRoom();
    when(() => room.token).thenReturn('abcd');
    when(() => room.lastMessage).thenReturn((baseMessage: null, builtListNever: null, chatMessage: null));

    account = mockTalkAccount();
    talkBloc = MockTalkBloc();
    roomBloc = TalkRoomBloc(
      talkBloc: talkBloc,
      account: account,
      room: room,
    );
  });

  tearDown(() async {
    // Wait for all events to be processed
    await Future<void>.delayed(const Duration(milliseconds: 1));
    roomBloc.dispose();
  });

  test('refresh', () async {
    expect(
      roomBloc.room.transformResult((e) => e.token),
      emitsInOrder([
        Result.success('abcd').asLoading(),
        Result.success('abcd'),
        Result.success('abcd'),
        Result.success('abcd').asLoading(),
        Result.success('abcd'),
        Result.success('abcd'),
      ]),
    );

    expect(
      roomBloc.messages.transformResult((e) => BuiltList<int>(e.map((m) => m.id))),
      emitsInOrder([
        Result<BuiltList<int>>.loading(),
        Result.success(BuiltList<int>([2, 1, 0])),
        Result.success(BuiltList<int>([2, 1, 0])).asLoading(),
        Result.success(BuiltList<int>([2, 1, 0])),
      ]),
    );

    expect(
      roomBloc.lastCommonRead,
      emitsInOrder([0, 0]),
    );

    // The delay is necessary to avoid a race condition with loading twice at the same time
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await roomBloc.refresh();

    verify(() => talkBloc.updateRoom(any())).called(4);
  });

  test('sendMessage', () async {
    expect(
      roomBloc.messages.transformResult((e) => BuiltList<int>(e.map((m) => m.id))),
      emitsInOrder([
        Result<BuiltList<int>>.loading(),
        Result.success(BuiltList<int>([2, 1, 0])),
        Result.success(BuiltList<int>([3, 2, 1, 0])),
      ]),
    );
    expect(
      roomBloc.room.transformResult((e) => e.lastMessage.chatMessage?.id),
      emitsInOrder([
        Result<int>.loading(),
        Result.success(null),
        Result.success(2),
        Result.success(3),
      ]),
    );

    expect(
      roomBloc.lastCommonRead,
      emitsInOrder([0, 1]),
    );

    // The delay is necessary to avoid a race condition with loading twice at the same time
    await Future<void>.delayed(const Duration(milliseconds: 1));
    roomBloc.sendMessage('');

    verify(() => talkBloc.updateRoom(any())).called(3);
  });

  test('polling', () async {
    expect(
      roomBloc.messages.transformResult((e) => BuiltList<int>(e.map((m) => m.id))),
      emitsInOrder([
        Result<BuiltList<int>>.loading(),
        Result.success(BuiltList<int>([2, 1, 0])),
        Result.success(BuiltList<int>([4, 3, 2, 1, 0])),
      ]),
    );
    expect(
      roomBloc.room.transformResult((e) => e.lastMessage.chatMessage?.id),
      emitsInOrder([
        Result<int>.loading(),
        Result.success(null),
        Result.success(2),
        Result.success(4),
      ]),
    );

    expect(
      roomBloc.lastCommonRead,
      emitsInOrder([0, 0]),
    );

    verify(() => talkBloc.updateRoom(any())).called(1);
  });
}
