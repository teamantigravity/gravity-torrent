import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Handle opening a single .torrent / magnet file.
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    AppLinks.shared.handleLink(link: filename)
    return true
  }

  // Handle opening multiple files.
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      AppLinks.shared.handleLink(link: filename)
    }
  }
}
