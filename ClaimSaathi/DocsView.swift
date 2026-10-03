import SwiftUI

struct DocsView: View {
    @EnvironmentObject private var model: AppModel

    private var ready: Int { model.documents.filter { $0.status == .verified }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(
                        title: "Documents",
                        subtitle: "\(ready) of \(model.documents.count) verified. \(model.missingDocumentCount) still need attention."
                    )
                    progress
                    ForEach(model.documents) { document in
                        documentCard(document)
                    }
                    if let notice = model.notice {
                        Text(notice)
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color.csBackground)
        }
    }

    private var progress: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Checklist")
                    .font(CSFont.cardTitle())
                    .foregroundStyle(Color.csNavy)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.csPale)
                        Capsule()
                            .fill(Color.csSuccess)
                            .frame(width: proxy.size.width * CGFloat(ready) / CGFloat(max(model.documents.count, 1)))
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func documentCard(_ document: ClaimDocument) -> some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(document.title)
                        .font(CSFont.cardTitle())
                        .foregroundStyle(Color.csText)
                    Spacer()
                    StatusBadge(title: document.status.rawValue, tint: document.status.tint)
                }
                if let fileName = document.fileName {
                    Text(fileName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.csNavy)
                }
                Text(document.note)
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                if document.status == .missing {
                    Button("Upload demo file") {
                        model.markUploaded(document.id)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.csNavy)
                    .padding(.top, 4)
                }
            }
        }
    }
}

struct PolicyView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Policy", subtitle: "Read from the sample Star Health PDF.")
                CSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ON FILE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.csSuccess)
                        Text("\(model.policy.insurer) \(model.policy.product)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.csNavy)
                        Text(model.policy.number)
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                        Text("Holder · \(model.policy.holder)")
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    infoTile("Sum insured", inr(model.policy.sumInsured))
                    infoTile("Room rent", "\(inr(model.policy.roomRentPerDay)) / day")
                    infoTile("Co-pay", model.policy.coPay)
                    infoTile("Network", "Demo hospital list")
                }
                CSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Waiting periods")
                            .font(CSFont.cardTitle())
                            .foregroundStyle(Color.csNavy)
                        ForEach(model.policy.waitingPeriods, id: \.self) { item in
                            Label(item, systemImage: "clock")
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csText)
                        }
                    }
                }
                CSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exclusions")
                            .font(CSFont.cardTitle())
                            .foregroundStyle(Color.csNavy)
                        ForEach(model.policy.exclusions, id: \.self) { item in
                            Label(item, systemImage: "xmark.circle")
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csText)
                        }
                    }
                }
                Text("If a rule is not in the sample document, the assistant says it was not found. It does not guess.")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                Button {
                    model.tab = .assistant
                } label: {
                    Text("Ask about this policy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.csNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.csBackground)
        .navigationTitle("Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.csSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.csNavy)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.csNavy.opacity(0.05), radius: 10, y: 4)
    }
}

struct StartClaimView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var hospital = ""
    @State private var reason = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Start a claim", subtitle: "Pre-authorisation preview. Nothing is sent to a hospital.")
                form
                preview
                if let error {
                    Text(error)
                        .font(CSFont.caption())
                        .foregroundStyle(Color.csError)
                }
                PrimaryButton(title: "Submit demo pre-auth") {
                    submit()
                }
                Text("Demo only. This does not contact an insurer or TPA.")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
            }
            .padding(20)
        }
        .background(Color.csBackground)
        .navigationTitle("New claim")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 12) {
                field("Hospital", text: $hospital, prompt: "Apollo Hospitals, Ahmedabad")
                field("Treatment", text: $reason, prompt: "Dengue admission")
                field("Estimated amount", text: $amount, prompt: "220000")
                    .keyboardType(.numberPad)
                DatePicker("Admission", selection: $date, displayedComponents: .date)
                    .font(CSFont.body())
                    .foregroundStyle(Color.csText)
                Button("Fill demo details") {
                    hospital = "Apollo Hospitals, Ahmedabad"
                    reason = "Planned dengue admission"
                    amount = "180000"
                    error = nil
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.csCyan)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CSFont.caption())
                .foregroundStyle(Color.csSecondary)
            TextField(prompt, text: text)
                .padding(12)
                .background(Color.csBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var preview: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pre-auth preview")
                    .font(CSFont.cardTitle())
                    .foregroundStyle(Color.csNavy)
                previewLine("Patient", model.userName)
                previewLine("Policy", model.policy.number)
                previewLine("Hospital", hospital.isEmpty ? "—" : hospital)
                previewLine("Reason", reason.isEmpty ? "—" : reason)
                previewLine("Estimate", amount.isEmpty ? "—" : inr(Int(amount) ?? 0))
            }
        }
    }

    private func previewLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(CSFont.caption())
                .foregroundStyle(Color.csSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.csText)
        }
    }

    private func submit() {
        let trimmedHospital = hospital.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHospital.isEmpty, !trimmedReason.isEmpty, let value = Int(amount), value > 0 else {
            error = "Add a hospital, a reason, and an amount."
            return
        }
        model.submitClaim(hospital: trimmedHospital, reason: trimmedReason, amount: value)
        model.tab = .claims
        dismiss()
    }
}
