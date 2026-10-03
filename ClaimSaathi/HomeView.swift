import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color.csBackground.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer(minLength: 12)
                LogoMark()
                VStack(spacing: 8) {
                    Text("Claim Saathi")
                        .font(CSFont.title())
                        .foregroundStyle(Color.csNavy)
                    Text("Your AI health insurance claim companion")
                        .font(CSFont.body())
                        .foregroundStyle(Color.csSecondary)
                        .multilineTextAlignment(.center)
                    Text("Understand. Upload. Track. Get paid.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.csNavy)
                        .padding(.top, 4)
                }
                CSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DEMO LOGIN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.csCyan)
                        Text(model.userName)
                            .font(CSFont.cardTitle())
                            .foregroundStyle(Color.csText)
                        Text(model.email)
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                        Text("Customer · sample policy already loaded")
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csSecondary)
                    }
                }
                PrimaryButton(title: "Continue as Rajesh", systemImage: "arrow.right") {
                    model.login()
                }
                Text("Demo only. No real insurer, hospital, or payment is connected.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.csSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let claim = model.activeClaim, claim.query != nil {
                        actionBanner(claim)
                    }
                    if let claim = model.activeClaim {
                        activeClaimCard(claim)
                    }
                    quickActions
                    policyStrip
                    activity
                }
                .padding(20)
            }
            .background(Color.csBackground)
            .navigationDestination(for: String.self) { claimID in
                ClaimDetailView(claimID: claimID)
            }
            .navigationDestination(for: HomeLink.self) { link in
                switch link {
                case .policy:
                    PolicyView()
                case .startClaim:
                    StartClaimView()
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good morning")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                Text(model.userName)
                    .font(CSFont.screenTitle())
                    .foregroundStyle(Color.csNavy)
            }
            Spacer()
            Text(initials)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.csNavy)
                .frame(width: 44, height: 44)
                .background(Color.csPale)
                .clipShape(Circle())
        }
    }

    private var initials: String {
        model.userName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private func actionBanner(_ claim: Claim) -> some View {
        NavigationLink(value: claim.id) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.csWarning)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Action required")
                        .font(CSFont.cardTitle())
                        .foregroundStyle(Color.csText)
                    Text(claim.query ?? "A document is still needed.")
                        .font(CSFont.caption())
                        .foregroundStyle(Color.csSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.csSecondary)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(Color.csWarning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func activeClaimCard(_ claim: Claim) -> some View {
        CSCard(padding: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(claim.id)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.csCyan)
                    Spacer()
                    StatusBadge(title: claim.status.rawValue, tint: claim.status.tint)
                }
                Text(claim.hospital)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.csNavy)
                Text(claim.reason)
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                HStack {
                    Text(inr(claim.amount))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.csText)
                    Spacer()
                    Text(claim.updated)
                        .font(CSFont.caption())
                        .foregroundStyle(Color.csSecondary)
                }
                progress(claim)
                NavigationLink(value: claim.id) {
                    Text("Track claim")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.csNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private func progress(_ claim: Claim) -> some View {
        let done = claim.steps.filter { $0.state == .done }.count
        let total = max(claim.steps.count, 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                Spacer()
                Text("\(done) of \(total)")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csNavy)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.csPale)
                    Capsule()
                        .fill(Color.csCyan)
                        .frame(width: proxy.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 8)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(CSFont.cardTitle())
                .foregroundStyle(Color.csNavy)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(value: HomeLink.policy) {
                    actionTile("Upload policy", "doc.badge.plus", Color.csCyan)
                }
                .buttonStyle(.plain)
                NavigationLink(value: HomeLink.startClaim) {
                    actionTile("Start claim", "plus.rectangle.on.rectangle", Color.csNavy)
                }
                .buttonStyle(.plain)
                Button {
                    model.tab = .docs
                } label: {
                    actionTile("Documents", "checklist", Color.csSuccess)
                }
                .buttonStyle(.plain)
                Button {
                    model.tab = .assistant
                } label: {
                    actionTile("Ask Saathi", "sparkles", Color.csWarning)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionTile(_ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.csText)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.csNavy.opacity(0.05), radius: 10, y: 4)
    }

    private var policyStrip: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your policy")
                        .font(CSFont.cardTitle())
                        .foregroundStyle(Color.csNavy)
                    Spacer()
                    NavigationLink(value: HomeLink.policy) {
                        Text("View")
                            .font(CSFont.caption())
                            .foregroundStyle(Color.csCyan)
                    }
                }
                Text("\(model.policy.insurer) · \(model.policy.number)")
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
                HStack(spacing: 12) {
                    metric("Sum insured", inr(model.policy.sumInsured))
                    metric("Room rent", "\(inr(model.policy.roomRentPerDay))/day")
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.csSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.csText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.csPale)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(CSFont.cardTitle())
                .foregroundStyle(Color.csNavy)
            CSCard {
                VStack(alignment: .leading, spacing: 14) {
                    activityRow("Query opened", "Payment receipt needed for CLM-1042", "Today")
                    Divider()
                    activityRow("Hospital bill verified", "Apollo bill matched the claim amount", "Yesterday")
                    Divider()
                    activityRow("Policy read", "Sum insured and room rent explained", "28 Sep")
                }
            }
        }
    }

    private func activityRow(_ title: String, _ detail: String, _ time: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.csText)
                Text(detail)
                    .font(CSFont.caption())
                    .foregroundStyle(Color.csSecondary)
            }
            Spacer()
            Text(time)
                .font(.system(size: 12))
                .foregroundStyle(Color.csSecondary)
        }
    }
}

enum HomeLink: Hashable {
    case policy
    case startClaim
}
