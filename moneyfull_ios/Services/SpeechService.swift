import Speech
import AVFoundation

class SpeechService: ObservableObject {
    static let shared = SpeechService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var error: String?

    private var accumulatedText = ""
    private var silenceTimer: Timer?
    private var lastTextUpdateTime: Date?
    private let silenceTimeout: TimeInterval = 5
    private var isStopping = false
    private var onStopCompletion: (() -> Void)?

    private init() {}

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        accumulatedText = ""
        lastTextUpdateTime = Date()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.startNewRecognitionTask(inputNode: inputNode)
            self.startSilenceMonitor()
        }
    }

    private func startNewRecognitionTask(inputNode: AVAudioInputNode) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error, inputNode: inputNode)
        }
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?, inputNode: AVAudioInputNode) {
        if let result = result {
            let currentSegment = result.bestTranscription.formattedString
            let fullText = self.accumulatedText.isEmpty ? currentSegment : self.accumulatedText + currentSegment

            DispatchQueue.main.async {
                self.transcribedText = fullText
            }
            self.lastTextUpdateTime = Date()

            if result.isFinal {
                self.accumulatedText = fullText

                if self.isStopping {
                    self.finishStopping()
                    return
                }

                self.recognitionTask?.cancel()
                self.recognitionTask = nil

                let newRequest = SFSpeechAudioBufferRecognitionRequest()
                newRequest.shouldReportPartialResults = true
                self.recognitionRequest = newRequest

                self.recognitionTask = self.speechRecognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
                    self?.handleRecognitionResult(result: result, error: error, inputNode: inputNode)
                }
            }
        }

        if error != nil {
            if self.isStopping {
                self.finishStopping()
                return
            }

            self.recognitionRequest = nil
            self.recognitionTask = nil

            if self.isRecording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self, self.isRecording else { return }
                    self.startNewRecognitionTask(inputNode: inputNode)
                }
            }
        }
    }

    private func finishStopping() {
        isStopping = false
        recognitionRequest = nil
        recognitionTask = nil

        if !transcribedText.isEmpty {
            accumulatedText = transcribedText
        }

        DispatchQueue.main.async {
            self.transcribedText = self.accumulatedText
            self.onStopCompletion?()
            self.onStopCompletion = nil
        }
    }

    private func startSilenceMonitor() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isRecording, let lastUpdate = self.lastTextUpdateTime else { return }

            let elapsed = Date().timeIntervalSince(lastUpdate)
            if elapsed >= self.silenceTimeout {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording(completion: (() -> Void)? = nil) {
        guard isRecording else { return }

        onStopCompletion = completion
        isRecording = false
        isStopping = true
        silenceTimer?.invalidate()
        silenceTimer = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.recognitionRequest?.endAudio()
        }
    }

    func cancelRecording() {
        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        accumulatedText = ""
        transcribedText = ""
    }
}
