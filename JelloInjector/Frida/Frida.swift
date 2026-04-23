import Foundation

enum FridaError: Error, CustomStringConvertible {
  case runtime(domain: UInt32, code: Int32, message: String)

  var description: String {
    switch self {
    case .runtime(_, _, let message): return message
    }
  }

  static func take(_ gerror: UnsafeMutablePointer<GError>?) -> FridaError {
    guard let gerror else {
      return .runtime(domain: 0, code: 0, message: "unknown frida error")
    }
    let message = gerror.pointee.message.map { String(cString: $0) } ?? "unknown"
    let err = FridaError.runtime(
      domain: gerror.pointee.domain,
      code: gerror.pointee.code,
      message: message
    )
    g_error_free(gerror)
    return err
  }
}

enum Frida {
  private static var initialized = false
  private static let lock = NSLock()

  static func initialize() {
    lock.lock(); defer { lock.unlock() }
    guard !initialized else { return }
    frida_init()
    initialized = true
  }

  static func shutdown() {
    lock.lock(); defer { lock.unlock() }
    guard initialized else { return }
    frida_deinit()
    initialized = false
  }
}
