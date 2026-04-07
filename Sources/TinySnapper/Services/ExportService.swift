import AppKit
import WebKit

enum ExportError: Error {
    case snapshotFailed
    case imageEncodingFailed
    case pasteboardWriteFailed
}

@MainActor
final class ExportService {
    private var activeSessions: [SnapshotSession] = []

    func copyToClipboard(from state: EditorState, completion: @escaping (Result<Void, ExportError>) -> Void) {
        snapshotImage(for: state) { result in
            switch result {
            case .success(let image):
                do {
                    try self.writeImageToPasteboard(image)
                    completion(.success(()))
                } catch let error as ExportError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.pasteboardWriteFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func writeImageToPasteboard(_ image: NSImage) throws {
        guard let pngData = image.pngData else {
            throw ExportError.imageEncodingFailed
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var wroteAny = false
        wroteAny = pasteboard.setData(pngData, forType: .png) || wroteAny

        if let tiffData = image.tiffRepresentation {
            wroteAny = pasteboard.setData(tiffData, forType: .tiff) || wroteAny
        }

        guard wroteAny else {
            throw ExportError.pasteboardWriteFailed
        }
    }

    func savePNG(from state: EditorState, completion: @escaping (Result<Void, ExportError>) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(state.title).png"

        guard panel.runModal() == .OK, let url = panel.url else {
            completion(.success(()))
            return
        }

        snapshotImage(for: state) { result in
            switch result {
            case .success(let image):
                guard let data = image.pngData else {
                    completion(.failure(.imageEncodingFailed))
                    return
                }
                do {
                    try data.write(to: url)
                    completion(.success(()))
                } catch {
                    completion(.failure(.imageEncodingFailed))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func snapshotImage(for state: EditorState, completion: @escaping (Result<NSImage, ExportError>) -> Void) {
        let payload = CanvasRenderer.makePayload(for: state, interactive: false)
        let session = SnapshotSession(
            html: CanvasRenderer.html(for: state, interactive: false),
            size: payload.stageSize,
            stageCornerRadius: payload.stageCornerRadius
        )
        session.onCompletion = { [weak self, weak session] result in
            completion(result)
            guard let self, let session else { return }
            self.activeSessions.removeAll { $0 === session }
        }
        activeSessions.append(session)
        session.start()
    }
}

@MainActor
private final class SnapshotSession: NSObject, WKNavigationDelegate {
    private let html: String
    private let webView: WKWebView
    private let stageCornerRadius: CGFloat
    private var finished = false
    var onCompletion: ((Result<NSImage, ExportError>) -> Void)?

    init(html: String, size: CGSize, stageCornerRadius: Double) {
        self.html = html
        self.webView = WKWebView(frame: CGRect(origin: .zero, size: size))
        self.stageCornerRadius = CGFloat(stageCornerRadius)
        self.webView.setValue(false, forKey: "drawsBackground")
        super.init()
    }

    func start() {
        webView.navigationDelegate = self
        webView.loadHTMLString(html, baseURL: CanvasRenderer.resourceBaseURL())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !finished else { return }
        finished = true

        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        config.rect = webView.bounds

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            webView.takeSnapshot(with: config) { image, _ in
                if let image {
                    let maskedImage = image.maskedToRoundedRect(cornerRadius: self.stageCornerRadius) ?? image
                    self.onCompletion?(.success(maskedImage))
                } else {
                    self.onCompletion?(.failure(.snapshotFailed))
                }
                self.onCompletion = nil
            }
        }
    }
}
