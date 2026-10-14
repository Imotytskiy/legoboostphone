import AVFoundation
import SwiftUI
import Vision
import CoreImage

final class CameraViewModel: NSObject, ObservableObject {
    @Published private(set) var permissionStatus = "Camera permission needed"
    @Published private(set) var direction: FaceDirection = .searching
    @Published private(set) var faceCenterX: CGFloat?
    @Published private(set) var faceBox: CGRect?
    @Published private(set) var streamStatus = "Disconnected"
    private let imageContext = CIContext()
    private var streamURL: URL?
    private var sendingFrame = false
    private var lastFrameTime = Date.distantPast
    private let uploadSession = URLSession(configuration: .ephemeral)

    func setStreaming(address: String?) {
        visionQueue.async {
            self.streamURL = address.flatMap { value in
                guard let url = URL(string: value), url.scheme == "http", url.host != nil else { return nil }
                return url.appendingPathComponent("frame")
            }
            let status = address == nil ? "Disconnected" : self.streamURL == nil ? "Invalid Mac address" : "Connecting"
            DispatchQueue.main.async { self.streamStatus = status }
        }
    }

    private func sendFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let url = streamURL, !sendingFrame, Date().timeIntervalSince(lastFrameTime) > 0.15,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameTime = Date()
        let source = CIImage(cvPixelBuffer: buffer)
        let scale = min(1, 640 / source.extent.width)
        let image = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let jpeg = imageContext.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else { return }
        sendingFrame = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpeg
        uploadSession.dataTask(with: request) { _, response, error in
            self.visionQueue.async { self.sendingFrame = false }
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 204
            DispatchQueue.main.async { self.streamStatus = success ? "Live" : "Mac unavailable" }
        }.resume()
    }

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "lego.robot.camera.session")
    private let visionQueue = DispatchQueue(label: "lego.robot.camera.vision")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var configured = false

    @MainActor
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionStatus = "Camera ready"
            configureAndStartSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? "Camera ready" : "Camera denied"
            if granted {
                configureAndStartSession()
            }
        case .denied, .restricted:
            permissionStatus = "Camera denied"
        @unknown default:
            permissionStatus = "Camera unavailable"
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.configured {
                self.configureSession()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.permissionStatus = "Front camera unavailable"
            }
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)

        guard session.canAddOutput(videoOutput) else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.permissionStatus = "Camera output unavailable"
            }
            session.commitConfiguration()
            return
        }

        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 0
            connection.isVideoMirrored = true
        }

        configured = true
        session.commitConfiguration()
    }

    private func detectFace(in sampleBuffer: CMSampleBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let self else { return }

            let face = (request.results as? [VNFaceObservation])?.max {
                $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
            }

            Task { @MainActor in
                self.updateFace(face)
            }
        }

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        try? handler.perform([request])
    }

    @MainActor
    private func updateFace(_ face: VNFaceObservation?) {
        guard let face else {
            faceCenterX = nil
            faceBox = nil
            direction = .searching
            return
        }

        let box = face.boundingBox
        let centerX = box.midX
        faceCenterX = centerX
        faceBox = CGRect(
            x: box.minX,
            y: 1 - box.maxY,
            width: box.width,
            height: box.height
        )

        switch centerX {
        case ..<0.42:
            direction = .left
        case 0.58...:
            direction = .right
        default:
            direction = .center
        }
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        detectFace(in: sampleBuffer)
        sendFrame(sampleBuffer)
    }
}
