import Foundation

final class FridaScript {
  private let script: OpaquePointer

  private final class HandlerBox {
    let onMessage: (String) -> Void
    init(_ h: @escaping (String) -> Void) { self.onMessage = h }
  }
  private var handlerBox: Unmanaged<HandlerBox>?

  init(raw: OpaquePointer) {
    self.script = raw
  }

  func setOnMessage(_ handler: @escaping (String) -> Void) {
    let box = HandlerBox(handler)
    let retained = Unmanaged.passRetained(box)
    self.handlerBox = retained
    let userData = retained.toOpaque()
    let callback: @convention(c) (
      OpaquePointer?, UnsafePointer<CChar>?, OpaquePointer?, UnsafeMutableRawPointer?
    ) -> Void = { _, msgCStr, _, user in
      guard let msgCStr, let user else { return }
      let msg = String(cString: msgCStr)
      let box = Unmanaged<HandlerBox>.fromOpaque(user).takeUnretainedValue()
      box.onMessage(msg)
    }
    _ = g_signal_connect_data(
      UnsafeMutableRawPointer(script),
      "message",
      unsafeBitCast(callback, to: GCallback.self),
      userData,
      nil,
      GConnectFlags(rawValue: 0)
    )
  }

  func load() throws {
    var gerror: UnsafeMutablePointer<GError>?
    frida_script_load_sync(script, nil, &gerror)
    if gerror != nil {
      throw FridaError.take(gerror)
    }
  }

  func unload() {
    frida_script_unload_sync(script, nil, nil)
  }

  deinit {
    handlerBox?.release()
    g_object_unref(UnsafeMutableRawPointer(script))
  }
}
