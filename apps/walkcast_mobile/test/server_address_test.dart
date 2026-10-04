import 'package:flutter_test/flutter_test.dart';
import 'package:walkcast_mobile/src/core/config/server_address.dart';

void main() {
  test('LAN address and explicit port normalize correctly', () {
    expect(
      normalizeServerAddress(' 192.168.1.10 ', '8000'),
      'http://192.168.1.10:8000',
    );
    expect(
      normalizeServerAddress('https://example.com:8443/', ''),
      'https://example.com:8443',
    );
  });
  test('HTTPS default port and IPv6 remain valid', () {
    expect(
      normalizeServerAddress('https://example.com', ''),
      'https://example.com',
    );
    expect(normalizeServerAddress('http://[::1]', '8000'), 'http://[::1]:8000');
  });
  test(
    'unsupported schemes, credentials, paths and fragments are rejected',
    () {
      for (final host in [
        '',
        'file:///tmp',
        'ftp://example.com',
        'http://u:p@example.com',
        'https://example.com/api/v1',
        'https://example.com?q=1',
        'https://example.com#x',
        'bad host',
      ]) {
        expect(
          () => normalizeServerAddress(host, '8000'),
          throwsFormatException,
          reason: host,
        );
      }
    },
  );
  test('port range and nonnumeric values are rejected', () {
    for (final port in ['0', '65536', '-1', 'abc']) {
      expect(
        () => normalizeServerAddress('localhost', port),
        throwsFormatException,
      );
    }
  });
}
