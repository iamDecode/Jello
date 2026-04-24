import AppKit
import Foundation
import OSLog

/// Owns the enable/disable lifecycle: holds the Frida device, injects into running/launching apps.
@MainActor
final class InjectorController: ObservableObject {
  @Published private(set) var isEnabled: Bool = false

  private let log = Logger(subsystem: "com.decode.JelloInjector", category: "Injector")
  private let fridaQueue = DispatchQueue(
    label: "com.decode.JelloInjector.frida", qos: .userInitiated)

  private var device: FridaDevice?
  private var sessions: [pid_t: FridaSession] = [:]
  private var scripts: [pid_t: FridaScript] = [:]
  private var launchObserver: NSObjectProtocol?
  private var sipWarningShown = false

  private let skipBundleIDs: Set<String> = [
    "com.decode.JelloInjector",
    "com.decode.Jello",
    "com.apple.loginwindow",
    "com.apple.dock",
    "com.apple.WindowManager",
    "com.apple.controlcenter",
    "com.apple.notificationcenterui",
    "com.apple.systemuiserver",
    "com.apple.Spotlight",
    "com.apple.dt.Xcode",
  ]

  var bundlePath: String {
    Bundle.main.url(forResource: "JelloInject", withExtension: "bundle")?.path ?? ""
  }

  func toggle() {
    if isEnabled {
      disable()
    } else {
      enable()
    }
  }

  func enable() {
    guard !isEnabled else { return }
    guard !bundlePath.isEmpty else {
      log.error("JelloInject.bundle not found in Resources")
      presentAlert(
        title: "JelloInject.bundle missing",
        text: "The injector couldn't locate JelloInject.bundle in its own Resources folder."
      )
      return
    }

    isEnabled = true
    UserDefaults.standard.set(true, forKey: "JelloInjectorEnabled")

    fridaQueue.async { [weak self] in
      guard let self else { return }
      do {
        if self.device == nil {
          self.device = try FridaDevice()
          self.log.info("Frida device initialised")
        }
      } catch {
        self.log.error("Failed to init Frida device: \(String(describing: error))")
        Task { @MainActor in
          self.isEnabled = false
          UserDefaults.standard.set(false, forKey: "JelloInjectorEnabled")
          self.presentAlert(
            title: "Frida failed to start",
            text: "\(error)"
          )
        }
        return
      }

      let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
      for app in apps {
        self.injectOnFridaQueue(app: app)
      }
    }

    launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
      guard
        let self,
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      else { return }
      self.fridaQueue.async { self.injectOnFridaQueue(app: app) }
    }
  }

  func disable() {
    guard isEnabled else { return }
    isEnabled = false
    UserDefaults.standard.set(false, forKey: "JelloInjectorEnabled")

    if let token = launchObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(token)
      launchObserver = nil
    }

    fridaQueue.async { [weak self] in
      guard let self else { return }
      // Ask each agent to invoke JelloInjectTeardown (it dispatches the actual
      // cleanup to the target app's main queue, so the block survives even
      // after we unload the script below).
      for script in self.scripts.values {
        script.post("{\"type\":\"teardown\"}")
      }
      // Give agents a moment to process the posted message and kick off the
      // main-queue block before we tear down the script context.
      Thread.sleep(forTimeInterval: 0.3)
      for script in self.scripts.values { script.unload() }
      for session in self.sessions.values { session.detach() }
      self.scripts.removeAll()
      self.sessions.removeAll()
    }
  }

  // MARK: - Frida-queue helpers

  private static func isApplePlatformBinary(_ app: NSRunningApplication) -> Bool {
    // Resolve symlinks so Safari under /Applications/Safari.app is recognised
    // via its canonical /System/Volumes/Preboot/Cryptexes/App/System/... path.
    guard let resolved = app.bundleURL?.resolvingSymlinksInPath() else { return false }
    let path = resolved.path
    return path.hasPrefix("/System/") || path.hasPrefix("/Library/Apple/")
  }

  private func injectOnFridaQueue(app: NSRunningApplication) {
    dispatchPrecondition(condition: .onQueue(fridaQueue))
    guard let device else { return }
    let pid = app.processIdentifier
    guard pid > 0 else { return }
    if let bid = app.bundleIdentifier, skipBundleIDs.contains(bid) { return }
    if sessions[pid] != nil { return }
    // Apple platform binaries crash under Frida on macOS 26 — codeSigningMonitor
    // SIGBUSes the target mid-patch, so there is no "injection failed" signal
    // to react to. Skip them up front.
    if Self.isApplePlatformBinary(app) {
      let label = app.bundleIdentifier ?? app.localizedName ?? "pid=\(pid)"
      log.info("Skipping Apple platform binary \(label, privacy: .public) (pid=\(pid))")
      return
    }

    let label = app.bundleIdentifier ?? app.localizedName ?? "pid=\(pid)"
    do {
      let session = try device.attach(pid: pid)
      let script = try session.createScript(source: Self.agentSource(bundlePath: bundlePath))
      let scriptLog = self.log
      script.setOnMessage { msg in
        scriptLog.info("script[\(label, privacy: .public) pid=\(pid)] \(msg, privacy: .public)")
      }
      try script.load()
      sessions[pid] = session
      scripts[pid] = script
      log.info("Injected into \(label, privacy: .public) (pid=\(pid))")
    } catch {
      log.error(
        "Inject failed for \(label, privacy: .public) (pid=\(pid)): \(String(describing: error))")
      Task { @MainActor in self.maybeShowSIPWarning() }
    }
  }

  private static func agentSource(bundlePath: String) -> String {
    let binaryPath = (bundlePath as NSString).appendingPathComponent("Contents/MacOS/JelloInject")
    let escaped =
      binaryPath
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "'", with: "\\'")
    return """
      send({ stage: 'top-of-script', pid: Process.id });
      try {
        const path = '\(escaped)';
        send({ stage: 'dlopen-start', path });
        const dlopen = new NativeFunction(
          Module.getGlobalExportByName('dlopen'),
          'pointer', ['pointer', 'int']
        );
        const dlerror = new NativeFunction(
          Module.getGlobalExportByName('dlerror'),
          'pointer', []
        );
        const RTLD_NOW = 2;
        const pathPtr = Memory.allocUtf8String(path);
        const handle = dlopen(pathPtr, RTLD_NOW);
        if (handle.isNull()) {
          const errPtr = dlerror();
          const err = errPtr.isNull() ? 'unknown' : errPtr.readUtf8String();
          send({ stage: 'dlopen-failed', err });
        } else {
          send({ stage: 'dlopen-ok', handle: handle.toString() });

          const initSym = Module.findGlobalExportByName('JelloInjectInit');
          if (initSym) {
            new NativeFunction(initSym, 'void', [])();
            send({ stage: 'init-called' });
          } else {
            send({ stage: 'init-missing' });
          }

          const teardownSym = Module.findGlobalExportByName('JelloInjectTeardown');
          recv('teardown', () => {
            try {
              if (teardownSym) {
                new NativeFunction(teardownSym, 'void', [])();
                send({ stage: 'teardown-called' });
              } else {
                send({ stage: 'teardown-missing' });
              }
            } catch (e) {
              send({ stage: 'teardown-error', err: String(e) });
            }
          });
        }
      } catch (e) {
        send({ stage: 'top-level-exception', err: String(e) });
      }
      """
  }

  // MARK: - SIP notice

  private func maybeShowSIPWarning() {
    guard !sipWarningShown else { return }
    if UserDefaults.standard.bool(forKey: "JelloInjectorSIPWarningSuppressed") { return }
    sipWarningShown = true

    let alert = NSAlert()
    alert.messageText = "Some apps couldn't be injected"
    alert.informativeText = """
      Jello needs to attach to other apps. On Apple Silicon, macOS blocks this for most third-party \
      apps unless SIP's debug protection is disabled. From Recovery Mode, run:

          csrutil enable --without debug

      Without this, Jello will only work in a handful of apps (typically self-built or \
      developer-signed with get-task-allow).
      """
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Don't show again")
    let response = alert.runModal()
    if response == .alertSecondButtonReturn {
      UserDefaults.standard.set(true, forKey: "JelloInjectorSIPWarningSuppressed")
    }
  }

  private func presentAlert(title: String, text: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = text
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}
