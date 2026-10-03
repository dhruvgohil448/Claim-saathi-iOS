import SwiftUI
import PhotosUI

@Observable
@MainActor
final class AppState {
    var user: User?
    var home: Home?
    var error: String?
    var busy = false
    var authed = TokenStore.token != nil
    var lastUpload: UploadResponse?

    func logout() {
        TokenStore.token = nil
        authed = false
        user = nil
        home = nil
    }

    func run(_ work: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do { try await work() }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

struct RootView: View {
    @State private var app = AppState()

    var body: some View {
        Group {
            if app.authed { MainTabs().environment(app) }
            else { LoginFlow().environment(app) }
        }
        .tint(Color.csCyan)
        .animation(.easeInOut(duration: 0.35), value: app.authed)
        .task {
            API.shared.onUnauthorized = { Task { @MainActor in app.logout() } }
            guard TokenStore.token != nil else { return }
            do { app.user = try await API.shared.me(); app.authed = true }
            catch { app.logout() }
        }
    }
}

private struct LoginFlow: View {
    @Environment(AppState.self) private var app
    @State private var phone = ""
    @State private var otp = ""
    @State private var stage = 0
    @State private var name = ""
    @State private var email = ""
    @State private var dob = "1990-01-01"
    @State private var gender = "male"
    @State private var city = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavyHero(heroTitle, heroSubtitle) { if stage > 0 { StepDots(current: stage, total: 3) } }
                    .padding(.horizontal, -16)
                content
                    .padding(.horizontal, 4)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                if let error = app.error { Text(error).foregroundStyle(Color.csError).font(.footnote) }
            }
            .padding(16)
            .animation(.spring(duration: 0.4), value: stage)
        }
        .background(Color.csBackground.ignoresSafeArea())
    }

    private var heroTitle: String {
        stage == 0 ? "Claim Saathi" : stage == 1 ? "Verify OTP" : "Almost there"
    }
    private var heroSubtitle: String {
        stage == 0 ? "Your AI health-insurance companion" : stage == 1 ? "Sent to \(phone). Demo code 111000." : "Complete your profile to start a claim"
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case 0:
            CSCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Login with mobile").font(.headline).foregroundStyle(Color.csNavy)
                    Text("Use the number on your policy. No SMS is sent in demo.").font(.footnote).foregroundStyle(Color.csSecondary)
                    FieldBox(title: "10-digit phone", text: $phone, keyboard: .numberPad)
                    PrimaryButton(title: "Get OTP", busy: app.busy, enabled: phone.filter(\.isNumber).count == 10) {
                        app.run {
                            _ = try await API.shared.sendOtp(String(phone.filter(\.isNumber).prefix(10)))
                            stage = 1
                        }
                    }
                    Text("Demo OTP is always 111000").font(.caption).foregroundStyle(Color.csSecondary)
                }
            }
        case 1:
            CSCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Enter the 6-digit code").font(.headline).foregroundStyle(Color.csNavy)
                    OtpBoxes(value: $otp)
                    PrimaryButton(title: "Verify & continue", busy: app.busy, enabled: otp.count == 6) {
                        app.run {
                            let res = try await API.shared.verifyOtp(String(phone.filter(\.isNumber).prefix(10)), otp)
                            TokenStore.token = res.token
                            app.user = res.user
                            if res.needsProfile == true { stage = 2 } else { app.authed = true }
                        }
                    }
                    GhostButton(title: "Change number") { stage = 0 }
                }
            }
        default:
            CSCard {
                VStack(alignment: .leading, spacing: 12) {
                    FieldBox(title: "Full name", text: $name)
                    FieldBox(title: "Email", text: $email, keyboard: .emailAddress)
                    FieldBox(title: "Date of birth yyyy-MM-dd", text: $dob)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("male"); Text("Female").tag("female"); Text("Other").tag("other")
                    }.pickerStyle(.segmented)
                    FieldBox(title: "City", text: $city)
                    PrimaryButton(title: "Save & enter app", busy: app.busy, enabled: name.count >= 2 && email.contains("@")) {
                        app.run {
                            let res = try await API.shared.putProfile(ProfileBody(name: name, email: email, dob: dob, gender: gender, city: city.isEmpty ? nil : city))
                            TokenStore.token = res.token
                            app.user = res.user
                            app.authed = true
                        }
                    }
                }
            }
        }
    }
}

private struct MainTabs: View {
    @Environment(AppState.self) private var app
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            HomeTab().tag(0).tabItem { Label("Home", systemImage: "house.fill") }
            ClaimsTab().tag(1).tabItem { Label("Claims", systemImage: "list.bullet.rectangle") }
            ChatScreen().tag(2).tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            AlertsTab().tag(3).tabItem { Label("Alerts", systemImage: "bell.fill") }.badge(app.home?.counts?.unreadNotifications ?? 0)
            ProfileTab().tag(4).tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}

private struct HomeTab: View {
    @Environment(AppState.self) private var app
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Good to see you").font(.footnote).foregroundStyle(.white.opacity(0.75))
                        Text(app.home?.user.name ?? app.user?.name ?? "Claim Saathi")
                            .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        HStack(alignment: .top, spacing: 8) {
                            stat("Paid out", inr(app.home?.paidOut))
                            stat("Open claims", "\(app.home?.counts?.activeClaims ?? 0)")
                            stat("Queries", "\(app.home?.counts?.openQueries ?? 0)")
                        }
                    }
                    .padding(20)
                    .safeAreaPadding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Color(red: 0, green: 0.23, blue: 0.55), Color.csNavy], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea(edges: .top))

                    Group {
                    if app.home == nil {
                        SkeletonCard(lines: 2)
                        SkeletonCard(lines: 3)
                        SkeletonCard(lines: 1)
                    }
                    if let home = app.home {
                        if home.activePolicy == nil {
                            SaathiTip(text: "Start by linking your health policy — I’ll explain your cover, room-rent limit and co-pay in simple words.")
                        } else if home.currentClaim == nil {
                            SaathiTip(text: "Your policy is linked. Tap “Start claim” — I’ll warn you about co-pay and room-rent limits before you submit.")
                        }
                    }
                    if let policy = app.home?.activePolicy {
                        NavigationLink { PolicyReaderView(policyId: policy.id) } label: {
                            CSCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ACTIVE POLICY").font(.caption.bold()).foregroundStyle(Color.csCyan)
                                    Text(policy.insurer ?? "").font(.headline).foregroundStyle(Color.csNavy)
                                    Text(policy.policyNumber ?? "").foregroundStyle(Color.csSecondary)
                                    HStack(alignment: .top) {
                                        Text("\(inr(policy.sumInsured)) cover").frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(inr(policy.roomRentLimit))/day").frame(maxWidth: .infinity, alignment: .center)
                                        Text("\(Int(policy.coPayPercent ?? 0))% copay").frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(Color.csNavy)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    if let claim = app.home?.currentClaim {
                        NavigationLink { TrackingView(claimId: claim.id) } label: {
                            CSCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { Text(claim.claimNumber ?? "").foregroundStyle(Color.csCyan).font(.headline); if claim.isTemplate == true { StatusBadge(title: "Sample", tint: .csSecondary) }; Spacer(); StatusBadge(title: pretty(claim.status?.rawValue ?? ""), tint: statusTint(claim.status)) }
                                    Text(claim.hospital ?? "").foregroundStyle(Color.csNavy)
                                    Text("\(claim.claimType == .CASHLESS ? "Cashless pre-auth" : "Reimbursement") · \(inr(claim.billAmount ?? claim.estimatedAmount))").font(.footnote).foregroundStyle(Color.csSecondary)
                                    let done = claim.checklist?.verified?.count ?? 0
                                    let total = claim.checklist?.required?.count ?? 0
                                    if total > 0 { UploadProgressBar(done: done, total: total).padding(.top, 4) }
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    WarningList(warnings: app.home?.warnings ?? [])
                    HStack(alignment: .top, spacing: 8) {
                        NavigationLink { StartClaimView() } label: { ActionTile(icon: "plus.circle.fill", title: "Start claim", subtitle: "File or pre-auth") }
                        NavigationLink { AddPolicyView() } label: { ActionTile(icon: "doc.text.fill", title: "Link policy", subtitle: "Add cover") }
                        NavigationLink { BankView() } label: { ActionTile(icon: "building.columns.fill", title: "Bank", subtitle: "Payout account") }
                    }
                    Text("Needs you").font(.title3.bold()).foregroundStyle(Color.csNavy).padding(.top, 4)
                    ForEach(app.home?.pendingActions ?? [], id: \.title) { action in
                        actionLink(action)
                    }
                    if app.home != nil && app.home?.pendingActions?.isEmpty != false {
                        CSCard { EmptyStateView(icon: "checkmark.circle.fill", title: "You’re all caught up", message: "No pending actions. We’ll alert you when something needs you.") }
                    }
                    if let error = app.error { Text(error).font(.footnote).foregroundStyle(Color.csError) }
                    }
                    .padding(.horizontal, 16)
                    Color.clear.frame(height: 72)
                }
            }
            .background(Color.csBackground.ignoresSafeArea())
            .refreshable { if let home = try? await API.shared.home() { app.home = home } }
            .saathiFab(claimId: app.home?.currentClaim?.id)
            .toolbar(.hidden, for: .navigationBar)
            .task { while !Task.isCancelled { if let home = try? await API.shared.home() { app.home = home }; try? await Task.sleep(for: .seconds(5)) } }
        }
    }

    private func actionIcon(_ kind: String) -> String {
        switch kind {
        case "QUERY": "questionmark.bubble.fill"
        case "MISSING_DOC", "REUPLOAD_DOC": "doc.badge.arrow.up.fill"
        case "ADD_BANK": "building.columns.fill"
        case "COMPLETE_PROFILE": "person.crop.circle.badge.exclamationmark"
        default: "doc.text.fill"
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private func actionLink(_ action: PendingAction) -> some View {
        let card = CSCard {
            HStack(spacing: 12) {
                Image(systemName: actionIcon(action.kind))
                    .foregroundStyle(action.kind == "QUERY" ? Color.csWarning : Color.csCyan)
                    .frame(width: 38, height: 38)
                    .background((action.kind == "QUERY" ? Color.csWarning : Color.csCyan).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(pretty(action.kind)).font(.caption.bold()).foregroundStyle(action.kind == "QUERY" ? Color.csWarning : Color.csCyan)
                    Text(action.title).foregroundStyle(Color.csNavy).font(.subheadline.weight(.semibold)).lineLimit(3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Color.csSecondary)
            }
        }
        switch action.kind {
        case "QUERY":
            if let id = action.queryId { NavigationLink { QueryDetailView(queryId: id) } label: { card }.buttonStyle(.plain) }
        case "MISSING_DOC", "REUPLOAD_DOC":
            if let id = action.claimId { NavigationLink { ChecklistView(claimId: id) } label: { card }.buttonStyle(.plain) }
        case "ADD_BANK":
            NavigationLink { BankView() } label: { card }.buttonStyle(.plain)
        case "COMPLETE_PROFILE":
            NavigationLink { ProfileEditView() } label: { card }.buttonStyle(.plain)
        default:
            NavigationLink { AddPolicyView() } label: { card }.buttonStyle(.plain)
        }
    }
}

private struct AddPolicyView: View {
    @Environment(AppState.self) private var app
    @State private var insurer = ""
    @State private var number = ""
    @State private var sum = ""
    @State private var start = "2026-01-01"
    @State private var room = "4000"
    @State private var copay = "10"
    @State private var savedId: String?
    @State private var fileName: String?
    @State private var fileBytes: Data?
    @State private var fileMime = "application/pdf"
    @State private var showFiles = false
    @State private var extracted = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Fill the details and attach the policy PDF. Leave fields empty to use the demo cover (₹5L, room ₹4,000/day, 10% co-pay).")
                    .font(.footnote).foregroundStyle(Color.csSecondary)
                FieldBox(title: "Insurer", text: $insurer)
                FieldBox(title: "Policy number", text: $number)
                FieldBox(title: "Sum insured", text: $sum, keyboard: .numberPad)
                FieldBox(title: "Start yyyy-MM-dd", text: $start)
                FieldBox(title: "Room rent / day", text: $room, keyboard: .numberPad)
                FieldBox(title: "Co-pay %", text: $copay, keyboard: .numberPad)
                GhostButton(title: fileName == nil ? "Upload policy document" : "Change document") { showFiles = true }
                if let fileName { Text("Attached: \(fileName)").font(.footnote).foregroundStyle(Color.csSuccess) }
                PrimaryButton(title: "Save policy", busy: app.busy, enabled: true) {
                    app.run {
                        let body = AddPolicyBody(insurer: insurer, policyNumber: number, sumInsured: Int(sum) ?? 0, startDate: start, roomRentLimit: Int(room), coPayPercent: Double(copay))
                        let saved: AddPolicyResponse
                        if let fileBytes, let fileName {
                            saved = try await API.shared.addPolicyPdf(body, bytes: fileBytes, filename: fileName, mime: fileMime)
                        } else {
                            saved = try await API.shared.addPolicy(body)
                        }
                        savedId = saved.policy.id
                        extracted = saved.extractedFromPdf == true
                    }
                }
                if extracted { Text("Rules were read from the PDF.").font(.footnote).foregroundStyle(Color.csSuccess) }
                if let savedId { NavigationLink("Read this policy") { PolicyReaderView(policyId: savedId) } }
                if let error = app.error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Link a policy")
        .navigationBarTitleDisplayMode(.inline)
        .documentSource(isPresented: $showFiles, name: "policy", onPick: { file in
            fileBytes = file.data; fileName = file.filename; fileMime = file.mime
        }, onError: { app.error = $0 })
    }
}

private struct PolicyReaderView: View {
    let policyId: String
    @State private var analysis: PolicyAnalysis?
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let analysis {
                    CSCard { Text(analysis.whatIsCovered ?? "").foregroundStyle(Color.csNavy) }
                    ForEach(analysis.coverage ?? [], id: \.item) { row in
                        CSCard {
                            VStack(alignment: .leading) {
                                Text(row.item ?? "").font(.headline).foregroundStyle(Color.csNavy)
                                Text(row.detail ?? "").font(.footnote).foregroundStyle(Color.csSecondary)
                            }
                        }
                    }
                    ForEach(analysis.waitingPeriods ?? [], id: \.name) { wait in
                        StatusBadge(title: wait.status ?? wait.name ?? "", tint: wait.active == true ? .csWarning : .csSuccess)
                    }
                }
                if let error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle(analysis?.policyNumber ?? "Policy")
        .task { do { analysis = try await API.shared.analyze(policyId) } catch { self.error = error.localizedDescription } }
    }
}

private struct StartClaimView: View {
    @Environment(AppState.self) private var app
    @State private var step = 0
    @State private var policies: [Policy] = []
    @State private var policyId = ""
    @State private var cashless = false
    @State private var hospital = ""
    @State private var city = ""
    @State private var reason = ""
    @State private var treatment = ""
    @State private var patient = ""
    @State private var admission = ""
    @State private var discharge = ""
    @State private var days = ""
    @State private var roomRent = ""
    @State private var estimate = ""
    @State private var bill = ""
    @State private var details: PatientDetails?
    @State private var network: Bool?
    @State private var roomType: String?
    @State private var otp = ""
    @State private var templates: DemoTemplates?
    @State private var preview: PreviewResult?
    @State private var created: Claim?
    private func num(_ s: String) -> Int? { Int(s.filter(\.isNumber)) }
    private var previewKey: String { [policyId, cashless ? "C" : "R", estimate, bill, roomRent, days].joined(separator: "|") }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                StepDots(current: step, total: 3).padding(.bottom, 4)
                switch step {
                case 0:
                    Text("How should we file this?").font(.title3.bold()).foregroundStyle(Color.csNavy)
                    Picker("Type", selection: $cashless) { Text("Reimbursement").tag(false); Text("Pre-auth (cashless)").tag(true) }.pickerStyle(.segmented)
                    ForEach(policies) { policy in
                        Button { policyId = policy.id } label: {
                            CSCard {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(policy.policyNumber ?? "").font(.headline).foregroundStyle(policyId == policy.id ? Color.csCyan : Color.csNavy)
                                        Text("\(policy.insurer ?? "") · \(inr(policy.sumInsured)) cover").font(.footnote).foregroundStyle(Color.csSecondary)
                                    }
                                    Spacer()
                                    if policyId == policy.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.csCyan) }
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    if policies.isEmpty { Text("No policy yet. Link a policy first.").foregroundStyle(Color.csSecondary) }
                    PrimaryButton(title: "Next", enabled: !policyId.isEmpty) { withAnimation { step = 1 } }
                case 1:
                    HStack {
                        Text("Hospital & amounts").font(.title3.bold()).foregroundStyle(Color.csNavy)
                        Spacer()
                        Button { useSample() } label: { Label("Use sample data", systemImage: "wand.and.stars") }.font(.footnote.bold()).disabled(templates == nil)
                    }
                    FieldBox(title: "Hospital", text: $hospital)
                    FieldBox(title: "City", text: $city)
                    FieldBox(title: "Diagnosis / reason", text: $reason)
                    FieldBox(title: "Treatment", text: $treatment)
                    FieldBox(title: "Patient", text: $patient)
                    FieldBox(title: cashless ? "Planned admission (yyyy-MM-dd)" : "Admission date (yyyy-MM-dd)", text: $admission)
                    if !cashless { FieldBox(title: "Discharge date (yyyy-MM-dd)", text: $discharge) }
                    HStack { FieldBox(title: "Days", text: $days, keyboard: .numberPad); FieldBox(title: "Room rent / day", text: $roomRent, keyboard: .numberPad) }
                    FieldBox(title: "Estimated amount", text: $estimate, keyboard: .numberPad)
                    if !cashless { FieldBox(title: "Final bill amount", text: $bill, keyboard: .numberPad) }
                    previewBlock
                    PrimaryButton(title: "Review", enabled: hospital.count >= 2 && reason.count >= 2 && patient.count >= 2) { withAnimation { step = 2 } }
                    GhostButton(title: "Back") { withAnimation { step = 0 } }
                default:
                    Text("Confirm & consent").font(.title3.bold()).foregroundStyle(Color.csNavy)
                    CSCard {
                        VStack(spacing: 8) {
                            row("Type", cashless ? "Pre-auth (cashless)" : "Reimbursement")
                            row("Hospital", hospital)
                            row("Patient", patient)
                            row("Admission", admission)
                            row(cashless ? "Estimate" : "Bill", inr(cashless ? num(estimate) : (num(bill) ?? num(estimate))))
                        }
                    }
                    previewBlock
                    if created == nil {
                        Text("Enter the consent OTP (demo: \(templates?.consentOtp ?? "111000"))").font(.footnote).foregroundStyle(Color.csSecondary)
                        OtpBoxes(value: $otp)
                        PrimaryButton(title: "Submit claim", busy: app.busy, enabled: otp.count == 6) {
                            app.run {
                                let claim = try await API.shared.createClaim(claimBody())
                                created = claim
                            }
                        }
                        GhostButton(title: "Edit details") { withAnimation { step = 1 } }
                    }
                    if let created {
                        CSCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("✅ \(created.claimNumber ?? "Claim") submitted").font(.headline).foregroundStyle(Color.csSuccess)
                                WarningList(warnings: (created.warnings ?? []).filter { $0.severity != "info" })
                                NavigationLink("Upload documents") { ChecklistView(claimId: created.id) }
                                NavigationLink("Track claim") { TrackingView(claimId: created.id) }
                            }
                        }
                    }
                }
                if let error = app.error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Start a claim")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let p = try? API.shared.policies()
            async let t = try? API.shared.templates()
            policies = await p ?? []
            templates = await t
            policyId = templates?.policyId ?? policies.first?.id ?? ""
            if patient.isEmpty { patient = app.user?.name ?? "" }
        }
        .task(id: previewKey) {
            guard !policyId.isEmpty, num(estimate) != nil || num(bill) != nil || num(roomRent) != nil else { preview = nil; return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            preview = try? await API.shared.preview(PreviewBody(policyId: policyId, type: cashless ? "PREAUTH" : "REIMBURSEMENT", estimatedAmount: num(estimate), billAmount: cashless ? nil : num(bill), roomRentPerDay: num(roomRent), days: num(days), reason: reason.isEmpty ? nil : reason, treatment: treatment.isEmpty ? nil : treatment, admissionDate: admission.isEmpty ? nil : admission))
        }
    }

    @ViewBuilder private var previewBlock: some View {
        if let preview {
            WarningList(warnings: preview.warnings ?? [])
            if let e = preview.estimate {
                Text("You may get \(inr(e.approvedAmount)) · you pay about \(inr(e.outOfPocket)) · cover left \(inr(preview.remainingSumInsured))")
                    .font(.footnote.bold()).foregroundStyle(Color.csNavy)
            }
        }
    }
    private func useSample() {
        guard let t = cashless ? templates?.preauth : templates?.reimbursement else { return }
        if let id = t.policyId { policyId = id }
        hospital = t.hospital ?? ""; city = t.hospitalCity ?? ""; reason = t.reason ?? ""; treatment = t.treatment ?? ""
        patient = t.patientName ?? patient; admission = t.admissionDate ?? ""; discharge = t.dischargeDate ?? ""
        days = t.days.map(String.init) ?? ""; roomRent = t.roomRentPerDay.map(String.init) ?? ""
        estimate = t.estimatedAmount.map(String.init) ?? ""; bill = t.billAmount.map(String.init) ?? ""
        details = t.patientDetails; network = t.isNetworkHospital; roomType = t.roomType
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Color.csSecondary); Spacer(); Text(v).foregroundStyle(Color.csNavy).bold() }
    }
    private func claimBody() -> CreateClaimBody {
        CreateClaimBody(policyId: policyId, type: cashless ? "PREAUTH" : "REIMBURSEMENT", hospital: hospital, hospitalCity: city.isEmpty ? nil : city, isNetworkHospital: network,
                        reason: reason, treatment: treatment.isEmpty ? nil : treatment, admissionType: cashless ? "PLANNED" : "EMERGENCY",
                        admissionDate: admission.isEmpty ? nil : admission, dischargeDate: cashless || discharge.isEmpty ? nil : discharge,
                        days: num(days), roomType: roomType, roomRentPerDay: num(roomRent),
                        billAmount: cashless ? nil : num(bill), estimatedAmount: num(estimate), patientName: patient, patientDetails: details, consentOtp: otp)
    }
}

private struct ChecklistView: View {
    @Environment(AppState.self) private var app
    let claimId: String
    @State private var list: Checklist?
    @State private var picking: DocumentType?
    @State private var showChooser = false
    var body: some View {
        ZStack {
            List {
                if list == nil {
                    ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 8).fill(Color.csPale).frame(height: 36).modifier(Shimmer()) }
                }
                if let progress = list?.progress {
                    UploadProgressBar(done: progress.verified ?? 0, total: progress.required ?? 0).padding(.vertical, 4)
                }
                if let next = list?.items?.first(where: { $0.status != .verified }) {
                    SaathiTip(text: "Next up: \(next.label ?? "document"). Tap it to take a photo or pick a file — I’ll check it instantly.\(next.fix.map { " Tip: \($0)" } ?? "")")
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } else if list?.items?.isEmpty == false {
                    SaathiTip(text: "All documents verified. The claims team is reviewing — you’ll get an alert for any query.")
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                ForEach(list?.warnings ?? [], id: \.self) { Text($0).foregroundStyle(Color.csWarning) }
                ForEach(list?.items ?? []) { item in
                    Button { picking = item.type; showChooser = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.status == .verified ? "checkmark.circle.fill" : item.status == .rejected ? "xmark.octagon.fill" : item.status == .uploaded ? "clock.fill" : "arrow.up.doc")
                                .foregroundStyle(item.status == .verified ? Color.csSuccess : item.status == .rejected ? Color.csError : item.status == .uploaded ? Color.csWarning : Color.csCyan)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text(item.label ?? "").foregroundStyle(Color.csNavy).bold()
                                if let file = item.fileName { Text(file).font(.caption).foregroundStyle(Color.csSecondary) }
                            }
                            Spacer()
                            StatusBadge(title: item.status?.rawValue ?? "", tint: item.status == .verified ? .csSuccess : item.status == .rejected ? .csError : item.status == .uploaded ? .csWarning : .csSecondary)
                        }
                    }
                }
                if let upload = app.lastUpload {
                    Text("Last upload: \(pretty(upload.validation?.appStatus?.rawValue ?? "uploaded"))\(upload.validation?.fix.map { " · \($0)" } ?? "")").font(.footnote).foregroundStyle(upload.validation?.appStatus == .verified ? Color.csSuccess : Color.csWarning)
                    NavigationLink("See validation") { ValidationView(upload: upload) }
                }
                if let error = app.error { Text(error).foregroundStyle(Color.csError) }
            }
            if app.busy {
                Color.csNavy.opacity(0.35).ignoresSafeArea()
                CSCard {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Validating document…").bold().foregroundStyle(Color.csNavy)
                    }.frame(maxWidth: .infinity)
                }.padding(40)
            }
        }
        .navigationTitle("Documents")
        .saathiFab(prompt: "What documents are missing for my claim?", claimId: claimId)
        .documentSource(isPresented: $showChooser, name: picking?.rawValue.lowercased() ?? "document", onPick: { file in
            let type = picking?.rawValue
            app.run {
                app.lastUpload = try await API.shared.upload(claimId: claimId, bytes: file.data, filename: file.filename, mime: file.mime, type: type)
                list = try await API.shared.checklist(claimId)
            }
        }, onError: { app.error = $0 })
        .task { while !Task.isCancelled { if let l = try? await API.shared.checklist(claimId) { list = l }; try? await Task.sleep(for: .seconds(6)) } }
    }
}

private struct ValidationView: View {
    let upload: UploadResponse
    var body: some View {
        List {
            Text(upload.validation?.summary ?? pretty(upload.validation?.appStatus?.rawValue ?? "Validation")).font(.headline)
            ForEach(upload.validation?.checks ?? []) { check in
                HStack(alignment: .top) {
                    Image(systemName: check.passed == true ? "checkmark.circle.fill" : check.passed == false ? "xmark.circle.fill" : "minus.circle")
                        .foregroundStyle(check.passed == true ? Color.csSuccess : check.passed == false ? Color.csError : Color.csSecondary)
                    VStack(alignment: .leading) {
                        Text(check.label ?? "").bold()
                        Text(check.detail ?? "").font(.footnote).foregroundStyle(Color.csSecondary)
                    }
                }
            }
            ForEach(upload.validation?.warnings ?? [], id: \.self) { Text($0).foregroundStyle(Color.csWarning) }
        }.navigationTitle("Validation")
    }
}

private struct ClaimsTab: View {
    @State private var claims: [Claim] = []
    @State private var filter: String?
    @State private var error: String?
    @State private var loaded = false
    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) {
                    Text("All").tag(String?.none)
                    Text("Action").tag(String?.some("QUERY_RAISED,DOCS_PENDING"))
                    Text("Settled").tag(String?.some("SETTLED"))
                }.pickerStyle(.segmented).listRowBackground(Color.clear)
                if !loaded {
                    ForEach(0..<3, id: \.self) { _ in SkeletonCard(lines: 2).listRowBackground(Color.clear).listRowSeparator(.hidden) }
                } else if claims.isEmpty && error == nil {
                    EmptyStateView(icon: "doc.text.magnifyingglass", title: "No claims here", message: "Start a claim from Home — it will show up here and update live.")
                        .listRowBackground(Color.clear)
                }
                ForEach(claims) { claim in
                    NavigationLink { TrackingView(claimId: claim.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(claim.claimNumber ?? "").foregroundStyle(Color.csCyan).bold(); if claim.isTemplate == true { StatusBadge(title: "Sample", tint: .csSecondary) }; Spacer(); StatusBadge(title: pretty(claim.status?.rawValue ?? ""), tint: statusTint(claim.status)) }
                            Text(claim.hospital ?? "")
                            Text("\(claim.claimType == .CASHLESS ? "Cashless pre-auth" : "Reimbursement") · \(claim.patientName ?? "")").font(.caption).foregroundStyle(Color.csSecondary)
                            Text(inr(claim.billAmount ?? claim.estimatedAmount)).font(.headline).foregroundStyle(Color.csNavy)
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(Color.csError) }
            }
            .navigationTitle("Claims")
            .task(id: filter) { do { claims = try await API.shared.claims(status: filter); error = nil } catch { self.error = error.localizedDescription }; loaded = true }
            .refreshable { claims = (try? await API.shared.claims(status: filter)) ?? claims }
        }
    }
}

private struct TrackingView: View {
    let claimId: String
    @State private var timeline: Timeline?
    @State private var detail: Claim?
    @State private var error: String?
    private func stepColor(_ state: StepState?) -> Color {
        switch state {
        case .done: .csSuccess
        case .current: .csCyan
        case .failed: .csError
        default: .csPale
        }
    }
    private var trackingTip: String? {
        switch timeline?.status ?? detail?.status {
        case .DOCS_PENDING, .CREATED, .PREAUTH_SUBMITTED: "Upload your documents one by one — each is verified instantly and the details fill in automatically."
        case .UNDER_REVIEW, .NEEDS_HUMAN: "Your claim is with the claims team. If they need anything, you’ll get a query alert here."
        case .QUERY_RAISED: "The insurer has a question. Tap the query below and reply with the requested file to keep things moving."
        case .APPROVED: "Approved! Settlement is being processed — open Settlement to see every deduction explained."
        case .SETTLED: "Paid. Open Settlement to see exactly why each amount was deducted."
        case .REJECTED: "This claim was rejected. Ask Saathi to explain why and what you can do next."
        default: nil
        }
    }
    var body: some View {
        List {
            if let d = detail {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(d.hospital ?? "").font(.headline).foregroundStyle(Color.csNavy); Spacer(); StatusBadge(title: pretty(d.status?.rawValue ?? ""), tint: statusTint(d.status)) }
                    Text("\(d.claimType == .CASHLESS ? "Cashless pre-auth" : "Reimbursement") · \(d.patientName ?? "") · \(d.reason ?? "")").font(.footnote).foregroundStyle(Color.csSecondary)
                    Text("Bill \(inr(d.billAmount)) · Estimate \(inr(d.estimatedAmount))").font(.footnote).foregroundStyle(Color.csNavy)
                }
                if !(d.warnings ?? []).isEmpty { WarningList(warnings: d.warnings ?? []).listRowBackground(Color.clear) }
            }
            if let update = timeline?.latestOpsUpdate?.message {
                CSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LATEST UPDATE").font(.caption.bold()).foregroundStyle(Color.csCyan)
                        Text(update).foregroundStyle(Color.csNavy)
                    }
                }.listRowBackground(Color.clear)
            }
            if timeline == nil && error == nil {
                SkeletonCard(lines: 4).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if let tip = trackingTip {
                SaathiTip(text: tip).listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if let steps = timeline?.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PROGRESS").font(.caption.bold()).foregroundStyle(Color.csCyan).padding(.bottom, 10)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle().fill(stepColor(step.state)).frame(width: 22, height: 22)
                                    Image(systemName: step.state == .done ? "checkmark" : step.state == .failed ? "xmark" : step.state == .current ? "circle.fill" : "circle")
                                        .font(.system(size: step.state == .current ? 7 : 10, weight: .bold)).foregroundStyle(.white)
                                }
                                if index < steps.count - 1 {
                                    Rectangle().fill(step.state == .done ? Color.csSuccess : Color.csPale).frame(width: 2).frame(minHeight: 22)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.label ?? "").font(.subheadline.weight(step.state == .current ? .bold : .semibold))
                                    .foregroundStyle(step.state == .pending ? Color.csSecondary : Color.csNavy)
                                if let note = step.note { Text(note).font(.caption).foregroundStyle(Color.csSecondary) }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            ForEach(timeline?.openQueries ?? []) { q in
                NavigationLink { QueryDetailView(queryId: q.id) } label: { Text("Reply: \(q.message ?? "Query")").foregroundStyle(Color.csWarning) }
            }
            NavigationLink("All queries") { QueriesView() }
            NavigationLink("Upload documents") { ChecklistView(claimId: claimId) }
            NavigationLink("Settlement") { SettlementView(claimId: claimId) }
            if let error { Text(error).foregroundStyle(Color.csError) }
        }
        .navigationTitle(timeline?.claimNumber ?? "Claim")
        .saathiFab(prompt: "Track my claim and explain the next step", claimId: claimId)
        .task { while !Task.isCancelled { do { timeline = try await API.shared.timeline(claimId); detail = try await API.shared.claim(claimId); error = nil } catch { self.error = error.localizedDescription }; try? await Task.sleep(for: .seconds(5)) } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Link("PDF", destination: API.shared.summaryPdfURL(claimId)) } }
    }
}

private struct QueriesView: View {
    @State private var items: [Query] = []
    var body: some View {
        List(items) { query in
            NavigationLink { QueryDetailView(queryId: query.id) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(query.claim?.claimNumber ?? "Query").foregroundStyle(Color.csCyan).bold()
                    Text(query.message ?? "")
                }
            }
        }
        .navigationTitle("Queries")
        .task { items = (try? await API.shared.queries()) ?? [] }
    }
}

private struct QueryDetailView: View {
    @Environment(AppState.self) private var app
    let queryId: String
    @State private var explain = ""
    @State private var reply = ""
    @State private var status = ""
    @State private var checks: [ValidationCheck] = []
    @State private var showFiles = false
    var body: some View {
        Form {
            if !explain.isEmpty { Text(explain) }
            FieldBox(title: "Reply", text: $reply)
            PrimaryButton(title: "Send reply", busy: app.busy) {
                app.run {
                    let result = try await API.shared.respond(queryId: queryId, text: reply.isEmpty ? "Replied from the app" : reply, bytes: nil, filename: nil, mime: nil, type: nil)
                    status = result.status == .CLOSED ? "Query resolved ✓" : "Sent to the claims team"
                    checks = result.document?.validation?.checks ?? []
                }
            }
            GhostButton(title: "Attach file / photo and send") { showFiles = true }
            if !status.isEmpty { Text(status).foregroundStyle(Color.csSuccess) }
            ForEach(checks) { Text("\($0.label ?? ""): \($0.detail ?? "")").font(.footnote) }
            if let error = app.error { Text(error).foregroundStyle(Color.csError) }
        }
        .navigationTitle("Query")
        .task { explain = (try? await API.shared.explainQuery(queryId).explanation) ?? "" }
        .documentSource(isPresented: $showFiles, name: "query-reply", onPick: { file in
            app.run {
                let answered = try await API.shared.respond(queryId: queryId, text: reply.isEmpty ? "Uploaded the requested file" : reply, bytes: file.data, filename: file.filename, mime: file.mime, type: nil)
                status = answered.status == .CLOSED ? "Query resolved ✓" : "Sent to the claims team"
                checks = answered.document?.validation?.checks ?? []
            }
        }, onError: { app.error = $0 })
    }
}

private struct AlertsTab: View {
    @Environment(AppState.self) private var app
    @State private var notes: [AppNotification] = []
    var body: some View {
        NavigationStack {
            List {
                Button("Mark all read") { app.run { try await API.shared.markAllRead(); notes = try await API.shared.notifications().items } }
                if notes.isEmpty {
                    EmptyStateView(icon: "bell.badge", title: "No alerts yet", message: "Claim updates in English & Hindi will appear here live.").listRowBackground(Color.clear)
                }
                ForEach(notes) { note in
                    Button {
                        app.run {
                            try await API.shared.markRead(note.id)
                            notes = try await API.shared.notifications().items
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.type == .WARNING ? "exclamationmark.triangle.fill" : note.type == .SUCCESS ? "checkmark.seal.fill" : note.type == .ACTION_REQUIRED ? "hand.raised.fill" : "info.circle.fill")
                                .foregroundStyle(note.type == .WARNING ? Color.csWarning : note.type == .SUCCESS ? Color.csSuccess : note.type == .ACTION_REQUIRED ? Color.csError : Color.csCyan)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title ?? "").font(.headline).foregroundStyle(Color.csNavy)
                                Text(note.body ?? "").font(.footnote).foregroundStyle(Color.csSecondary)
                                Text("\(note.claim?.claimNumber ?? "") \(shortDate(note.createdAt))").font(.caption2).foregroundStyle(Color.csSecondary)
                            }
                            Spacer()
                            if note.read != true { Circle().fill(Color.csCyan).frame(width: 8, height: 8) }
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .task { while !Task.isCancelled { notes = (try? await API.shared.notifications().items) ?? []; try? await Task.sleep(for: .seconds(5)) } }
        }
    }
}

private struct ProfileEditView: View {
    @Environment(AppState.self) private var app
    @State private var name = ""
    @State private var city = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        FieldBox(title: "Name", text: $name)
                        FieldBox(title: "City", text: $city)
                        PrimaryButton(title: "Save profile", busy: app.busy) {
                            app.run {
                                let res = try await API.shared.patchProfile(ProfilePatch(name: name, city: city))
                                TokenStore.token = res.token
                                app.user = res.user
                            }
                        }
                    }
                }
                if let error = app.error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = app.user?.name ?? ""; city = app.user?.city ?? "" }
    }
}

private struct ProfileTab: View {
    @Environment(AppState.self) private var app
    @State private var name = ""
    @State private var city = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NavyHero(app.user?.name ?? "Profile", app.user?.phone ?? app.user?.email ?? "")
                    CSCard {
                        VStack(alignment: .leading, spacing: 12) {
                            FieldBox(title: "Name", text: $name)
                            FieldBox(title: "City", text: $city)
                            PrimaryButton(title: "Save profile", busy: app.busy) {
                                app.run {
                                    let res = try await API.shared.patchProfile(ProfilePatch(name: name, city: city))
                                    TokenStore.token = res.token
                                    app.user = res.user
                                }
                            }
                        }
                    }
                    NavigationLink { BankView() } label: { ActionTile(icon: "building.columns.fill", title: "Bank account", subtitle: "For settlement payouts") }
                    NavigationLink { FinanceView() } label: { ActionTile(icon: "indianrupeesign.circle.fill", title: "Money", subtitle: "Balances, expenses, medical spend") }
                    GhostButton(title: "Log out") { app.logout() }
                    if let error = app.error { Text(error).foregroundStyle(Color.csError) }
                }.padding(16)
            }
            .background(Color.csBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { name = app.user?.name ?? ""; city = app.user?.city ?? "" }
        }
    }
}

private struct BankView: View {
    @Environment(AppState.self) private var app
    @State private var holder = ""
    @State private var account = ""
    @State private var ifsc = ""
    @State private var bank = ""
    @State private var saved = false
    @State private var current: BankMasked?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let current {
                    CSCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PAYOUT ACCOUNT").font(.caption.bold()).foregroundStyle(Color.csCyan)
                            Text("\(current.bankName ?? "Bank") \(current.accountNumberMasked ?? "")").font(.headline).foregroundStyle(Color.csNavy)
                            Text("\(current.accountName ?? "") · \(current.ifsc ?? "")\(current.verified == true ? " · verified ✓" : "")").font(.footnote).foregroundStyle(Color.csSecondary)
                        }
                    }
                }
                NavigationLink { FinanceView() } label: { ActionTile(icon: "indianrupeesign.circle.fill", title: "Money overview", subtitle: "Balances, expenses, payouts") }
                Text("Update payout account").font(.headline).foregroundStyle(Color.csNavy)
                FieldBox(title: "Account name", text: $holder)
                FieldBox(title: "Account number", text: $account, keyboard: .numberPad)
                FieldBox(title: "IFSC", text: $ifsc)
                    .onChange(of: ifsc) { _, next in ifsc = next.uppercased() }
                FieldBox(title: "Bank", text: $bank)
                PrimaryButton(title: "Save with OTP 111000", busy: app.busy) {
                    app.run {
                        current = try await API.shared.saveBank(BankBody(accountName: holder, accountNumber: account, ifsc: ifsc, bankName: bank.isEmpty ? nil : bank, otp: "111000")).bank
                        saved = true
                    }
                }
                if saved { Text("Saved. The number is stored masked.").foregroundStyle(Color.csSuccess) }
                if let error = app.error { Text(error).foregroundStyle(Color.csError) }
            }.padding(16)
        }
        .background(Color.csBackground)
        .navigationTitle("Bank")
        .onAppear { if holder.isEmpty { holder = app.user?.name ?? "" } }
        .task { current = try? await API.shared.bank().bank }
    }
}

private struct SettlementView: View {
    let claimId: String
    @State private var settlement: Settlement?
    @State private var error: String?
    var body: some View {
        List {
            if settlement?.preview == true { Text("Estimate. Final amount after approval.").foregroundStyle(Color.csWarning) }
            if settlement?.isDemo == true { StatusBadge(title: "Demo settlement", tint: .csWarning) }
            Text("Bill \(inr(settlement?.billAmount))")
            ForEach(settlement?.deductions ?? [], id: \.label) { line in
                VStack(alignment: .leading) {
                    Text("\(line.label ?? "")  − \(inr(line.amount))")
                    if let reason = line.reason { Text(reason).font(.footnote).foregroundStyle(Color.csSecondary) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(settlement?.status == .PAID ? "PAID TO YOUR ACCOUNT" : "APPROVED AMOUNT").font(.caption.bold()).foregroundStyle(Color.csSuccess)
                Text(inr(settlement?.approvedAmount)).font(.system(size: 32, weight: .bold)).foregroundStyle(Color.csSuccess)
                Text("Approved \(inr(settlement?.approvedAmount)) of \(inr(settlement?.billAmount)) bill").font(.caption).foregroundStyle(Color.csSecondary)
            }.padding(.vertical, 4)
            if let status = settlement?.status { StatusBadge(title: pretty(status.rawValue), tint: status == .PAID ? .csSuccess : .csWarning) }
            if let explanation = settlement?.explanation { Text(explanation).font(.footnote).foregroundStyle(Color.csSecondary) }
            if let utr = settlement?.utr { Text("UTR \(utr)\(settlement?.paidAt.map { " · paid \(shortDate($0))" } ?? "")") }
            Link("Summary PDF", destination: API.shared.summaryPdfURL(claimId))
            if let error { Text(error).foregroundStyle(Color.csError) }
        }
        .navigationTitle("Settlement")
        .saathiFab(prompt: "Explain the deductions in my settlement", claimId: claimId)
        .task { do { settlement = try await API.shared.settlement(claimId) } catch { self.error = error.localizedDescription } }
    }
}
