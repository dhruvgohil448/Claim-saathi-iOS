import SwiftUI

struct ClaimsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Claims", subtitle: "Track every step from submission to settlement.")
                    ForEach(model.claims) { claim in
                        NavigationLink(value: claim.id) {
                            claimRow(claim)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color.csBackground)
            .navigationDestination(for: String.self) { claimID in
                ClaimDetailView(claimID: claimID)
            }
        }
    }

    private func claimRow(_ claim: Claim) -> some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(claim.id)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.csCyan)
                    Spacer()
                    StatusBadge(title: claim.status.rawValue, tint: claim.status.tint)
                }
                Text(claim.hospital)
                    .font(CSFont.cardTitle())
                    .foregroundStyle(Color.csNavy)
                Text(claim.reason)
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                HStack {
                    Text(inr(claim.amount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.csText)
                    Spacer()
                    Text(claim.updated)
                        .font(CSFont.caption())
                        .foregroundStyle(Color.csSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.csSecondary)
                }
            }
        }
    }
}

struct ClaimDetailView: View {
    @EnvironmentObject private var model: AppModel
    let claimID: String
    @State private var reply = ""

    private var claim: Claim? {
        model.claims.first { $0.id == claimID }
    }

    var body: some View {
        ScrollView {
            if let claim {
                VStack(alignment: .leading, spacing: 16) {
                    header(claim)
                    timeline(claim)
                    if claim.query != nil {
                        queryCard(claim)
                    }
                    if claim.settlement != nil {
                        NavigationLink {
                            SettlementView(claimID: claim.id)
                        } label: {
                            Text("View settlement")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.csNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Advance demo status") {
                        model.advance(claim.id)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.csSecondary)
                    .frame(maxWidth: .infinity)
                    if let notice = model.notice {
                        Text(notice)
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.csBackground)
        .navigationTitle(claimID)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ claim: Claim) -> some View {
        CSCard {
            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(title: claim.status.rawValue, tint: claim.status.tint)
                Text(claim.hospital)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.csNavy)
                Text(claim.reason)
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                Text(inr(claim.amount))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.csText)
                Text("Updated \(claim.updated)")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
            }
        }
    }

    private func timeline(_ claim: Claim) -> some View {
        CSCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Timeline")
                    .font(CSFont.cardTitle())
                    .foregroundStyle(Color.csNavy)
                    .padding(.bottom, 12)
                ForEach(Array(claim.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(marker(step.state))
                                .frame(width: 14, height: 14)
                            if index < claim.steps.count - 1 {
                                Rectangle()
                                    .fill(step.state == .done ? Color.csSuccess : Color.csPale)
                                    .frame(width: 2, height: 42)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(step.state == .upcoming ? Color.csSecondary : Color.csText)
                            Text(step.detail)
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csSecondary)
                        }
                        .padding(.bottom, 12)
                        Spacer()
                    }
                }
            }
        }
    }

    private func marker(_ state: StepState) -> Color {
        switch state {
        case .done: return .csSuccess
        case .current: return .csCyan
        case .upcoming: return .csPale
        }
    }

    private func queryCard(_ claim: Claim) -> some View {
        CSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Insurer query")
                    .font(CSFont.cardTitle())
                    .foregroundStyle(Color.csNavy)
                Text(claim.query ?? "")
                    .font(CSFont.body())
                    .foregroundStyle(Color.csText)
                Text("Reply in plain language. This stays inside the demo.")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                TextField("I uploaded the receipt", text: $reply, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.csBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                PrimaryButton(title: "Send reply") {
                    model.replyToQuery(claimID: claim.id, message: reply)
                    reply = ""
                }
            }
        }
    }
}

struct SettlementView: View {
    @EnvironmentObject private var model: AppModel
    let claimID: String

    private var claim: Claim? { model.claims.first { $0.id == claimID } }

    var body: some View {
        ScrollView {
            if let claim, let settlement = claim.settlement {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Settlement", subtitle: "Every figure below is sample demo data.")
                    CSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Approved amount")
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csSecondary)
                            Text(inr(settlement.approvedAmount))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.csSuccess)
                            Text(claim.hospital)
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csSecondary)
                        }
                    }
                    CSCard {
                        VStack(spacing: 12) {
                            amountRow("Hospital bill", inr(settlement.billAmount), Color.csText)
                            ForEach(settlement.lines) { line in
                                VStack(alignment: .leading, spacing: 4) {
                                    amountRow(line.title, "− \(inr(line.amount))", Color.csError)
                                    Text(line.reason)
                                        .font(CSFont.caption())
                                        .foregroundStyle(Color.csSecondary)
                                }
                            }
                            Divider()
                            amountRow("You receive", inr(settlement.approvedAmount), Color.csSuccess)
                        }
                    }
                    Text("Deductions follow the sample policy: non-payables, the ₹5,000 room-rent cap, and 10% co-pay. This is not a real payout.")
                        .font(CSFont.caption())
                        .foregroundStyle(Color.csSecondary)
                }
                .padding(20)
            }
        }
        .background(Color.csBackground)
        .navigationTitle("Settlement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func amountRow(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.csText)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
        }
    }
}
