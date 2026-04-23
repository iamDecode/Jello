import Foundation

final class FridaSession {
  private let session: OpaquePointer

  init(raw: OpaquePointer) {
    self.session = raw
  }

  func createScript(source: String, name: String = "jello-injector") throws -> FridaScript {
    let options = frida_script_options_new()
    defer { g_object_unref(UnsafeMutableRawPointer(options)) }
    frida_script_options_set_name(options, name)
    frida_script_options_set_runtime(options, FRIDA_SCRIPT_RUNTIME_QJS)

    var gerror: UnsafeMutablePointer<GError>?
    guard let script = frida_session_create_script_sync(
      session, source, options, nil, &gerror
    ) else {
      throw FridaError.take(gerror)
    }
    return FridaScript(raw: script)
  }

  func detach() {
    frida_session_detach_sync(session, nil, nil)
  }

  deinit {
    g_object_unref(UnsafeMutableRawPointer(session))
  }
}
