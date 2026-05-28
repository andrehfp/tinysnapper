import AppKit
import CoreGraphics
import Foundation

enum CaptureError: Error {
    case failed(message: String)
    case screenRecordingPermissionDenied
}

final class CaptureService {
    func captureInteractive(completion: @escaping @Sendable (Result<NSImage?, CaptureError>) -> Void) {
        guard Self.hasScreenRecordingPermission() else {
            completion(.failure(.screenRecordingPermissionDenied))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")

            let outputPipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-s", "-x", tempURL.path]
            process.standardError = outputPipe
            process.standardOutput = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.failed(message: error.localizedDescription)))
                }
                return
            }

            let stderr = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let fileExists = FileManager.default.fileExists(atPath: tempURL.path)

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            if fileExists, let image = NSImage(contentsOf: tempURL) {
                DispatchQueue.main.async {
                    completion(.success(image))
                }
                return
            }

            if stderr.isEmpty || stderr.localizedCaseInsensitiveContains("cancel") {
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.failure(.failed(message: stderr.trimmingCharacters(in: .whitespacesAndNewlines))))
            }
        }
    }

    private static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
    }
}
