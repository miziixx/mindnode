import UIKit
import Flutter
import AVFoundation

// MARK: - 마인드사운드 iOS 오디오 엔진
//
// 이 파일 하나에 AppDelegate + 오디오 엔진 + DSP를 모두 담는다(Xcode 프로젝트에
// 파일을 추가하지 않고 CI에서 빌드되도록). DSP는 Python 검증 코어 및 Dart/Kotlin과
// 동일한 알고리즘·상수(v1)를 사용한다.
//
// - AVAudioSourceNode: 실시간 주파수/드론/바이노럴/펄스 생성(렌더 블록)
// - AVAudioPlayerNode: 자연음/패드/차임 PCM 재생
// - AVAudioMixerNode: 믹싱 / AVAudioSession: 백그라운드·경로 관리
//
// ⚠️ 이 iOS 구현은 현재 개발 환경(리눅스)에서 빌드/실행 검증하지 못했다.

// MARK: DSP 상수/유틸
enum Dsp {
    static let twoPi = 2.0 * Double.pi
    static func dbToLin(_ db: Double) -> Double { pow(10.0, db / 20.0) }
    static let limiterCeil = dbToLin(-1.0)
}

struct Ramp {
    var current: Double
    var target: Double
    var step: Double = 0
    init(_ v: Double) { current = v; target = v }
    mutating func setTarget(_ v: Double, _ sr: Double, _ ms: Double) {
        target = v
        let n = max(1.0, sr * ms / 1000.0)
        step = (target - current) / n
    }
    mutating func snap(_ v: Double) { current = v; target = v; step = 0 }
    mutating func next() -> Double {
        if step == 0 { return current }
        current += step
        if (step > 0 && current >= target) || (step < 0 && current <= target) {
            current = target; step = 0
        }
        return current
    }
}

struct ToneP { var enabled = false; var freq = 528.0; var gainDb = -26.0; var pan = 0.0 }
struct DroneP { var enabled = false; var center = 528.0; var gainDb = -24.0; var movement = 0.05
    var width = 0.25; var sub = 0.35; var main = 0.55; var air = 0.10 }
struct BinP { var enabled = false; var carrier = 220.0; var beat = 10.0; var invert = false; var gainDb = -30.0 }
struct PulseP { var enabled = false; var freq = 432.0; var rate = 7.83; var depth = 0.2; var alternate = false; var gainDb = -30.0 }

struct StageP {
    var title = ""
    var durationSec = 0
    var primary = ToneP()
    var secondary = ToneP(enabled: false, freq: 741, gainDb: -34, pan: 0)
    var drone = DroneP()
    var binaural = BinP()
    var pulse = PulseP()
    var natureKey: String? = nil
    var padKey: String? = nil
    var chimeKey: String? = nil
    var chimeIntervalSec = 0
    var transitionSec = 1.5
}

// MARK: 엔진
final class MindSoundEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private let naturePlayer = AVAudioPlayerNode()
    private let padPlayer = AVAudioPlayerNode()
    private let chimePlayer = AVAudioPlayerNode()
    private var sampleRate: Double = 48000
    private let onEvent: ([String: Any]) -> Void

    // 렌더 스레드 소유 위상
    private var primaryPhase = 0.0, secondaryPhase = 0.0
    private var subLP = 0.0, subRP = 0.3, mainLP = 1.1, mainRP = 1.4, airLP = 2.2, airRP = 2.5
    private var lfoLP = 0.0, lfoRP = Double.pi / 2
    private var binLP = 0.0, binRP = 0.0
    private var pulseCarrierP = 0.0, pulseModP = 0.0

    private var primaryFreq = Ramp(528), secondaryFreq = Ramp(741)
    private var masterGain = Ramp(0), primaryGain = Ramp(0), secondaryGain = Ramp(0)
    private var droneGain = Ramp(0), binauralGain = Ramp(0), pulseGain = Ramp(0)

    // 파라미터 스냅샷(락으로 갱신, 렌더에서 trylock 복사)
    private let lock = NSLock()
    private var snapshot = StageP()
    private var renderStage = StageP()

    private var stages: [StageP] = []
    private var stageIndex = 0
    private var totalDurationSec = 0
    private var startFadeMs = 3000.0
    private var endFadeMs = 10000.0
    private var framesRendered: Int64 = 0
    private var stageStartFrame: Int64 = 0
    private var stopRequested = false
    private var paused = false

    init(onEvent: @escaping ([String: Any]) -> Void) {
        self.onEvent = onEvent
    }

    func initialize() {
        configureSession()
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate <= 0 { sampleRate = 48000 }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            self?.render(frameCount, abl)
            return noErr
        }
        engine.attach(sourceNode)
        engine.attach(naturePlayer)
        engine.attach(padPlayer)
        engine.attach(chimePlayer)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.connect(naturePlayer, to: engine.mainMixerNode, format: format)
        engine.connect(padPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(chimePlayer, to: engine.mainMixerNode, format: format)
        registerNotifications()
        onEvent(["type": "engineReady", "sampleRate": sampleRate])
    }

    private func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [])
        try? s.setActive(true)
    }

    // MARK: 렌더 블록(실시간, 할당/락 대기 없음)
    private func render(_ frameCount: AVAudioFrameCount, _ abl: UnsafeMutablePointer<AudioBufferList>) {
        let ablp = UnsafeMutableAudioBufferListPointer(abl)
        let left = ablp[0].mData!.assumingMemoryBound(to: Float.self)
        let right = ablp.count > 1 ? ablp[1].mData!.assumingMemoryBound(to: Float.self) : left
        // 스냅샷 복사(trylock; 실패 시 이전 값 유지)
        if lock.try() {
            renderStage = snapshot
            lock.unlock()
        }
        let s = renderStage
        let sr = sampleRate
        let n = Int(frameCount)
        for i in 0..<n {
            var l = 0.0, r = 0.0
            var active = 0
            // primary
            let pg = primaryGain.next(); let pf = primaryFreq.next()
            let pv = sin(primaryPhase); advance(&primaryPhase, pf, sr)
            if pg > 1e-6 {
                let a = (s.primary.pan + 1) / 2 * Double.pi / 2
                l += pv * pg * cos(a); r += pv * pg * sin(a); active += 1
            }
            // secondary
            let sg = secondaryGain.next(); let sf = secondaryFreq.next()
            let sv = sin(secondaryPhase); advance(&secondaryPhase, sf, sr)
            if sg > 1e-6 { l += sv * sg; r += sv * sg; active += 1 }
            // drone
            let dg = droneGain.next()
            if dg > 1e-6 {
                let ll = 0.925 + 0.075 * sin(lfoLP); advance(&lfoLP, s.drone.movement, sr)
                let lr = 0.925 + 0.075 * sin(lfoRP); advance(&lfoRP, s.drone.movement, sr)
                let nyq = sr * 0.5; let airHz = s.drone.center * 2; let airOn = airHz < nyq * 0.98
                var dl = s.drone.sub * sin(subLP); var dr = s.drone.sub * sin(subRP)
                advance(&subLP, s.drone.center * 0.5, sr); advance(&subRP, s.drone.center * 0.5, sr)
                dl += s.drone.main * sin(mainLP); dr += s.drone.main * sin(mainRP)
                advance(&mainLP, s.drone.center, sr); advance(&mainRP, s.drone.center, sr)
                if airOn {
                    dl += s.drone.air * sin(airLP); dr += s.drone.air * sin(airRP)
                    advance(&airLP, airHz, sr); advance(&airRP, airHz, sr)
                }
                dl *= ll * dg; dr *= lr * dg
                let mid = 0.5 * (dl + dr); let side = 0.5 * (dl - dr) * (1 + s.drone.width)
                l += mid + side; r += mid - side; active += 1
            }
            // binaural
            let bg = binauralGain.next()
            if bg > 1e-6 {
                let lhz = s.binaural.invert ? s.binaural.carrier + s.binaural.beat : s.binaural.carrier
                let rhz = s.binaural.invert ? s.binaural.carrier : s.binaural.carrier + s.binaural.beat
                l += sin(binLP) * bg; r += sin(binRP) * bg
                advance(&binLP, lhz, sr); advance(&binRP, rhz, sr); active += 1
            }
            // pulse
            let plg = pulseGain.next()
            if plg > 1e-6 {
                let c = sin(pulseCarrierP); advance(&pulseCarrierP, s.pulse.freq, sr)
                let envL = (1 - s.pulse.depth) + s.pulse.depth * (0.5 + 0.5 * cos(pulseModP))
                let envR = s.pulse.alternate ? (1 - s.pulse.depth) + s.pulse.depth * (0.5 + 0.5 * cos(pulseModP + Double.pi)) : envL
                advance(&pulseModP, s.pulse.rate, sr)
                l += c * envL * plg; r += c * envR * plg; active += 1
            }
            let hs = active <= 1 ? 1.0 : 1.0 / sqrt(Double(active))
            let m = masterGain.next()
            left[i] = Float(softLimit(l * hs * m))
            right[i] = Float(softLimit(r * hs * m))
        }
        framesRendered += Int64(n)
    }

    private func advance(_ phase: inout Double, _ f: Double, _ sr: Double) {
        phase += Dsp.twoPi * f / sr
        if phase >= Dsp.twoPi { phase -= Dsp.twoPi } else if phase < 0 { phase += Dsp.twoPi }
    }

    private func softLimit(_ x: Double) -> Double {
        var v = x
        if v.isNaN || v.isInfinite { v = 0 }
        let c = Dsp.limiterCeil
        let y = c * tanh(v / c)
        return min(c, max(-c, y))
    }

    // MARK: 명령
    func loadPreset(_ preset: [String: Any], assetPaths: [String: String],
                    startFadeMs: Int, endFadeMs: Int, master: Double) {
        self.startFadeMs = Double(startFadeMs)
        self.endFadeMs = Double(endFadeMs)
        masterTarget = master
        stages = (preset["stages"] as? [[String: Any]])?.map { parseStage($0, assetPaths) } ?? []
        totalDurationSec = stages.reduce(0) { $0 + $1.durationSec }
        stageIndex = 0
        if let first = stages.first { applyStage(first, instant: true) }
        onEvent(["type": "playbackStateChanged", "state": "ready"])
    }

    private var masterTarget = 0.15
    func start() {
        if !engine.isRunning { try? engine.start() }
        naturePlayer.play(); padPlayer.play(); chimePlayer.play()
        masterGain.snap(0)
        masterGain.setTarget(masterTarget, sampleRate, startFadeMs)
        stopRequested = false; paused = false
        framesRendered = 0; stageStartFrame = 0
        loadStageAssets(0)
        startTimer()
        onEvent(["type": "playbackStateChanged", "state": "playing"])
    }
    func pause() { paused = true; onEvent(["type": "playbackStateChanged", "state": "paused"]) }
    func resume() { paused = false; onEvent(["type": "playbackStateChanged", "state": "playing"]) }
    func stop(graceful: Bool) {
        if graceful { masterGain.setTarget(0, sampleRate, endFadeMs); stopRequested = true }
        else { finish(completed: false) }
    }
    func seekToStage(_ i: Int) { changeStage(min(max(0, i), stages.count - 1)) }
    func nextStage() { if stageIndex < stages.count - 1 { changeStage(stageIndex + 1) } }
    func previousStage() { if stageIndex > 0 { changeStage(stageIndex - 1) } }
    func setMasterGain(_ g: Double) { masterTarget = g; masterGain.setTarget(g, sampleRate, 30) }
    func setFrequency(_ hz: Double) { primaryFreq.setTarget(hz, sampleRate, 30) }
    func setSecondaryFrequency(_ hz: Double) { secondaryFreq.setTarget(hz, sampleRate, 30) }
    func setLayerEnabled(_ id: String, _ enabled: Bool) {
        let g = enabled ? gain(for: id, snapshot) : 0
        setRampTarget(id, g, 100)
    }
    func setLayerGain(_ id: String, _ db: Double) {
        setRampTarget(id, Dsp.dbToLin(db), 30)
    }
    func dispose() { timer?.invalidate(); engine.stop() }

    private func setRampTarget(_ id: String, _ value: Double, _ ms: Double) {
        switch id {
        case "primary": primaryGain.setTarget(value, sampleRate, ms)
        case "secondary": secondaryGain.setTarget(value, sampleRate, ms)
        case "drone": droneGain.setTarget(value, sampleRate, ms)
        case "binaural": binauralGain.setTarget(value, sampleRate, ms)
        case "pulse": pulseGain.setTarget(value, sampleRate, ms)
        default: break
        }
    }
    private func gain(for id: String, _ s: StageP) -> Double {
        switch id {
        case "primary": return s.primary.enabled ? Dsp.dbToLin(s.primary.gainDb) : 0
        case "secondary": return s.secondary.enabled ? Dsp.dbToLin(s.secondary.gainDb) : 0
        case "drone": return s.drone.enabled ? Dsp.dbToLin(s.drone.gainDb) : 0
        case "binaural": return s.binaural.enabled ? Dsp.dbToLin(s.binaural.gainDb) : 0
        case "pulse": return s.pulse.enabled ? Dsp.dbToLin(s.pulse.gainDb) : 0
        default: return 0
        }
    }

    private func applyStage(_ s: StageP, instant: Bool) {
        lock.lock(); snapshot = s; lock.unlock()
        let ms = instant ? 0 : s.transitionSec * 1000
        if instant {
            primaryFreq.snap(s.primary.freq); secondaryFreq.snap(s.secondary.freq)
            primaryGain.snap(gain(for: "primary", s)); secondaryGain.snap(gain(for: "secondary", s))
            droneGain.snap(gain(for: "drone", s)); binauralGain.snap(gain(for: "binaural", s))
            pulseGain.snap(gain(for: "pulse", s))
        } else {
            primaryFreq.setTarget(s.primary.freq, sampleRate, ms)
            secondaryFreq.setTarget(s.secondary.freq, sampleRate, ms)
            primaryGain.setTarget(gain(for: "primary", s), sampleRate, ms)
            secondaryGain.setTarget(gain(for: "secondary", s), sampleRate, ms)
            droneGain.setTarget(gain(for: "drone", s), sampleRate, ms)
            binauralGain.setTarget(gain(for: "binaural", s), sampleRate, ms)
            pulseGain.setTarget(gain(for: "pulse", s), sampleRate, ms)
        }
    }

    private func changeStage(_ i: Int) {
        stageIndex = i; stageStartFrame = framesRendered
        guard let s = stages[safe: i] else { return }
        applyStage(s, instant: false)
        loadStageAssets(i)
        onEvent(["type": "currentStageChanged", "stageIndex": i, "stageCount": stages.count,
                 "frequencyHz": displayFreq(s) as Any, "title": s.title])
    }

    // MARK: 자산
    private func loadStageAssets(_ i: Int) {
        guard let s = stages[safe: i] else { return }
        scheduleLoop(naturePlayer, key: s.natureKey)
        scheduleLoop(padPlayer, key: s.padKey)
    }
    private func scheduleLoop(_ node: AVAudioPlayerNode, key: String?) {
        node.stop()
        guard let key = key, let buf = loadBuffer(key) else { return }
        node.scheduleBuffer(buf, at: nil, options: .loops, completionHandler: nil)
        node.play()
    }
    func triggerChime(_ key: String?) {
        guard let key = key, let buf = loadBuffer(key) else { return }
        chimePlayer.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        chimePlayer.play()
    }
    private func loadBuffer(_ assetKey: String) -> AVAudioPCMBuffer? {
        let lookup = FlutterDartProject.lookupKey(forAsset: assetKey)
        guard let path = Bundle.main.path(forResource: lookup, ofType: nil) else { return nil }
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return nil }
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                         frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        try? file.read(into: buf)
        return buf
    }

    // MARK: 타이머/이벤트
    private var timer: Timer?
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    private func tick() {
        if stopRequested && masterGain.current <= 1e-5 { finish(completed: false); return }
        let elapsed = elapsedTotalSec()
        let remaining = max(0, totalDurationSec - elapsed)
        onEvent(["type": "remainingTimeChanged", "remainingSec": remaining, "totalSec": totalDurationSec])
        let frac = totalDurationSec > 0 ? Double(elapsed) / Double(totalDurationSec) : 0
        onEvent(["type": "progressChanged", "fraction": min(1, max(0, frac))])
        if let s = stages[safe: stageIndex] {
            let stageElapsed = Int((framesRendered - stageStartFrame) / Int64(sampleRate))
            if s.durationSec > 0 && stageElapsed >= s.durationSec {
                if stageIndex < stages.count - 1 { changeStage(stageIndex + 1) }
                else if !stopRequested { stop(graceful: true) }
            }
        }
    }
    private func elapsedTotalSec() -> Int {
        var acc = 0
        for i in 0..<stageIndex where i < stages.count { acc += stages[i].durationSec }
        acc += Int((framesRendered - stageStartFrame) / Int64(sampleRate))
        return acc
    }
    private func finish(completed: Bool) {
        timer?.invalidate()
        naturePlayer.stop(); padPlayer.stop(); chimePlayer.stop()
        onEvent(["type": "playbackStateChanged", "state": "idle"])
        if completed { onEvent(["type": "sessionCompleted"]) }
    }
    private func displayFreq(_ s: StageP) -> Double? {
        if s.primary.enabled { return s.primary.freq }
        if s.drone.enabled { return s.drone.center }
        if s.pulse.enabled { return s.pulse.freq }
        if s.binaural.enabled { return s.binaural.carrier }
        return nil
    }

    // MARK: 인터럽션/경로
    private func registerNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .began { self?.pause(); self?.onEvent(["type": "interruptionChanged", "began": true]) }
            else { self?.onEvent(["type": "interruptionChanged", "began": false]) }
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            if reason == .oldDeviceUnavailable {
                self?.pause()
                self?.onEvent(["type": "routeChanged", "reason": "oldDeviceUnavailable", "headphonesConnected": false])
            }
        }
    }

    // MARK: 파싱
    private func parseStage(_ m: [String: Any], _ assets: [String: String]) -> StageP {
        var s = StageP()
        s.title = m["title"] as? String ?? ""
        s.durationSec = m["durationSec"] as? Int ?? 600
        s.transitionSec = (m["transitionDurationSec"] as? NSNumber)?.doubleValue ?? 1.5
        if let p = m["primaryTone"] as? [String: Any] { s.primary = tone(p, -26) }
        if let p = m["secondaryTone"] as? [String: Any] { s.secondary = tone(p, -34) }
        if let d = m["drone"] as? [String: Any] {
            s.drone = DroneP(enabled: d["enabled"] as? Bool ?? false,
                             center: num(d["centerHz"], 528), gainDb: num(d["gainDb"], -24),
                             movement: num(d["movementRateHz"], 0.05), width: num(d["stereoWidth"], 0.25),
                             sub: num(d["subVoiceRatio"], 0.35), main: num(d["mainVoiceRatio"], 0.55),
                             air: num(d["airVoiceRatio"], 0.10))
        }
        if let b = m["binaural"] as? [String: Any] {
            s.binaural = BinP(enabled: b["enabled"] as? Bool ?? false, carrier: num(b["carrierHz"], 220),
                              beat: num(b["beatHz"], 10), invert: b["invert"] as? Bool ?? false,
                              gainDb: num(b["gainDb"], -30))
        }
        if let p = m["pulse"] as? [String: Any] {
            s.pulse = PulseP(enabled: p["enabled"] as? Bool ?? false, freq: num(p["frequencyHz"], 432),
                             rate: num(p["rateHz"], 7.83), depth: num(p["depth"], 0.2),
                             alternate: (p["stereoMode"] as? String) == "alternate", gainDb: num(p["gainDb"], -30))
        }
        s.natureKey = assets[m["natureAssetId"] as? String ?? ""]
        s.padKey = assets[m["padAssetId"] as? String ?? ""]
        s.chimeKey = assets[m["chimeAssetId"] as? String ?? ""]
        s.chimeIntervalSec = m["chimeIntervalSec"] as? Int ?? 0
        return s
    }
    private func tone(_ m: [String: Any], _ def: Double) -> ToneP {
        ToneP(enabled: m["enabled"] as? Bool ?? false, freq: num(m["frequencyHz"], 528),
              gainDb: num(m["gainDb"], def), pan: num(m["pan"], 0))
    }
    private func num(_ v: Any?, _ def: Double) -> Double { (v as? NSNumber)?.doubleValue ?? def }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - AppDelegate
@main
@objc class AppDelegate: FlutterAppDelegate {
    private var mindEngine: MindSoundEngine!
    private var eventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let method = FlutterMethodChannel(name: "com.mindsound.app/audio",
                                          binaryMessenger: controller.binaryMessenger)
        let events = FlutterEventChannel(name: "com.mindsound.app/audio_events",
                                         binaryMessenger: controller.binaryMessenger)
        events.setStreamHandler(StreamHandler { [weak self] sink in self?.eventSink = sink })

        mindEngine = MindSoundEngine { [weak self] map in
            DispatchQueue.main.async { self?.eventSink?(map) }
        }

        method.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handle(_ call: FlutterMethodCall, _ result: FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "initialize": mindEngine.initialize()
        case "loadPreset":
            mindEngine.loadPreset(a["preset"] as? [String: Any] ?? [:],
                                  assetPaths: a["assetPaths"] as? [String: String] ?? [:],
                                  startFadeMs: a["startFadeMs"] as? Int ?? 3000,
                                  endFadeMs: a["endFadeMs"] as? Int ?? 10000,
                                  master: (a["masterGain01"] as? NSNumber)?.doubleValue ?? 0.15)
        case "start": mindEngine.start()
        case "pause": mindEngine.pause()
        case "resume": mindEngine.resume()
        case "stop": mindEngine.stop(graceful: a["graceful"] as? Bool ?? true)
        case "seekToStage": mindEngine.seekToStage(a["index"] as? Int ?? 0)
        case "nextStage": mindEngine.nextStage()
        case "previousStage": mindEngine.previousStage()
        case "setMasterGain": mindEngine.setMasterGain((a["gain01"] as? NSNumber)?.doubleValue ?? 0.15)
        case "setFrequency": mindEngine.setFrequency((a["hz"] as? NSNumber)?.doubleValue ?? 440)
        case "setSecondaryFrequency": mindEngine.setSecondaryFrequency((a["hz"] as? NSNumber)?.doubleValue ?? 440)
        case "setLayerEnabled": mindEngine.setLayerEnabled(a["layerId"] as? String ?? "", a["enabled"] as? Bool ?? true)
        case "setLayerGain": mindEngine.setLayerGain(a["layerId"] as? String ?? "", (a["gainDb"] as? NSNumber)?.doubleValue ?? -24)
        case "triggerChime": mindEngine.triggerChime(a["assetPath"] as? String)
        case "dispose": mindEngine.dispose()
        default: break
        }
        result(nil)
    }
}

final class StreamHandler: NSObject, FlutterStreamHandler {
    private let onListen: (@escaping FlutterEventSink) -> Void
    init(_ onListen: @escaping (@escaping FlutterEventSink) -> Void) { self.onListen = onListen }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListen(events); return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}
