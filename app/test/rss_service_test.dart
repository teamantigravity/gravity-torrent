import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RssFeed', () {
    test('round-trips through JSON', () {
      const feed = RssFeed(
        url: 'https://example.com/feed.xml',
        keyword: '1080p',
        enabled: false,
      );
      final json = feed.toJson();
      final restored = RssFeed.fromJson(json);

      expect(restored.url, feed.url);
      expect(restored.keyword, feed.keyword);
      expect(restored.enabled, feed.enabled);
    });

    test('uses sensible defaults', () {
      final feed = RssFeed.fromJson({'url': 'https://example.com/feed.xml'});
      expect(feed.keyword, '');
      expect(feed.enabled, isTrue);
    });
  });

  group('RssService link extraction', () {
    test('extracts magnet links from text', () {
      final links = RssService.instance.candidateLinks(
        null,
        'Check out magnet:?xt=urn:btih:abc&dn=foo and another magnet:?xt=urn:btih:def',
      );

      expect(links.length, 2);
      expect(links.first, startsWith('magnet:'));
    });

    test('extracts .torrent URLs from text', () {
      final links = RssService.instance.candidateLinks(
        null,
        'Download https://example.com/foo.torrent or https://example.com/bar.TORRENT',
      );

      expect(links.length, 2);
      expect(links.first, endsWith('.torrent'));
    });

    test('extracts links from XML elements', () {
      final document = XmlDocument.parse('''
        <item>
          <title>Example</title>
          <link>https://example.com/file.torrent</link>
          <enclosure url="https://example.com/enclosure.torrent" />
          <torrent:magnetURI xmlns:torrent="http://example.com/torrent">
            magnet:?xt=urn:btih:xyz
          </torrent:magnetURI>
        </item>
      ''');
      final item = document.findAllElements('item').first;

      final links = RssService.instance.candidateLinks(item, item.innerText);

      expect(links, contains('https://example.com/file.torrent'));
      expect(links, contains('https://example.com/enclosure.torrent'));
      expect(links, contains('magnet:?xt=urn:btih:xyz'));
    });

    test('ignores non-torrent links', () {
      final links = RssService.instance.candidateLinks(
        null,
        'Visit https://example.com/page.html or https://example.com/file.zip',
      );

      expect(links, isEmpty);
    });

    test('handles CDATA content', () {
      final document = XmlDocument.parse('''
        <item>
          <description><![CDATA[<p> magnet:?xt=urn:btih:cdata </p>]]></description>
        </item>
      ''');
      final item = document.findAllElements('item').first;

      final links = RssService.instance.candidateLinks(item, item.innerText);

      expect(links, contains('magnet:?xt=urn:btih:cdata'));
    });

    test('isTorrentLink recognizes magnets and torrent files', () {
      expect(
          RssService.instance.isTorrentLink('magnet:?xt=urn:btih:abc'), isTrue);
      expect(
        RssService.instance.isTorrentLink('https://example.com/file.torrent'),
        isTrue,
      );
      expect(
        RssService.instance.isTorrentLink('https://example.com/file.zip'),
        isFalse,
      );
      expect(
        RssService.instance.isTorrentLink(''),
        isFalse,
      );
    });
  });
}
