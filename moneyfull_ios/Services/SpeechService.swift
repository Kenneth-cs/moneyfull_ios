import Speech
import AVFoundation

class SpeechService: ObservableObject {
    static let shared = SpeechService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        ?? SFSpeechRecognizer()
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
    private var wantsRecording = false
    private var onStopCompletion: (() -> Void)?
    private var stopTimeoutWork: DispatchWorkItem?
    private var tapInstalled = false
    private var consecutiveRecognitionErrors = 0

    /// flushing: 松手后仍继续喂音频，让识别跟上最后几个字
    /// waitingFinal: 已 endAudio，等最终结果
    private enum StopPhase { case idle, flushing, waitingFinal }
    private var stopPhase: StopPhase = .idle

    /// 每次 start/cancel 更换；stop 过程中保持不变，否则会丢掉最后几段识别结果。
    private var sessionID = UUID()
    private var recognitionGeneration = 0

    private init() {}

    func requestPermission() async -> Bool {
        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
        guard micAuthorized else { return false }

        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return speechAuthorized
    }

    func startRecording() async throws {
        let session = UUID()
        let started: Bool = try await runOnMainThrowing {
            self.sessionID = session
            self.wantsRecording = true
            self.stopTimeoutWork?.cancel()
            self.stopTimeoutWork = nil
            self.isStopping = false
            self.stopPhase = .idle
            self.onStopCompletion = nil
            self.consecutiveRecognitionErrors = 0
            self.teardownEngine(endRecognition: true)
            self.accumulatedText = ""
            self.transcribedText = ""
            self.lastTextUpdateTime = Date()
            self.error = nil

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            return self.sessionID == session
        }
        guard started else { return }

        // 首次授权或过热降频时，inputNode 可能短暂给出 sampleRate=0。
        // installTap 对无效格式会抛 NSException（do-catch 拦不住），必须先校验并重试。
        var lastError: Error?
        for _ in 0..<8 {
            let stillCurrent = await runOnMain { self.sessionID == session && self.wantsRecording }
            guard stillCurrent else { return }

            do {
                try await runOnMainThrowing {
                    guard self.sessionID == session, self.wantsRecording else { return }
                    try self.installTapAndStartEngine()
                }
                lastError = nil
                break
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 80_000_000)
            }
        }

        if let lastError {
            await runOnMain {
                guard self.sessionID == session else { return }
                self.teardownEngine(endRecognition: true)
                self.publishRecording(false)
            }
            throw lastError
        }

        let armed = await runOnMain { () -> Bool in
            guard self.sessionID == session, self.wantsRecording else {
                if !self.isStopping {
                    self.teardownEngine(endRecognition: true)
                }
                return false
            }
            self.publishRecording(true)
            self.startSilenceMonitor()
            return true
        }
        guard armed else { return }
    }

    func stopRecording(completion: (() -> Void)? = nil) {
        let work = {
            self.wantsRecording = false
            self.silenceTimer?.invalidate()
            self.silenceTimer = nil
            self.onStopCompletion = completion
            self.isStopping = true
            self.publishRecording(false)

            // 引擎还没起来（按住瞬间就松开）：没有可冲刷的尾音。
            guard self.tapInstalled || self.recognitionRequest != nil else {
                self.stopPhase = .idle
                self.finishStopping()
                return
            }

            // 松手后继续录一小段。语音识别有 300~600ms 滞后，
            // 立刻停引擎会丢掉最后一两个字。
            self.stopPhase = .flushing
            self.stopTimeoutWork?.cancel()
            let endAudioWork = DispatchWorkItem { [weak self] in
                self?.endAudioAndWaitForFinal()
            }
            self.stopTimeoutWork = endAudioWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: endAudioWork)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func cancelRecording() {
        let work = {
            self.wantsRecording = false
            self.sessionID = UUID()
            self.stopTimeoutWork?.cancel()
            self.stopTimeoutWork = nil
            self.isStopping = false
            self.stopPhase = .idle
            self.onStopCompletion = nil
            self.silenceTimer?.invalidate()
            self.silenceTimer = nil
            self.teardownEngine(endRecognition: true)
            self.accumulatedText = ""
            self.transcribedText = ""
            self.publishRecording(false)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    // MARK: - Engine

    private func installTapAndStartEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw NSError(
                domain: "SpeechService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "音频格式未就绪（sampleRate=\(recordingFormat.sampleRate)）"]
            )
        }

        // 先建识别请求，再装 tap，否则开头几帧音频会 append 到 nil。
        if recognitionRequest == nil {
            startNewRecognitionTask(force: true)
        }

        // 重复 installTap 会抛无法捕获的 NSException。先摘掉旧 tap 再装。
        removeTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            removeTapIfNeeded()
            throw error
        }
    }

    private func teardownEngine(endRecognition: Bool) {
        audioEngineStopAndRemoveTap()
        if endRecognition {
            recognitionGeneration += 1
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
        }
    }

    private func audioEngineStopAndRemoveTap() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfNeeded()
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private func publishRecording(_ recording: Bool) {
        if Thread.isMainThread {
            isRecording = recording
        } else {
            DispatchQueue.main.async { self.isRecording = recording }
        }
    }

    // MARK: - Recognition

    private func startNewRecognitionTask(force: Bool = false) {
        let canRun = force || (isRecording && !isStopping) || stopPhase == .flushing
        guard canRun else { return }
        guard speechRecognizer?.isAvailable == true else { return }

        recognitionGeneration += 1
        let generation = recognitionGeneration
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request
        let session = sessionID

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.recognitionGeneration,
                      session == self.sessionID else { return }
                self.handleRecognitionResult(result: result, error: error, session: session)
            }
        }
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?, session: UUID) {
        guard session == sessionID else { return }

        if let result {
            consecutiveRecognitionErrors = 0
            let currentSegment = result.bestTranscription.formattedString
            let fullText = accumulatedText.isEmpty ? currentSegment : accumulatedText + currentSegment
            transcribedText = fullText
            lastTextUpdateTime = Date()

            if result.isFinal {
                accumulatedText = fullText
                if stopPhase == .waitingFinal {
                    finishStopping()
                    return
                }
                // 冲刷尾音期间的分段结束：开下一段继续收最后几个字，不要立刻收工。
                recognitionTask = nil
                startNewRecognitionTask()
                return
            }
        }

        if let error {
            if stopPhase == .waitingFinal {
                finishStopping()
                return
            }

            let nsError = error as NSError
            let cancelled = nsError.code == 1 || nsError.code == 216
            recognitionRequest = nil
            recognitionTask = nil

            let canRestart = (isRecording && !isStopping) || stopPhase == .flushing
            guard canRestart, !cancelled else { return }

            consecutiveRecognitionErrors += 1
            guard consecutiveRecognitionErrors <= 5 else {
                self.error = error.localizedDescription
                return
            }

            let delay = 0.15 * Double(consecutiveRecognitionErrors)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.sessionID == session else { return }
                let canRestart = (self.isRecording && !self.isStopping) || self.stopPhase == .flushing
                guard canRestart else { return }
                self.startNewRecognitionTask()
            }
        }
    }

    private func endAudioAndWaitForFinal() {
        guard isStopping, stopPhase == .flushing else { return }
        stopPhase = .waitingFinal
        recognitionRequest?.endAudio()
        audioEngineStopAndRemoveTap()

        let timeout = DispatchWorkItem { [weak self] in
            self?.finishStopping()
        }
        stopTimeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: timeout)
    }

    private func finishStopping() {
        guard isStopping || onStopCompletion != nil else { return }
        stopTimeoutWork?.cancel()
        stopTimeoutWork = nil

        if !transcribedText.isEmpty {
            accumulatedText = transcribedText
        } else if !accumulatedText.isEmpty {
            transcribedText = accumulatedText
        }

        let completion = onStopCompletion
        onStopCompletion = nil
        isStopping = false
        stopPhase = .idle
        wantsRecording = false
        recognitionGeneration += 1
        audioEngineStopAndRemoveTap()
        recognitionRequest = nil
        recognitionTask = nil

        DispatchQueue.main.async {
            completion?()
        }
    }

    private func startSilenceMonitor() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isRecording, let lastUpdate = self.lastTextUpdateTime else { return }
            if Date().timeIntervalSince(lastUpdate) >= self.silenceTimeout {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
    }

    // MARK: - Thread hop

    private func runOnMain<T>(_ work: @escaping () -> T) async -> T {
        if Thread.isMainThread { return work() }
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume(returning: work())
            }
        }
    }

    private func runOnMainThrowing<T>(_ work: @escaping () throws -> T) async throws -> T {
        if Thread.isMainThread { return try work() }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
