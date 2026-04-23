import AppKit
import SwiftUI

@main
struct JelloInjectorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings { EmptyView() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private let controller = InjectorController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      let image: NSImage? = {
        if let url = Bundle.main.url(forResource: "jello", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
          img.size = NSSize(width: 18, height: 18)
          return img
        }
        return NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Jello")
      }()
      image?.isTemplate = true
      button.image = image
    }
    rebuildMenu()

    if UserDefaults.standard.bool(forKey: "JelloInjectorEnabled") {
      controller.enable()
    }

    NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.rebuildMenu() }
  }

  private func rebuildMenu() {
    let menu = NSMenu()

    let toggle = NSMenuItem(
      title: controller.isEnabled ? "Disable Jello" : "Enable Jello",
      action: #selector(toggleEnabled),
      keyEquivalent: ""
    )
    toggle.target = self
    toggle.state = controller.isEnabled ? .on : .off
    menu.addItem(toggle)

    menu.addItem(NSMenuItem.separator())

    let quit = NSMenuItem(
      title: "Quit",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quit)

    statusItem.menu = menu
  }

  @objc private func toggleEnabled() {
    controller.toggle()
    rebuildMenu()
  }
}
