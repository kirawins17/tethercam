import SwiftUI
import AVFoundation

@main
struct TethercamApp: App {
    @StateObject private var server = CameraServer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(server)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var server: CameraServer

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: server.session)
                .ignoresSafeArea()
                .opacity(server.dimPreview ? 0 : 1)

            VStack(spacing: 12) {
                Spacer()
                Text(server.status)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .foregroundColor(.white)
                    .cornerRadius(10)

                HStack(spacing: 12) {
                    Button(server.useFront ? "Use back camera" : "Use front camera") {
                        server.toggleCamera()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(server.dimPreview ? "Show preview" : "Hide preview") {
                        server.dimPreview.toggle()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // The camera only works while the app is on screen, so keep the phone awake.
            UIApplication.shared.isIdleTimerDisabled = true
            server.start()
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
