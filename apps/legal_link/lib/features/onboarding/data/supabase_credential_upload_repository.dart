import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/credential_upload.dart';

class SupabaseCredentialUploadRepository implements CredentialUploadRepository {
  SupabaseCredentialUploadRepository(
    this._client, {
    required this.endpoint,
    http.Client? transport,
  }) : _transport = transport ?? http.Client(),
       _ownsTransport = transport == null;

  static const chunkBytes = 6 * 1024 * 1024;
  final SupabaseClient _client;
  final Uri endpoint;
  final http.Client _transport;
  final bool _ownsTransport;
  final _pending = <String, _UploadSession>{};
  final _running = <String>{};

  void dispose() {
    if (_ownsTransport) _transport.close();
  }

  @override
  Future<String> upload({
    required String userId,
    required CredentialKind kind,
    required CredentialFile file,
    required void Function(double) onProgress,
  }) async {
    final failure = file.validate();
    if (failure != null) throw failure;
    _headers(userId);
    final key = '$userId/${kind.name}/${sha256.convert(file.bytes)}';
    if (!_running.add(key)) throw UploadFailure.unavailable;
    try {
      final session = await _session(key, userId, kind, file);
      var offset = session.offset;
      onProgress(offset / file.bytes.length);
      while (offset < file.bytes.length) {
        final end = min(offset + chunkBytes, file.bytes.length);
        offset = await _patch(session, userId, file, offset, end);
        onProgress(offset / file.bytes.length);
      }
      _pending.remove(key);
      return session.path;
    } catch (error) {
      if (error is UploadFailure) rethrow;
      throw UploadFailure.unavailable;
    } finally {
      _running.remove(key);
    }
  }

  Map<String, String> _headers(String owner) {
    final session = _client.auth.currentSession;
    if (session == null ||
        session.user.id != owner ||
        session.user.appMetadata['role'] != 'advocate') {
      throw UploadFailure.unavailable;
    }
    return {
      'authorization': 'Bearer ${session.accessToken}',
      'tus-resumable': '1.0.0',
      'x-upsert': 'false',
    };
  }

  Future<_UploadSession> _session(
    String key,
    String owner,
    CredentialKind kind,
    CredentialFile file,
  ) async {
    final previous = _pending[key];
    if (previous != null) {
      final response = await _send('HEAD', previous.uri, _headers(owner));
      if (response.statusCode == 200 || response.statusCode == 204) {
        previous.offset = _offset(response, file.bytes.length);
        return previous;
      }
      if (response.statusCode != 404 && response.statusCode != 410) {
        throw UploadFailure.unavailable;
      }
    }
    final extension = file.name.split('.').last.toLowerCase();
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final path = '$owner/${kind.name}-$suffix.$extension';
    final headers = {
      ..._headers(owner),
      'upload-length': '${file.bytes.length}',
      'upload-metadata': _metadata(kind, path, extension),
    };
    final response = await _send('POST', endpoint, headers);
    if (response.statusCode != 201) throw UploadFailure.unavailable;
    final location = response.headers['location'];
    if (location == null) throw UploadFailure.unavailable;
    final uri = endpoint.resolve(location);
    if (uri.origin != endpoint.origin) throw UploadFailure.unavailable;
    final created = _UploadSession(uri, path);
    _pending[key] = created;
    return created;
  }

  String _metadata(CredentialKind kind, String path, String extension) {
    final values = {
      'bucketName': kind == CredentialKind.avatar ? 'avatars' : 'sanad',
      'objectName': path,
      'contentType': extension == 'png' ? 'image/png' : 'image/jpeg',
      'cacheControl': '3600',
    };
    return values.entries
        .map(
          (entry) => '${entry.key} ${base64.encode(utf8.encode(entry.value))}',
        )
        .join(',');
  }

  Future<int> _patch(
    _UploadSession session,
    String owner,
    CredentialFile file,
    int offset,
    int end,
  ) async {
    final response = await _send('PATCH', session.uri, {
      ..._headers(owner),
      'upload-offset': '$offset',
      'content-type': 'application/offset+octet-stream',
    }, bytes: file.bytes.sublist(offset, end));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw UploadFailure.unavailable;
    }
    final acknowledged = _offset(response, file.bytes.length);
    if (acknowledged != end) throw UploadFailure.unavailable;
    session.offset = acknowledged;
    return acknowledged;
  }

  int _offset(http.Response response, int length) {
    final value = int.tryParse(response.headers['upload-offset'] ?? '');
    if (value == null || value < 0 || value > length) {
      throw UploadFailure.unavailable;
    }
    return value;
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers, {
    List<int>? bytes,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll(headers)
      ..followRedirects = false;
    if (bytes != null) request.bodyBytes = bytes;
    return http.Response.fromStream(await _transport.send(request));
  }
}

class _UploadSession {
  _UploadSession(this.uri, this.path);
  final Uri uri;
  final String path;
  int offset = 0;
}
