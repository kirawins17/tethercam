import Foundation
import AVFoundation
import CoreImage
import ImageIO
import Network

/// Captures the camera and serves it on a TCP port.
///
/// Wire protocol (same idea as scrcpy's video socket, simplified):
///   repeat forever: [4-byte big-endian length N][N bytes of JPEG]
///
/// The PC reaches this port over the USB cable through Apple's usbmux
/// (the iPhone equivalent of `adb forward`), so no Wi-Fi is needed.
final class CameraServer: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let port: UInt16 = 8765
    static let jpegQuality: CGFloat = 0.7

    let session = AVCaptureSession()

    @Published var status = "Starting…"
    @Published var useFront = false
    @Published var dimPreview = false

    // Everything below is only touched on `queue`.
    private let queue = DispatchQueue(label: "tethercam.queue")
    private let output = AVCaptureVideoDataOutput()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var listener: NWListener?
    private var client: NWConnection?
    private var sending = false
    private var started = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                self.setStatus("Camera access denied. Turn it on in Settings › Tethercam.")
                return
            }
            self.queue.async {
                guard !self.started else { return }
                self.started = true
                self.configureSession(front: false)
                self.session.startRunning()
                self.startListener()
            }
        }
    }

    func toggleCamera() {
        useFront.toggle()
        let front = useFront
        queue.async {
            self.session.beginConfiguration()
            self.setInput(front: front)
            self.session.commitConfiguration()
        }
    }

    // MARK: - Camera

    private func configureSession(front: Bool) {
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }
        setInput(front: front)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    private func setInput(front: Bool) {
        session.inputs.forEach { session.removeInput($0) }
        let position: AVCaptureDevice.Position = front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            setStatus("Could not open the \(front ? "front" : "back") camera")
            return
        }
        session.addInput(input)
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Drop frames while the previous one is still being sent, like a real webcam.
        guard let conn = client, conn.state == .ready, !sending,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let qualityKey = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        guard let jpeg = ciContext.jpegRepresentation(of: image,
                                                      colorSpace: colorSpace,
                                                      options: [qualityKey: Self.jpegQuality]) else { return }

        var length = UInt32(jpeg.count).bigEndian
        var packet = withUnsafeBytes(of: &length) { Data($0) }
        packet.append(jpeg)

        sending = true
        conn.send(content: packet, completion: .contentProcessed { [weak self] error in
            self?.sending = false
            if error != nil { conn.cancel() }
        })
    }

    // MARK: - Network

    private func startListener() {
        do {
            // Security: listen on loopback only. The USB cable (usbmux) delivers
            // connections to 127.0.0.1, so the PC can connect over the cable, but
            // nobody on your Wi-Fi network can reach the camera.
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback),
                                                     port: NWEndpoint.Port(rawValue: Self.port)!)
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.setStatus("Ready. Plug into your PC and run tethercam.")
                case .failed(let error):
                    self?.setStatus("Server error: \(error.localizedDescription)")
                default:
                    break
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            setStatus("Could not open port \(Self.port): \(error.localizedDescription)")
        }
    }

    private func accept(_ conn: NWConnection) {
        // Second check: refuse anything that is not from this phone itself.
        guard Self.isLoopback(conn.endpoint) else {
            conn.cancel()
            return
        }
        // One PC at a time: a new connection replaces the old one.
        client?.cancel()
        client = conn
        sending = false
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                self.setStatus("Streaming to your PC")
                self.watchForClose(conn)
            case .failed, .cancelled:
                if self.client === conn {
                    self.client = nil
                    self.sending = false
                    self.setStatus("PC disconnected. Waiting…")
                }
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case .hostPort(let host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let address):
            return address.isLoopback
        case .ipv6(let address):
            return address.isLoopback || (address.asIPv4?.isLoopback ?? false)
        case .name(let name, _):
            return name == "localhost"
        @unknown default:
            return false
        }
    }

    /// The PC never sends data; reading just tells us when it hangs up.
    private func watchForClose(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64) { [weak self] _, _, isComplete, error in
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            self?.watchForClose(conn)
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { self.status = text }
    }
}
