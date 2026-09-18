import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_http_transport.dart';

void main() {
  final transport = CloudHttpTransport();

  test('normalizes HTTPS Cloud origin', () {
    expect(
      transport.normalizeBaseUrl(' https://cloud.example.com/ '),
      'https://cloud.example.com',
    );
    expect(
      transport.normalizeBaseUrl('https://cloud.example.com:8443'),
      'https://cloud.example.com:8443',
    );
  });

  test('rejects non-HTTPS and API paths', () {
    expect(
      () => transport.normalizeBaseUrl('http://cloud.example.com'),
      throwsFormatException,
    );
    expect(
      () => transport.normalizeBaseUrl('https://cloud.example.com/api/v1'),
      throwsFormatException,
    );
    expect(
      () => transport.normalizeBaseUrl('https://cloud.example.com?x=1'),
      throwsFormatException,
    );
  });
}
