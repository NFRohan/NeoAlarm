import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/core/app/app_metadata.dart';

void main() {
  test('app metadata version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\+]+)\+(.+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(AppMetadata.version, match!.group(1));
    expect(AppMetadata.buildNumber, match.group(2));
  });
}
