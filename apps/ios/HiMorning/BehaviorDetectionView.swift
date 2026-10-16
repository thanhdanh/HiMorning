import SwiftUI
import HiMorningCore
import Vision
import CoreML
import CoreMotion
import CoreVideo

struct BehaviorDetectionView: View {
    let alarm: SavedAlarm

    @ObservedObject var model: PilotModel
    @Environment(\.dismiss) private var dismiss

    @State private var isDetecting = false
    @State private var detectionResult = ""
    @State private var errorMessage = ""

    private let motionActivityManager = CMMotionActivityManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Behavior Verification")
                .font(.headline)
                .padding(.top)

            if isDetecting {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()

                Text("Monitoring device activity...")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(detectionResult)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Stop monitoring") {
                    stopBehaviorDetection()
                }
                .buttonStyle(MorningButtonStyle(primary: false))
                .padding(.horizontal)

            } else {
                VStack(spacing: 15) {
                    Button("Start motion monitoring") {
                        startBehaviorDetection()
                    }
                    .buttonStyle(MorningButtonStyle())

                    if !detectionResult.isEmpty {
                        Text(detectionResult)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MorningTheme.canvas.ignoresSafeArea())
        .onDisappear {
            stopBehaviorDetection()
        }
    }

    // MARK: - Behavior Detection

    private func startBehaviorDetection() {
        guard !isDetecting else {
            return
        }

        guard CMMotionActivityManager.isActivityAvailable() else {
            errorMessage = "Motion activity is not available on this device."
            return
        }

        isDetecting = true
        detectionResult = "Waiting for motion activity..."
        errorMessage = ""

        motionActivityManager.startActivityUpdates(to: .main) { activity in
            guard let activity else {
                return
            }

            DispatchQueue.main.async {
                guard isDetecting else {
                    return
                }

                if activity.walking {
                    detectionResult = "Walking activity detected."
                } else if activity.running {
                    detectionResult = "Running activity detected."
                } else if activity.cycling {
                    detectionResult = "Cycling activity detected."
                } else if activity.automotive {
                    detectionResult = "Vehicle activity detected."
                } else if activity.stationary {
                    detectionResult = "Device is stationary."
                } else {
                    detectionResult = "Activity is currently unknown."
                }
            }
        }
    }

    private func stopBehaviorDetection() {
        motionActivityManager.stopActivityUpdates()
        isDetecting = false
    }

    // MARK: - Challenge Completion

    // Do not automatically complete an alarm based on motion classification.
    //
    // A future implementation should:
    // 1. Evaluate the actual challenge requirements.
    // 2. Confirm that the required movement was performed.
    // 3. Use the existing ChallengeCoordinator completion pathway.
    // 4. Handle completion failures without dismissing the alarm.
}

// MARK: - Vision Support

extension BehaviorDetectionView {

    /// Classifies the contents of a camera frame using Apple's
    /// built-in Vision image classifier.
    ///
    /// Important:
    /// Image classification does not verify physical movements
    /// such as push-ups or jumping jacks.
    func analyzeWithVision(
        _ pixelBuffer: CVPixelBuffer
    ) async throws -> [VNClassificationObservation] {

        let request = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            options: [:]
        )

        try handler.perform([request])

        return request.results ?? []
    }

    /// Placeholder for future custom Core ML gesture recognition.
    ///
    /// A trained model must be supplied before this method can
    /// perform meaningful gesture classification.
    func analyzeWithCoreML(
        _ data: MLMultiArray
    ) async throws -> [String] {
        return []
    }
}

// MARK: - Preview

struct BehaviorDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        BehaviorDetectionView(
            alarm: SavedAlarm(
                id: UUID(),
                time: try! AlarmTime(
                    hour: 7,
                    minute: 0,
                    weekdays: []
                ),
                mode: .balanced,
                sound: .sunrise,
                challenge: .guidedRhythm(variant: .seated)
            ),
            model: PilotModel()
        )
    }
}