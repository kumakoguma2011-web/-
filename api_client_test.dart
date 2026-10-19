import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/services/api_client.dart';

void main() {
  test('ApiClient adds bearer token and decodes JSON', () async {
    late Map<String, String> received;
    final client = MockClient((request) async {
      received = request.headers;
      return http.Response(jsonEncode({'ok': true}), 200, headers: {'content-type': 'application/json'});
    });
    final api = ApiClient('https://example.test', client: client)..accessToken = 'token-123';
    final result = await api.get('/health');
    expect(result['ok'], isTrue);
    expect(received['authorization'], 'Bearer token-123');
  });

  test('ApiClient surfaces HTTP errors', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'message': 'unauthorized'}), 401, headers: {'content-type': 'application/json'}));
    final api = ApiClient('https://example.test', client: client);
    await expectLater(api.get('/profile'), throwsA(isA<ApiException>()));
  });
  test('ApiClient normalizes a trailing slash and preserves an API prefix', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiClient('https://example.test/api/', client: client);
    await api.get('/profile');
    expect(requested.toString(), 'https://example.test/api/profile');
  });

}
