import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraViewModel()
    @AppStorage("macAddress") private var macAddress = ""
    @State private var streaming = false
    @State private var showingSettings = false
    @State private var emotion: RobotEmotion = .calm
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            RobotFaceView(direction: camera.direction, emotion: emotion)
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Robot settings")
            .padding(12)
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
            ScrollView {
            VStack(spacing: 22) {
                Picker("Emotion", selection: $emotion) {
                    ForEach(RobotEmotion.allCases) { emotion in
                        Text(emotion.rawValue).tag(emotion)
                    }
                }
                .pickerStyle(.menu)
                RobotFaceView(direction: camera.direction, emotion: emotion)
                    .frame(height: 170)
                CameraPreviewView(session: camera.session)
                    .aspectRatio(16 / 9, contentMode: .fit)
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
            .padding(.bottom, 24)
            }
            .background(.black)
            .foregroundStyle(.white)
            .navigationTitle("LEGO Robot")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingSettings = false }
                }
            }
            .preferredColorScheme(.dark)
            }
        }
        .task {
            await camera.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                UIApplication.shared.isIdleTimerDisabled = true
                Task { await camera.start() }
            } else {
                camera.stop()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onDisappear {
            camera.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

private enum RobotEmotion: String, CaseIterable, Identifiable {
    case calm = "Calm", curious = "Curious", happy = "Happy"
    case focused = "Focused", surprised = "Surprised"
    var id: String { rawValue }

    func brow(left: Bool) -> (angle: Double, lift: CGFloat) {
        switch self {
        case .calm: return (left ? -10 : 10, 0)
        case .curious: return (left ? -19 : 5, left ? -20 : 0)
        case .happy: return (left ? -14 : 14, -13)
        case .focused: return (left ? 15 : -15, 12)
        case .surprised: return (left ? -3 : 3, -25)
        }
    }
}

private struct RobotFaceView: View {
    let direction: FaceDirection
    let emotion: RobotEmotion
    @State private var blinking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 760, geometry.size.height / 330)
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(Color(white: 0.86))
                RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.13)).padding(22)
                HStack(spacing: 210) {
                    Rectangle().fill(.cyan).frame(width: 12, height: 135)
                    Rectangle().fill(.cyan).frame(width: 12, height: 135)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [.gray, .white, .gray], startPoint: .top, endPoint: .bottom))
                    .frame(width: 150, height: 30)
                HStack(spacing: 150) {
                    EyeView(offset: direction.pupilOffset, blinking: blinking, emotion: emotion)
                    EyeView(offset: direction.pupilOffset, blinking: blinking, emotion: emotion)
                }
                ForEach([true, false], id: \.self) { left in
                    let pose = emotion.brow(left: left)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.orange, Color(red: 1, green: 0.28, blue: 0)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.5), lineWidth: 1))
                        .frame(width: 240, height: 24)
                        .rotationEffect(.degrees(pose.angle))
                        .offset(x: left ? -175 : 175, y: -108 + pose.lift)
                }
                HStack(spacing: 6) {
                    ForEach(0..<5) { _ in
                        RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.9)).frame(width: 80, height: 24)
                    }
                }
                .offset(y: 137)
            }
            .frame(width: 760, height: 330)
            .scaleEffect(scale)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: emotion)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: direction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Robot face, \(emotion.rawValue), \(direction.rawValue)")
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(4))
                    guard !reduceMotion else { continue }
                    withAnimation(.easeInOut(duration: 0.1)) { blinking = true }
                    try await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeInOut(duration: 0.14)) { blinking = false }
                } catch {
                    blinking = false
                    return
                }
            }
        }
    }
}

private struct EyeView: View {
    let offset: CGFloat
    let blinking: Bool
    let emotion: RobotEmotion

    var body: some View {
        ZStack {
            Circle().fill(.black).overlay(Circle().stroke(Color(white: 0.28), lineWidth: 6))
            ZStack {
                Circle().fill(RadialGradient(colors: [.white, .cyan, Color(red: 0, green: 0.25, blue: 0.4)], center: .center, startRadius: 4, endRadius: 75))
                Circle().stroke(.cyan, lineWidth: 4)
                ForEach(0..<4) { index in
                    Circle().fill(.cyan.opacity(0.6)).overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 2))
                        .frame(width: 30, height: 30)
                        .offset(x: index % 2 == 0 ? -36 : 36, y: index < 2 ? -36 : 36)
                }
                Circle().fill(Color(white: 0.06)).frame(width: 40, height: 40)
                    .overlay(Circle().stroke(.cyan, lineWidth: 3))
                    .offset(x: offset)
                Circle().fill(.white).frame(width: 12, height: 12).offset(x: -18, y: -26)
            }
            .frame(width: 146, height: 146)
            .scaleEffect(x: 1, y: blinking ? 0.05 : emotion == .happy ? 0.75 : 1)
        }
        .frame(width: 200, height: 200)
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
