import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dardito/features/contribute/story_submission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'fixture-user';
  @override
  bool get emailVerified => true;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'fixture-token';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Snapshot extends Fake implements TaskSnapshot {
  @override
  int get bytesTransferred => 3;
  @override
  int get totalBytes => 3;
}

class _UploadTask extends Fake implements UploadTask {
  _UploadTask(this.fails);
  final bool fails;
  @override
  Stream<TaskSnapshot> get snapshotEvents => Stream.value(_Snapshot());
  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) =>
      (fails
              ? Future<TaskSnapshot>.error(StateError('Fixture upload failure'))
              : Future<TaskSnapshot>.value(_Snapshot()))
          .then(onValue, onError: onError);
}

class _Reference extends Fake implements Reference {
  _Reference(this.events, this.path, this.fails);
  final List<String> events;
  @override
  final String fullPath = '';
  final String path;
  final bool fails;
  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    events.add('upload:$path');
    return _UploadTask(fails);
  }
}

class _Storage extends Fake implements FirebaseStorage {
  _Storage(this.events, {this.fails = false});
  final List<String> events;
  final bool fails;
  @override
  Reference ref([String? path]) => _Reference(events, path!, fails);
}

Future<String> _submit(
  StorySubmissionService service, {
  bool withPhoto = true,
}) => service.submit(
  title: 'Un recuerdo de Tolosa',
  story: 'Mi abuelo atendía este almacén y el barrio recuerda sus tardes.',
  category: 'memory',
  neighborhood: 'Tolosa',
  period: 'Década de 1960',
  evidence: 'oral_tradition',
  materialConsent: true,
  legalConsent: true,
  photos: withPhoto
      ? [
          SelectedStoryPhoto(
            name: 'fixture.jpg',
            bytes: Uint8List.fromList([255, 216, 255]),
            contentType: 'image/jpeg',
          ),
        ]
      : [],
  clientMetadata: {},
  onProgress: (_) {},
);

void main() {
  test(
    'autoriza antes de cargar y envía únicamente las rutas reservadas',
    () async {
      final events = <String>[];
      String? id;
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer fixture-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        id = body['submissionId'] as String;
        if (body['action'] == 'prepare') {
          events.add('prepare');
          expect(body['photos'], [
            {'name': 'photo_0.jpg', 'size': 3, 'contentType': 'image/jpeg'},
          ]);
          return http.Response(
            jsonEncode({
              'submissionId': id,
              'photoPaths': ['story_submissions/fixture-user/$id/photo_0.jpg'],
            }),
            200,
          );
        }
        events.add('submit');
        expect(body['photoPaths'], [
          'story_submissions/fixture-user/$id/photo_0.jpg',
        ]);
        return http.Response(jsonEncode({'id': id}), 202);
      });
      final result = await _submit(
        StorySubmissionService(
          auth: _Auth(),
          storage: _Storage(events),
          client: client,
        ),
      );
      expect(result, id);
      expect(events, [
        'prepare',
        'upload:story_submissions/fixture-user/$id/photo_0.jpg',
        'submit',
      ]);
    },
  );

  test('una reserva rechazada nunca inicia la carga de archivos', () async {
    final events = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      events.add(body['action'] as String);
      if (body['action'] == 'cancel')
        return http.Response('{"status":"missing"}', 200);
      return http.Response(
        '{"error":"Cuota agotada","code":"RATE_LIMITED"}',
        429,
      );
    });
    await expectLater(
      _submit(
        StorySubmissionService(
          auth: _Auth(),
          storage: _Storage(events),
          client: client,
        ),
      ),
      throwsA(isA<StorySubmissionException>()),
    );
    expect(events, ['prepare', 'cancel']);
  });

  test('una carga fallida cancela la reserva en el servidor', () async {
    final events = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      events.add(body['action'] as String);
      if (body['action'] == 'cancel')
        return http.Response('{"status":"cancelled"}', 200);
      final id = body['submissionId'];
      return http.Response(
        jsonEncode({
          'submissionId': id,
          'photoPaths': ['story_submissions/fixture-user/$id/photo_0.jpg'],
        }),
        200,
      );
    });
    await expectLater(
      _submit(
        StorySubmissionService(
          auth: _Auth(),
          storage: _Storage(events, fails: true),
          client: client,
        ),
      ),
      throwsA(isA<StorySubmissionException>()),
    );
    expect(events.first, 'prepare');
    expect(events[1], startsWith('upload:'));
    expect(events.last, 'cancel');
  });

  test(
    'recupera el éxito si el servidor aceptó el aporte pero falló su respuesta',
    () async {
      final events = <String>[];
      String? id;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        id = body['submissionId'] as String;
        if (body['action'] == 'prepare')
          return http.Response(
            jsonEncode({
              'submissionId': id,
              'photoPaths': ['story_submissions/fixture-user/$id/photo_0.jpg'],
            }),
            200,
          );
        if (body['action'] == 'cancel')
          return http.Response('{"status":"submitted"}', 200);
        return http.Response('{"error":"Fixture response failure"}', 500);
      });
      expect(
        await _submit(
          StorySubmissionService(
            auth: _Auth(),
            storage: _Storage(events),
            client: client,
          ),
        ),
        id,
      );
    },
  );

  test('un aporte sin fotos conserva el envío directo sin reserva', () async {
    final events = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('action'), false);
      expect(body['photoPaths'], isEmpty);
      return http.Response(jsonEncode({'id': body['submissionId']}), 202);
    });
    await _submit(
      StorySubmissionService(
        auth: _Auth(),
        storage: _Storage(events),
        client: client,
      ),
      withPhoto: false,
    );
    expect(events, isEmpty);
  });
}
