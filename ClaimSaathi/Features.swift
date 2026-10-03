import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Models for the server-driven features (warnings, templates, finance, chat cards)

struct AmountWarning: Decodable, Hashable, Identifiable {
    var code: String
    var severity: String
    var message: String
    var field: String?
    var claimId: String?
    var claimNumber: String?
    var id: String { code + (field ?? "") + (claimId ?? "") }
    var tint: Color { severity == "high" ? .csError : severity == "medium" ? .csWarning : .csSecondary }
}
struct PreviewEstimate: Decodable, Hashable { var billAmount: Int?; var approvedAmount: Int?; var coPayAmount: Int?; var outOfPocket: Int? }
struct PreviewResult: Decodable {
    var warnings: [AmountWarning]?
    var hasBlocking: Bool?
    var sumInsured: Int?
    var usedSumInsured: Int?
    var remainingSumInsured: Int?
    var roomRentLimit: Int?
    var coPayPercent: Double?
    var estimate: PreviewEstimate?
}
struct PreviewBody: Encodable {
    var policyId: String?
    var type: String
    var estimatedAmount: Int?
    var billAmount: Int?
    var roomRentPerDay: Int?
    var days: Int?
    var reason: String?
    var treatment: String?
    var admissionDate: String?
}
struct ClaimTemplate: Decodable, Hashable {
    var claimType: String?
    var policyId: String?
    var hospital: String?
    var hospitalCity: String?
    var isNetworkHospital: Bool?
    var reason: String?
    var treatment: String?
    var admissionType: String?
    var admissionDate: String?
    var dischargeDate: String?
    var days: Int?
    var roomType: String?
    var roomRentPerDay: Int?
    var estimatedAmount: Int?
    var billAmount: Int?
    var patientName: String?
    var patientDetails: PatientDetails?
}
struct DemoTemplates: Decodable { var policyId: String?; var policyNumber: String?; var preauth: ClaimTemplate?; var reimbursement: ClaimTemplate?; var consentOtp: String? }

struct FinanceAccount: Decodable, Hashable, Identifiable { var id: String; var bankName: String?; var accountType: String?; var maskedNumber: String?; var ifsc: String?; var balance: Double?; var isPrimary: Bool?; var linkedForPayouts: Bool? }
struct ExpenseCategory: Decodable, Hashable { var category: String; var amount: Double?; var percent: Double? }
struct MonthlyExpenses: Decodable, Hashable { var month: String?; var label: String?; var total: Double?; var categories: [ExpenseCategory]? }
struct MedicalSpend: Decodable, Hashable { var totalMedicalSpend: Double?; var insurerPaid: Double?; var outOfPocket: Double?; var insurerPaidPercent: Double?; var settledClaims: Int?; var pendingClaims: Int?; var pendingClaimAmount: Double?; var thisMonthMedicalExpense: Double? }
struct Payout: Decodable, Hashable { var claimId: String?; var claimNumber: String?; var hospital: String?; var amount: Double?; var utr: String?; var paidAt: String?; var creditedTo: String? }
struct Finance: Decodable { var isDemo: Bool?; var note: String?; var accounts: [FinanceAccount]?; var totalBalance: Double?; var monthlyExpenses: MonthlyExpenses?; var medical: MedicalSpend?; var payouts: [Payout]?; var totalPayouts: Double? }
struct ChatCard: Decodable, Hashable {
    var type: String
    var title: String?
    var total: Double?
    var month: String?
    var accounts: [FinanceAccount]?
    var categories: [ExpenseCategory]?
    var payouts: [Payout]?
    var totalMedicalSpend: Double?
    var insurerPaid: Double?
    var outOfPocket: Double?
    var insurerPaidPercent: Double?
}
struct ChatSuggestions: Decodable { var greeting: String?; var suggestions: [String]? }

func inrD(_ v: Double?) -> String { v.map { inr(Int($0.rounded())) } ?? "–" }
func shortDate(_ iso: String?) -> String {
    guard let iso else { return "" }
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? { let g = DateFormatter(); g.dateFormat = "yyyy-MM-dd"; return g.date(from: String(iso.prefix(10))) }()
    guard let d else { return String(iso.prefix(10)) }
    return d.formatted(.dateTime.day().month(.abbreviated).year())
}
func statusTint(_ s: ClaimStatus?) -> Color {
    switch s {
    case .SETTLED, .APPROVED: .csSuccess
    case .REJECTED: .csError
    case .QUERY_RAISED, .DOCS_PENDING: .csWarning
    default: .csCyan
    }
}

extension API {
    func preview(_ body: PreviewBody) async throws -> PreviewResult { try await request("claims/preview", method: "POST", json: body) }
    func templates() async throws -> DemoTemplates { try await request("demo/templates") }
    func finance() async throws -> Finance { try await request("me/finance") }
    func chatSuggestions() async throws -> ChatSuggestions { try await request("ai/suggestions") }
}

// MARK: - Warnings UI

struct WarningList: View {
    let warnings: [AmountWarning]
    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(warnings) { w in
                    HStack(alignment: .top, spacing: 8) {
                        Text(w.severity == "info" ? "ℹ️" : "⚠️")
                        VStack(alignment: .leading, spacing: 2) {
                            if let n = w.claimNumber { Text(n).font(.caption.bold()).foregroundStyle(Color.csCyan) }
                            Text(w.message).font(.footnote).foregroundStyle(w.tint)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(w.tint.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Document source: camera, photos or files → multipart "file"

struct PickedFile {
    var data: Data
    var filename: String
    var mime: String
    static let maxBytes = 10 * 1024 * 1024
    static func check(_ data: Data) throws {
        if data.count > maxBytes { throw APIError.http(413, "File is larger than 10 MB. Pick a smaller file or take a clearer photo.") }
        if data.isEmpty { throw APIError.http(400, "The selected file is empty.") }
    }
    static func mime(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "png": "image/png"
        case "heic", "heif": "image/heic"
        case "webp": "image/webp"
        default: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg"
        }
    }
    /// Re-encode any photo (HEIC, PNG…) as JPEG so every server path accepts it, keeping it under 10 MB.
    static func jpeg(_ data: Data, name: String) -> PickedFile? {
        guard let image = UIImage(data: data) else { return nil }
        var quality: CGFloat = 0.8
        var out = image.jpegData(compressionQuality: quality)
        while let o = out, o.count > maxBytes, quality > 0.2 { quality -= 0.2; out = image.jpegData(compressionQuality: quality) }
        return out.map { PickedFile(data: $0, filename: "\(name)-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg") }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Shows "Camera / Photos / Files" and hands back a ready-to-upload file.
struct DocumentSourceModifier: ViewModifier {
    @Binding var isPresented: Bool
    var name: String
    var onPick: (PickedFile) -> Void
    var onError: (String) -> Void
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photo: PhotosPickerItem?
    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add document", isPresented: $isPresented, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { showCamera = true } }
                Button("Choose from Photos") { showPhotos = true }
                Button("Browse files (PDF / image)") { showFiles = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let data = image.jpegData(compressionQuality: 0.8), let f = PickedFile.jpeg(data, name: name) { onPick(f) } else { onError("Could not read the photo.") }
                }.ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images)
            .onChange(of: photo) { _, item in
                guard let item else { return }
                photo = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let f = PickedFile.jpeg(data, name: name) { onPick(f) }
                    else { onError("Could not read the selected photo.") }
                }
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .jpeg, .png, .heic, .image]) { result in
                switch result {
                case .failure(let e): onError(e.localizedDescription)
                case .success(let url):
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { return onError("Could not read \(url.lastPathComponent).") }
                    let mime = PickedFile.mime(for: url)
                    if mime == "image/heic", let f = PickedFile.jpeg(data, name: name) { onPick(f) }
                    else { onPick(PickedFile(data: data, filename: url.lastPathComponent, mime: mime)) }
                }
            }
    }
}
extension View {
    func documentSource(isPresented: Binding<Bool>, name: String = "document", onPick: @escaping (PickedFile) -> Void, onError: @escaping (String) -> Void) -> some View {
        modifier(DocumentSourceModifier(isPresented: isPresented, name: name, onPick: onPick, onError: onError))
    }
}

// MARK: - Chat (live /ai/chat with suggestion chips + finance cards)

struct ChatMessage: Identifiable { let id = UUID(); let mine: Bool; let text: String; var cards: [ChatCard] = [] }

struct ChatScreen: View {
    @Environment(AppState.self) private var app
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var chips: [String] = []
    @State private var sending = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask Saathi").font(.title2.bold()).foregroundStyle(.white)
                    Text("Claims, cover, bank balances and medical spend").font(.footnote).foregroundStyle(.white.opacity(0.75))
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.csNavy)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                            if sending { HStack { ProgressView(); Text("Saathi is typing…").font(.footnote).foregroundStyle(Color.csSecondary) }.id("typing") }
                            if let error { Text(error).font(.footnote).foregroundStyle(Color.csError) }
                        }.padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) } }
                }
                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.self) { chip in
                                Button(chip) { send(chip) }
                                    .font(.footnote.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                                    .foregroundStyle(Color.csNavy).background(Color.csCyan.opacity(0.15)).clipShape(Capsule())
                            }
                        }.padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
                HStack(spacing: 8) {
                    TextField("Ask about your claim or money…", text: $input).padding(12).background(Color.csBackground).clipShape(RoundedRectangle(cornerRadius: 14)).onSubmit { send(input) }
                    Button { send(input) } label: { Image(systemName: "paperplane.fill").padding(12).foregroundStyle(.white).background(Color.csCyan).clipShape(Circle()) }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
                }.padding(12).background(Color.white)
            }
            .background(Color.csBackground)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard messages.isEmpty else { return }
                if let s = try? await API.shared.chatSuggestions() {
                    if let g = s.greeting { messages = [ChatMessage(mine: false, text: g)] }
                    chips = s.suggestions ?? []
                }
            }
        }
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        VStack(alignment: m.mine ? .trailing : .leading, spacing: 8) {
            Text(m.text)
                .padding(12)
                .foregroundStyle(m.mine ? .white : Color.csNavy)
                .background(m.mine ? Color.csNavy : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 300, alignment: m.mine ? .trailing : .leading)
            ForEach(m.cards, id: \.self) { FinanceCardView(card: $0) }
        }.frame(maxWidth: .infinity, alignment: m.mine ? .trailing : .leading)
    }

    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !sending else { return }
        messages.append(ChatMessage(mine: true, text: t)); input = ""; sending = true; error = nil
        let claimId = app.home?.currentClaim?.id
        Task {
            do {
                let r = try await API.shared.chat(t, claimId: claimId)
                messages.append(ChatMessage(mine: false, text: r.answer, cards: r.cards ?? []))
                chips = r.suggestions ?? r.followUps ?? chips
            } catch { self.error = error.localizedDescription }
            sending = false
        }
    }
}

struct FinanceCardView: View {
    let card: ChatCard
    var body: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(card.title ?? pretty(card.type)).font(.subheadline.bold()).foregroundStyle(Color.csNavy); Spacer(); StatusBadge(title: "Demo", tint: .csSecondary) }
                switch card.type {
                case "accounts":
                    ForEach(card.accounts ?? []) { a in
                        HStack { VStack(alignment: .leading) { Text(a.bankName ?? "").font(.footnote.bold()); Text("\(a.accountType ?? "") · \(a.maskedNumber ?? "")").font(.caption).foregroundStyle(Color.csSecondary) }; Spacer(); Text(inrD(a.balance)).font(.footnote.bold()) }
                    }
                    Divider(); HStack { Text("Total balance").bold(); Spacer(); Text(inrD(card.total)).bold().foregroundStyle(Color.csSuccess) }
                case "expenses":
                    let maxV = (card.categories ?? []).compactMap(\.amount).max() ?? 1
                    ForEach(card.categories ?? [], id: \.category) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(c.category).font(.caption); Spacer(); Text(inrD(c.amount)).font(.caption.bold()) }
                            GeometryReader { g in Capsule().fill(Color.csCyan).frame(width: g.size.width * CGFloat((c.amount ?? 0) / maxV)) }.frame(height: 6)
                        }
                    }
                    Divider(); HStack { Text("Total spent").bold(); Spacer(); Text(inrD(card.total)).bold() }
                case "medical":
                    row("Hospital bills", inrD(card.totalMedicalSpend))
                    row("Insurer paid", inrD(card.insurerPaid), .csSuccess)
                    row("Out of pocket", inrD(card.outOfPocket), .csWarning)
                    ProgressView(value: (card.insurerPaidPercent ?? 0) / 100).tint(Color.csSuccess)
                    Text("\(Int(card.insurerPaidPercent ?? 0))% covered by insurance").font(.caption).foregroundStyle(Color.csSecondary)
                case "payouts":
                    if (card.payouts ?? []).isEmpty { Text("No payouts yet").font(.footnote).foregroundStyle(Color.csSecondary) }
                    ForEach(card.payouts ?? [], id: \.self) { p in
                        HStack { VStack(alignment: .leading) { Text(p.claimNumber ?? "").font(.footnote.bold()); Text("\(shortDate(p.paidAt))\(p.utr.map { " · UTR \($0)" } ?? "")").font(.caption).foregroundStyle(Color.csSecondary) }; Spacer(); Text(inrD(p.amount)).font(.footnote.bold()).foregroundStyle(Color.csSuccess) }
                    }
                    Divider(); HStack { Text("Total received").bold(); Spacer(); Text(inrD(card.total)).bold() }
                default:
                    EmptyView()
                }
            }
        }.frame(maxWidth: 320)
    }
    private func row(_ k: String, _ v: String, _ tint: Color = .csNavy) -> some View {
        HStack { Text(k).font(.footnote).foregroundStyle(Color.csSecondary); Spacer(); Text(v).font(.footnote.bold()).foregroundStyle(tint) }
    }
}

// MARK: - Finance (Profile → Money)

struct FinanceView: View {
    @State private var finance: Finance?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let f = finance {
                    if let note = f.note { Text(note).font(.caption).foregroundStyle(Color.csSecondary) }
                    FinanceCardView(card: ChatCard(type: "accounts", title: "Linked bank accounts", total: f.totalBalance, accounts: f.accounts))
                    FinanceCardView(card: ChatCard(type: "expenses", title: "Expenses · \(f.monthlyExpenses?.label ?? "")", total: f.monthlyExpenses?.total, categories: f.monthlyExpenses?.categories))
                    FinanceCardView(card: ChatCard(type: "medical", title: "Medical spend", totalMedicalSpend: f.medical?.totalMedicalSpend, insurerPaid: f.medical?.insurerPaid, outOfPocket: f.medical?.outOfPocket, insurerPaidPercent: f.medical?.insurerPaidPercent))
                    FinanceCardView(card: ChatCard(type: "payouts", title: "Claim payouts received", total: f.totalPayouts, payouts: f.payouts))
                } else if error == nil { ProgressView().frame(maxWidth: .infinity) }
                if let error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Money")
        .task { do { finance = try await API.shared.finance() } catch { self.error = error.localizedDescription } }
        .refreshable { finance = try? await API.shared.finance() }
    }
}
