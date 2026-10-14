import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraViewModel()
    @AppStorage("macAddress") private var macAddress = ""
    @State private var streaming = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
            VStack(spacing: 22) {
                RobotEyesView(direction: camera.direction)
                    .frame(height: 190)
                    .padding(.top, 24)

                RoundedRectangle(cornerRadius: 5).fill(.cyan)
                    .frame(width: 40, height: 28)
                    .overlay(Rectangle().fill(.black).frame(width: 14, height: 8))
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Rectangle().fill(.cyan).frame(width: 28, height: index == 0 || index == 4 ? 14 : 24)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 6))

                CameraPreviewView(session: camera.session)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        Text("FRONT CAMERA")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(12)
                    }
                    .overlay {
                        FaceOverlay(faceBox: camera.faceBox)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                StatusPanel(
                    permissionStatus: camera.permissionStatus,
                    faceX: camera.faceCenterX,
                    direction: camera.direction
                )
                .padding(.bottom, 24)
                TextField("http://192.168.1.10:8765", text: $macAddress)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder).foregroundStyle(.black).disabled(streaming)
                Toggle("Mac camera", isOn: $streaming)
                    .onChange(of: streaming) { _, enabled in camera.setStreaming(address: enabled ? macAddress : nil) }
                Text(camera.streamStatus).font(.caption)
            }
            .padding(.horizontal, 18)
            }
        }
        .foregroundStyle(.white)
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

private struct RobotEyesView: View {
    let direction: FaceDirection

    var body: some View {
        HStack(spacing: 34) {
            EyeView(offset: direction.pupilOffset)
            EyeView(offset: direction.pupilOffset)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: direction)
        .accessibilityLabel("Robot eyes")
    }
}

private struct EyeView: View {
    let offset: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.cyan, lineWidth: 5).padding(5))

            RoundedRectangle(cornerRadius: 3)
                .fill(.cyan)
                .frame(width: 42, height: 70)
                .overlay(Rectangle().fill(.white).frame(width: 12, height: 12).offset(x: -8, y: -19))
                .offset(x: offset)
        }
        .frame(width: 112, height: 132)
    }
}

private struct FaceOverlay: View {
    let faceBox: CGRect?

    var body: some View {
        GeometryReader { geometry in
            if let faceBox {
                let rect = CGRect(
                    x: faceBox.minX * geometry.size.width,
                    y: faceBox.minY * geometry.size.height,
                    width: faceBox.width * geometry.size.width,
                    height: faceBox.height * geometry.size.height
                )

                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}

private struct StatusPanel: View {
    let permissionStatus: String
    let faceX: CGFloat?
    let direction: FaceDirection

    var body: some View {
        VStack(spacing: 8) {
            Text(permissionStatus)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))

            Text(direction.rawValue)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospaced()

            Text("X: \(formattedFaceX)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var formattedFaceX: String {
        guard let faceX else { return "--" }
        return String(format: "%.2f", faceX)
    }
}

#Preview {
    ContentView()
}
