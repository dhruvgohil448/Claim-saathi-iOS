import SwiftUI
import AVFoundation
import Speech

// MARK: - AI Claim Copilot models

struct RiskFlag: Decodable, Hashable { var code: String; var severity: String?; var message: String?; var messageHi: String? }
struct PredDeduction: Decodable, Hashable { var label: String; var amount: Double?; var reason: String?; var reasonHi: String?; var clause: String? }
struct Prediction: Decodable {
    var claimId: String?; var predictedPayout: Double?; var billAmount: Double?; var totalDeductions: Double?
    var confidence: Double?; var confidenceLabel: String?; var basis: String?; var headline: String?; var headlineHi: String?
    var deductions: [PredDeduction]?; var rejectionRisk: String?; var riskFlags: [RiskFlag]?; var tips: [String]?
}
struct BillLine: Decodable, Hashable { var description: String; var amount: Double?; var payableAmount: Double?; var deduction: Double?; var status: String?; var reason: String?; var reasonHi: String? }
struct BillTotals: Decodable { var billed: Double?; var payableBeforeCoPay: Double?; var nonPayable: Double?; var proportionateCut: Double?; var coPay: Double?; var finalPayable: Double? }
struct BillAnalysis: Decodable { var available: Bool; var message: String?; var messageHi: String?; var items: [BillLine]?; var totals: BillTotals?; var summary: String?; var summaryHi: String? }
struct VoiceStatus: Decodable { var sarvam: Bool? }
struct SttBody: Encodable { var audioBase64: String; var mimeType: String; var lang: String? }
struct SttResult: Decodable { var text: String? }
struct TtsBody: Encodable { var text: String; var lang: String? }
struct TtsResult: Decodable { var audioBase64: String? }
struct ChatLangBody: Encodable { var message: String; var claimId: String?; var lang: String? }

extension API {
    func prediction(_ claimId: String) async throws -> Prediction { try await request("claims/\(claimId)/prediction") }
    func billAnalysis(_ claimId: String) async throws -> BillAnalysis { try await request("claims/\(claimId)/bill-analysis") }
    func voiceStatus() async throws -> VoiceStatus { try await request("ai/voice/status") }
    func stt(_ base64: String, lang: String?) async throws -> SttResult { try await request("ai/voice/stt", method: "POST", json: SttBody(audioBase64: base64, mimeType: "audio/mp4", lang: lang)) }
    func tts(_ text: String, lang: String?) async throws -> TtsResult { try await request("ai/voice/tts", method: "POST", json: TtsBody(text: text, lang: lang)) }
    func chat(_ message: String, claimId: String?, lang: String?) async throws -> ChatReply { try await request("ai/chat", method: "POST", json: ChatLangBody(message: message, claimId: claimId, lang: lang)) }
    func chatSuggestions(lang: String?) async throws -> ChatSuggestions { try await request("ai/suggestions", query: ["lang": lang]) }
}

private func riskTint(_ s: String?) -> Color { s == "high" ? .csError : s == "medium" ? .csWarning : .csSecondary }

private struct LangPill: View {
    @Binding var hindi: Bool
    var body: some View {
        Button(hindi ? "EN" : "हिं") { hindi.toggle() }
            .font(.caption.bold()).foregroundStyle(Color.csNavy).padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color.csPale).clipShape(Capsule()).buttonStyle(.plain)
    }
}

// MARK: - "Saathi predicts" card

struct PredictionCard: View {
    let claimId: String
    var refreshKey: String = ""
    @State private var p: Prediction?
    @State private var open = false
    @State private var hindi = false
    var body: some View {
        Group {
            if let p {
                CSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles").foregroundStyle(Color.csCyan)
                            Text("SAATHI PREDICTS").font(.caption.bold()).foregroundStyle(Color.csCyan)
                            Spacer()
                            LangPill(hindi: $hindi)
                        }
                        Text(inrD(p.predictedPayout)).font(.system(size: 30, weight: .bold)).foregroundStyle(Color.csNavy)
                        Text(hindi ? (p.headlineHi ?? "") : "\(p.headline ?? "") · \(p.confidenceLabel ?? "")").font(.footnote).foregroundStyle(Color.csSecondary)
                        if let b = p.basis { Text(b).font(.caption).foregroundStyle(Color.csSecondary) }
                        ForEach(p.riskFlags ?? [], id: \.self) { f in
                            HStack(spacing: 6) { Circle().fill(riskTint(f.severity)).frame(width: 8, height: 8); Text(hindi ? (f.messageHi ?? f.message ?? "") : (f.message ?? "")).font(.caption).foregroundStyle(Color.csNavy) }
                        }
                        Button { withAnimation(.spring(duration: 0.3)) { open.toggle() } } label: {
                            HStack { Text(open ? "Hide reasons" : "Why \(inrD(p.totalDeductions)) is deducted").font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: open ? "chevron.up" : "chevron.down") }.foregroundStyle(Color.csCyan)
                        }.buttonStyle(.plain)
                        if open {
                            HStack { Text("Hospital bill").foregroundStyle(Color.csSecondary); Spacer(); Text(inrD(p.billAmount)).bold().foregroundStyle(Color.csNavy) }.font(.footnote)
                            ForEach(p.deductions ?? [], id: \.self) { d in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack { Text(d.label).font(.footnote.weight(.semibold)).foregroundStyle(Color.csNavy); Spacer(); Text("−\(inrD(d.amount))").font(.footnote.bold()).foregroundStyle(Color.csError) }
                                    Text(hindi ? (d.reasonHi ?? d.reason ?? "") : (d.reason ?? "")).font(.caption).foregroundStyle(Color.csSecondary)
                                }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.csBackground).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            HStack { Text("You get").foregroundStyle(Color.csSecondary); Spacer(); Text(inrD(p.predictedPayout)).bold().foregroundStyle(Color.csSuccess) }.font(.footnote)
                            ForEach(p.tips ?? [], id: \.self) { Text("💡 \($0)").font(.caption).foregroundStyle(Color.csNavy) }
                        }
                    }
                }
            }
        }
        .task(id: "\(claimId)|\(refreshKey)") { if let r = try? await API.shared.prediction(claimId) { p = r } }
    }
}

// MARK: - Bill analysis

struct BillAnalysisView: View {
    let claimId: String
    @State private var b: BillAnalysis?
    @State private var error: String?
    @State private var hindi = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Line by line against your policy rules").font(.footnote).foregroundStyle(Color.csSecondary); Spacer(); LangPill(hindi: $hindi) }
                if b == nil && error == nil { SkeletonCard(lines: 3); SkeletonCard(lines: 3) }
                if let b {
                    if !b.available {
                        SaathiTip(text: (hindi ? b.messageHi : b.message) ?? "Upload the hospital bill first.")
                    } else {
                        if let s = hindi ? b.summaryHi : b.summary { SaathiTip(text: s) }
                        if let t = b.totals {
                            CSCard {
                                VStack(spacing: 6) {
                                    row("Billed", inrD(t.billed), .csNavy)
                                    row("Not payable", "−\(inrD(t.nonPayable))", .csError)
                                    row("Room-rent cut", "−\(inrD(t.proportionateCut))", .csWarning)
                                    row("Co-pay", "−\(inrD(t.coPay))", .csSecondary)
                                    Divider()
                                    row("You get", inrD(t.finalPayable), .csSuccess)
                                }
                            }
                        }
                        ForEach(b.items ?? [], id: \.self) { i in
                            let tint: Color = i.status == "NON_PAYABLE" ? .csError : i.status == "PARTIAL" ? .csWarning : .csSuccess
                            CSCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Circle().fill(tint).frame(width: 10, height: 10)
                                        Text(i.description).font(.subheadline.weight(.semibold)).foregroundStyle(Color.csNavy)
                                        Spacer()
                                        StatusBadge(title: i.status == "NON_PAYABLE" ? "Not payable" : i.status == "PARTIAL" ? "Partial" : "Payable", tint: tint)
                                    }
                                    Text("\(inrD(i.payableAmount)) of \(inrD(i.amount))").font(.footnote).foregroundStyle(Color.csNavy)
                                    Text(hindi ? (i.reasonHi ?? i.reason ?? "") : (i.reason ?? "")).font(.caption).foregroundStyle(Color.csSecondary)
                                }
                            }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Bill analysis")
        .task { do { b = try await API.shared.billAnalysis(claimId) } catch { self.error = error.localizedDescription } }
    }
    private func row(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack { Text(l).font(.footnote).foregroundStyle(Color.csSecondary); Spacer(); Text(v).font(.footnote.bold()).foregroundStyle(c) }
    }
}

// MARK: - Voice Saathi (Sarvam STT/TTS via server, on-device fallback)

@MainActor
final class SaathiVoice: NSObject, ObservableObject {
    @Published var recording = false
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private var fileURL: URL { FileManager.default.temporaryDirectory.appendingPathComponent("saathi_voice.m4a") }

    func start() async -> String? {
        stopSpeaking()
        let granted: Bool = await withCheckedContinuation { c in AVAudioApplication.requestRecordPermission { c.resume(returning: $0) } }
        guard granted else { return "Microphone permission is needed for voice. Enable it in Settings." }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try s.setActive(true)
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.record()
            recording = true
            return nil
        } catch { return "Could not start the microphone" }
    }

    /// Stops recording and returns the transcript: Sarvam STT first, Apple on-device speech recognition as fallback.
    func stopAndTranscribe(hindi: Bool) async -> String? {
        recorder?.stop(); recorder = nil; recording = false
        guard let data = try? Data(contentsOf: fileURL), data.count > 1000 else { return nil }
        if let r = try? await API.shared.stt(data.base64EncodedString(), lang: hindi ? "hi" : nil), let t = r.text, !t.isEmpty { return t }
        return await deviceTranscribe(hindi: hindi)
    }

    private func deviceTranscribe(hindi: Bool) async -> String? {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        guard status == .authorized, let rec = SFSpeechRecognizer(locale: Locale(identifier: hindi ? "hi-IN" : "en-IN")), rec.isAvailable else { return nil }
        let req = SFSpeechURLRecognitionRequest(url: fileURL)
        return await withCheckedContinuation { c in
            var done = false
            rec.recognitionTask(with: req) { result, err in
                if done { return }
                if let result, result.isFinal { done = true; c.resume(returning: result.bestTranscription.formattedString) }
                else if err != nil { done = true; c.resume(returning: nil) }
            }
        }
    }

    func speak(_ text: String, hindi: Bool) async {
        stopSpeaking()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let r = try? await API.shared.tts(text, lang: hindi ? "hi" : "en"), let b64 = r.audioBase64, let data = Data(base64Encoded: b64), let p = try? AVAudioPlayer(data: data) {
            player = p; p.play(); return
        }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: hindi ? "hi-IN" : "en-IN") ?? AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }
    func stopSpeaking() { player?.stop(); player = nil; if synth.isSpeaking { synth.stopSpeaking(at: .immediate) } }
}

func isHindiText(_ s: String) -> Bool { s.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) } }
