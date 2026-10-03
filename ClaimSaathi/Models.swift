import SwiftUI

enum AppTab: Hashable {
    case home, claims, docs, assistant, profile
}

enum ClaimStatus: String, Hashable {
    case submitted = "Submitted"
    case docsVerified = "Docs verified"
    case underReview = "Under review"
    case actionRequired = "Action required"
    case approved = "Approved"
    case settled = "Settled"

    var tint: Color {
        switch self {
        case .submitted, .underReview: return .csCyan
        case .docsVerified, .approved, .settled: return .csSuccess
        case .actionRequired: return .csWarning
        }
    }
}

enum DocStatus: String {
    case verified = "Verified"
    case needsReview = "Needs review"
    case missing = "Missing"

    var tint: Color {
        switch self {
        case .verified: return .csSuccess
        case .needsReview: return .csWarning
        case .missing: return .csError
        }
    }
}

enum StepState {
    case done, current, upcoming
}

struct TimelineStep: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    var state: StepState
}

struct ClaimDocument: Identifiable, Hashable {
    let id: String
    let title: String
    var fileName: String?
    var status: DocStatus
    var note: String
}

struct DeductionLine: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let amount: Int
    let reason: String
}

struct Settlement: Hashable {
    let billAmount: Int
    let lines: [DeductionLine]
    let approvedAmount: Int
    var deductions: Int { lines.reduce(0) { $0 + $1.amount } }
}

struct Claim: Identifiable, Hashable {
    let id: String
    let hospital: String
    let reason: String
    let amount: Int
    var status: ClaimStatus
    let updated: String
    var steps: [TimelineStep]
    var query: String?
    var settlement: Settlement?
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

struct PolicySummary {
    let insurer = "Star Health"
    let product = "Family Health Optima"
    let number = "POL-88421"
    let holder = "Rajesh Sharma"
    let sumInsured = 500_000
    let roomRentPerDay = 5_000
    let coPay = "10%"
    let waitingPeriods = [
        "Initial waiting period: 30 days",
        "Pre-existing conditions: 2 years",
        "Specific illnesses: 1 year"
    ]
    let exclusions = [
        "Cosmetic treatment",
        "Dental care, unless caused by an accident",
        "Items listed as non-payable consumables"
    ]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var tab: AppTab = .home
    @Published var claims: [Claim]
    @Published var documents: [ClaimDocument]
    @Published var messages: [ChatMessage]
    @Published var notice: String?

    let userName = "Rajesh Sharma"
    let email = "customer@claimsaathi.demo"
    let phone = "+91 98765 43210"
    let policy = PolicySummary()

    init() {
        claims = Self.seedClaims()
        documents = Self.seedDocuments()
        messages = [
            ChatMessage(
                isUser: false,
                text: "Hi Rajesh. I read your Star Health policy. Sum insured is ₹5,00,000 and room rent is capped at ₹5,000 a day. Ask me about coverage, documents, or claim CLM-1042."
            )
        ]
    }

    var activeClaim: Claim? {
        claims.first { $0.status != .settled } ?? claims.first
    }

    var missingDocumentCount: Int {
        documents.filter { $0.status != .verified }.count
    }

    func login() {
        isLoggedIn = true
        tab = .home
    }

    func logout() {
        isLoggedIn = false
    }

    func markUploaded(_ documentID: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        documents[index].status = .needsReview
        documents[index].fileName = "Upload_\(documentID).pdf"
        documents[index].note = "Uploaded in the demo. Waiting for a check."
        notice = "\(documents[index].title) uploaded. Demo only."
    }

    func replyToQuery(claimID: String, message: String) {
        guard let index = claims.firstIndex(where: { $0.id == claimID }) else { return }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        claims[index].query = nil
        claims[index].status = .underReview
        if let stepIndex = claims[index].steps.firstIndex(where: { $0.state == .current }) {
            claims[index].steps[stepIndex].state = .done
            claims[index].steps[stepIndex] = TimelineStep(
                title: "Query resolved",
                detail: "You replied: \(trimmed)",
                state: .done
            )
            let next = claims[index].steps.index(after: stepIndex)
            if next < claims[index].steps.endIndex, claims[index].steps[next].state == .upcoming {
                let upcoming = claims[index].steps[next]
                claims[index].steps[next] = TimelineStep(title: upcoming.title, detail: upcoming.detail, state: .current)
            }
        }
        notice = "Reply sent. A person reviews this only in the demo."
    }

    func advance(_ claimID: String) {
        guard let index = claims.firstIndex(where: { $0.id == claimID }) else { return }
        guard let current = claims[index].steps.firstIndex(where: { $0.state == .current }) else { return }
        let currentStep = claims[index].steps[current]
        claims[index].steps[current] = TimelineStep(title: currentStep.title, detail: currentStep.detail, state: .done)
        let next = claims[index].steps.index(after: current)
        if next < claims[index].steps.endIndex {
            let upcoming = claims[index].steps[next]
            claims[index].steps[next] = TimelineStep(title: upcoming.title, detail: "Updated in the demo.", state: .current)
            claims[index].status = status(for: upcoming.title)
        } else {
            claims[index].status = .settled
        }
        notice = "Status moved forward. This is sample data."
    }

    func submitClaim(hospital: String, reason: String, amount: Int) {
        let id = "CLM-\(Int.random(in: 2000...8999))"
        let claim = Claim(
            id: id,
            hospital: hospital,
            reason: reason,
            amount: amount,
            status: .submitted,
            updated: "Just now",
            steps: [
                TimelineStep(title: "Submitted", detail: "Demo pre-auth created.", state: .current),
                TimelineStep(title: "Docs verified", detail: "Waiting for documents.", state: .upcoming),
                TimelineStep(title: "Under review", detail: "Not started.", state: .upcoming),
                TimelineStep(title: "Approved", detail: "Not started.", state: .upcoming),
                TimelineStep(title: "Settled", detail: "Not started.", state: .upcoming)
            ],
            query: nil,
            settlement: nil
        )
        claims.insert(claim, at: 0)
        notice = "\(id) submitted as a demo. No insurer received it."
    }

    func ask(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(isUser: true, text: trimmed))
        messages.append(ChatMessage(isUser: false, text: answer(for: trimmed)))
    }

    private func answer(for text: String) -> String {
        let query = text.lowercased()
        if query.contains("room") {
            return "Room rent is capped at ₹5,000 per day on policy \(policy.number). A higher room tariff is deducted in the settlement."
        }
        if query.contains("cover") || query.contains("policy") || query.contains("sum") || query.contains("wait") || query.contains("exclu") {
            return "\(policy.insurer) \(policy.product), \(policy.number). Sum insured \(inr(policy.sumInsured)). Co-pay \(policy.coPay). \(policy.waitingPeriods.joined(separator: ". ")). Excluded: \(policy.exclusions.joined(separator: "; "))."
        }
        if query.contains("document") || query.contains("missing") || query.contains("upload") {
            let pending = documents.filter { $0.status != .verified }
            if pending.isEmpty {
                return "Every required document is verified."
            }
            let lines = pending.map { "\($0.title): \($0.status.rawValue). \($0.note)" }
            return lines.joined(separator: " ")
        }
        if query.contains("status") || query.contains("claim") || query.contains("track") {
            guard let claim = activeClaim else { return "There is no active claim in this demo." }
            return "\(claim.id) at \(claim.hospital) is \(claim.status.rawValue.lowercased()). Amount \(inr(claim.amount)). \(claim.query ?? "No open query.")"
        }
        if query.contains("deduct") || query.contains("settle") || query.contains("why") || query.contains("amount") {
            guard let settlement = claims.first(where: { $0.settlement != nil })?.settlement else {
                return "A settlement breakdown is not ready for the newest claim."
            }
            let reasons = settlement.lines.map { "\($0.title) \(inr($0.amount)): \($0.reason)" }.joined(separator: " ")
            return "Sample bill \(inr(settlement.billAmount)). Deductions \(inr(settlement.deductions)). Approved \(inr(settlement.approvedAmount)). \(reasons) These figures are demo data."
        }
        return "I can explain this demo policy, the room-rent limit, missing documents, claim status, and why an amount was deducted. If something is not in the sample policy, check it with the insurer."
    }

    private func status(for stepTitle: String) -> ClaimStatus {
        switch stepTitle {
        case "Docs verified": return .docsVerified
        case "Under review": return .underReview
        case "Query", "Action required": return .actionRequired
        case "Approved": return .approved
        case "Settled": return .settled
        default: return .submitted
        }
    }

    private static func seedClaims() -> [Claim] {
        [
            Claim(
                id: "CLM-1042",
                hospital: "Apollo Hospitals, Ahmedabad",
                reason: "Dengue admission",
                amount: 220_000,
                status: .actionRequired,
                updated: "Today, 9:40 AM",
                steps: [
                    TimelineStep(title: "Submitted", detail: "Pre-auth sent on 28 Sep.", state: .done),
                    TimelineStep(title: "Docs verified", detail: "Policy, bill, and ID checked.", state: .done),
                    TimelineStep(title: "Under review", detail: "Ops reviewed the hospital bill.", state: .done),
                    TimelineStep(title: "Query", detail: "Upload the payment receipt.", state: .current),
                    TimelineStep(title: "Approved", detail: "Waiting on the receipt.", state: .upcoming),
                    TimelineStep(title: "Settled", detail: "Not started.", state: .upcoming)
                ],
                query: "Upload the payment receipt so we can match the bill.",
                settlement: Settlement(
                    billAmount: 220_000,
                    lines: [
                        DeductionLine(title: "Non-payable items", amount: 18_000, reason: "Gloves, syringes, and toiletries are not payable."),
                        DeductionLine(title: "Room rent above cap", amount: 15_000, reason: "Room was ₹8,000 a day. The policy cap is ₹5,000."),
                        DeductionLine(title: "Co-pay 10%", amount: 7_000, reason: "Your policy shares 10% of the allowed amount.")
                    ],
                    approvedAmount: 180_000
                )
            ),
            Claim(
                id: "CLM-0988",
                hospital: "Fortis Hospital, Mohali",
                reason: "Day-care procedure",
                amount: 110_000,
                status: .settled,
                updated: "12 Sep",
                steps: [
                    TimelineStep(title: "Submitted", detail: "Filed on 2 Sep.", state: .done),
                    TimelineStep(title: "Docs verified", detail: "All documents matched.", state: .done),
                    TimelineStep(title: "Approved", detail: "Approved on 10 Sep.", state: .done),
                    TimelineStep(title: "Settled", detail: "Sample payout recorded.", state: .done)
                ],
                query: nil,
                settlement: Settlement(
                    billAmount: 110_000,
                    lines: [
                        DeductionLine(title: "Non-payable items", amount: 15_000, reason: "Registration and consumables were excluded.")
                    ],
                    approvedAmount: 95_000
                )
            )
        ]
    }

    private static func seedDocuments() -> [ClaimDocument] {
        [
            ClaimDocument(id: "policy", title: "Policy PDF", fileName: "Star_Health_Policy.pdf", status: .verified, note: "Name and policy number match."),
            ClaimDocument(id: "bill", title: "Hospital bill", fileName: "Apollo_Bill.pdf", status: .verified, note: "Amount matches the claim."),
            ClaimDocument(id: "discharge", title: "Discharge summary", fileName: "Discharge_Summary.jpg", status: .needsReview, note: "The discharge date is hard to read."),
            ClaimDocument(id: "receipt", title: "Payment receipt", fileName: nil, status: .missing, note: "Ops asked for this on claim CLM-1042."),
            ClaimDocument(id: "id", title: "Photo ID", fileName: "Aadhaar.pdf", status: .verified, note: "Name matches the policyholder.")
        ]
    }
}
