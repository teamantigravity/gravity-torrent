import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:gravity_torrent/utils/update.dart';

void main() {
  group('latestUpgradeVersion', () {
    test('ignores the rolling latest-successful-build release', () {
      final releases = [
        {'tag_name': 'latest-successful-build', 'draft': false},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.1')), isNull);
    });

    test('returns a newer semver tag, stripping the optional v prefix', () {
      final releases = [
        {'tag_name': 'latest-successful-build', 'draft': false},
        {'tag_name': 'v1.2.0', 'draft': false},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.1')), '1.2.0');
    });

    test('returns null when the newest release is not newer', () {
      final releases = [
        {'tag_name': 'v1.0.1', 'draft': false},
        {'tag_name': '1.0.0', 'draft': false},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.1')), isNull);
    });

    test('picks the highest version regardless of list order', () {
      final releases = [
        {'tag_name': 'v1.1.0'},
        {'tag_name': 'v2.3.1'},
        {'tag_name': 'v2.0.0'},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.0')), '2.3.1');
    });

    test('skips drafts and pre-releases', () {
      final releases = [
        {'tag_name': 'v3.0.0', 'draft': true},
        {'tag_name': 'v2.9.0', 'prerelease': true},
        {'tag_name': 'v2.0.0'},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.0')), '2.0.0');
    });

    test('tolerates malformed entries and non-semver tags', () {
      final releases = [
        'garbage',
        {'tag_name': 42},
        {'tag_name': 'nightly'},
        {'tag_name': 'v1.5.0'},
      ];
      expect(latestUpgradeVersion(releases, Version.parse('1.0.0')), '1.5.0');
    });
  });
}
