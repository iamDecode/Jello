import Foundation

/// Thin wrapper around the local Frida device.
/// All methods are synchronous; call them from a background queue.
final class FridaDevice {
  private let manager: OpaquePointer
  private let device: OpaquePointer

  init() throws {
    Frida.initialize()

    guard let manager = frida_device_manager_new() else {
      throw FridaError.runtime(domain: 0, code: 0, message: "frida_device_manager_new returned nil")
    }
    self.manager = manager

    var gerror: UnsafeMutablePointer<GError>?
    guard let device = frida_device_manager_get_device_by_type_sync(
      manager, FRIDA_DEVICE_TYPE_LOCAL, 5000, nil, &gerror
    ) else {
      g_object_unref(UnsafeMutableRawPointer(manager))
      throw FridaError.take(gerror)
    }
    self.device = device
  }

  func attach(pid: pid_t) throws -> FridaSession {
    var gerror: UnsafeMutablePointer<GError>?
    guard let session = frida_device_attach_sync(
      device, UInt32(pid), nil, nil, &gerror
    ) else {
      throw FridaError.take(gerror)
    }
    return FridaSession(raw: session)
  }

  deinit {
    frida_device_manager_close_sync(manager, nil, nil)
    g_object_unref(UnsafeMutableRawPointer(device))
    g_object_unref(UnsafeMutableRawPointer(manager))
  }
}
