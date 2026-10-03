import Foundation

enum ClaimStatus: String, Decodable, CaseIterable {
    case CREATED, PREAUTH_SUBMITTED, DOCS_PENDING, UNDER_REVIEW, QUERY_RAISED, NEEDS_HUMAN, APPROVED, REJECTED, SETTLED, unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ClaimStatus(rawValue: raw) ?? .unknown
    }
}
enum ClaimType: String, Decodable { case CASHLESS, REIMBURSEMENT, unknown
    init(from decoder: Decoder) throws { self = ClaimType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum DocumentType: String, Decodable, CaseIterable {
    case HEALTH_CARD, POLICY_SCHEDULE, CLAIM_FORM, PREAUTH_FORM, DOCTOR_ESTIMATE, DISCHARGE_SUMMARY
    case HOSPITAL_BILL, PHARMACY_BILL, LAB_REPORT, PRESCRIPTION, PAYMENT_RECEIPT, ID_PROOF, OTHER, unknown
    init(from decoder: Decoder) throws { self = DocumentType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum DocumentStatus: String, Decodable { case UPLOADED, VERIFIED, NEEDS_REVIEW, INVALID, unknown
    init(from decoder: Decoder) throws { self = DocumentStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum QueryStatus: String, Decodable { case OPEN, ANSWERED, CLOSED, unknown
    init(from decoder: Decoder) throws { self = QueryStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum AppDocStatus: String, Decodable { case uploaded, verified, missing, rejected, unknown
    init(from decoder: Decoder) throws { self = AppDocStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum StepState: String, Decodable { case done, current, pending, failed, unknown
    init(from decoder: Decoder) throws { self = StepState(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum SettlementStatus: String, Decodable { case PREVIEW, ESTIMATED, APPROVED, PAID, unknown
    init(from decoder: Decoder) throws { self = SettlementStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum NotificationType: String, Decodable { case INFO, SUCCESS, WARNING, ACTION_REQUIRED, unknown
    init(from decoder: Decoder) throws { self = NotificationType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}
enum ActorType: String, Decodable { case AI, HUMAN, SYSTEM, unknown
    init(from decoder: Decoder) throws { self = ActorType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}

struct User: Decodable, Identifiable, Hashable {
    let id: String
    var name: String
    var email: String?
    var phone: String?
    var city: String?
    var dob: String?
    var gender: String?
    var profileComplete: Bool?
}

struct Member: Decodable, Hashable { var name: String?; var relation: String? }
struct Policy: Decodable, Identifiable, Hashable {
    let id: String
    var insurer: String?
    var planName: String?
    var policyNumber: String?
    var sumInsured: Int?
    var roomRentLimit: Int?
    var coPayPercent: Double?
    var members: [Member]?
}
struct HomeChecklist: Decodable, Hashable {
    var required: [String]?
    var verified: [String]?
    var missing: [String]?
}
struct Claim: Decodable, Identifiable, Hashable {
    let id: String
    var claimNumber: String?
    var hospital: String?
    var reason: String?
    var status: ClaimStatus?
    var billAmount: Int?
    var estimatedAmount: Int?
    var checklist: HomeChecklist?
}
struct Deduction: Decodable, Hashable { var label: String?; var amount: Int?; var reason: String?; var clause: String? }
struct Settlement: Decodable, Hashable {
    var billAmount: Int?
    var deductions: [Deduction]?
    var coPayAmount: Int?
    var approvedAmount: Int?
    var status: SettlementStatus?
    var utr: String?
    var isDemo: Bool?
    var preview: Bool?
}
struct ClaimRef: Decodable, Hashable { var id: String?; var claimNumber: String?; var hospital: String? }
struct PendingAction: Decodable, Hashable { var kind: String; var title: String; var claimId: String?; var queryId: String? }
struct HomeCounts: Decodable, Hashable { var unreadNotifications: Int?; var activeClaims: Int?; var openQueries: Int? }
struct Home: Decodable { var user: User; var activePolicy: Policy?; var currentClaim: Claim?; var pendingActions: [PendingAction]?; var counts: HomeCounts?; var paidOut: Int? }
struct AuthResponse: Decodable { var token: String; var user: User; var needsProfile: Bool? }
struct ProfileResponse: Decodable { var user: User; var token: String }
struct OtpSent: Decodable { var sent: Bool? }
struct Coverage: Decodable, Hashable { var item: String?; var detail: String? }
struct WaitingStatus: Decodable, Hashable { var name: String?; var active: Bool?; var status: String? }
struct PolicyAnalysis: Decodable {
    var insurer: String?
    var policyNumber: String?
    var whatIsCovered: String?
    var coverage: [Coverage]?
    var exclusions: [String]?
    var waitingPeriods: [WaitingStatus]?
}
struct AddPolicyResponse: Decodable { var policy: Policy; var extractedFromPdf: Bool? }
struct ChecklistItem: Decodable, Identifiable, Hashable {
    var id: String { type?.rawValue ?? label ?? "item" }
    var type: DocumentType?
    var label: String?
    var status: AppDocStatus?
    var fileName: String?
    var fix: String?
}
struct DocProgress: Decodable { var required: Int?; var verified: Int? }
struct Checklist: Decodable { var claimId: String?; var items: [ChecklistItem]?; var warnings: [String]?; var progress: DocProgress? }
struct ValidationCheck: Decodable, Identifiable {
    var id: String { key ?? label ?? "check" }
    var key: String?
    var label: String?
    var passed: Bool?
    var detail: String?
}
struct UploadValidation: Decodable { var appStatus: AppDocStatus?; var confidence: Double?; var summary: String?; var fix: String?; var checks: [ValidationCheck]?; var warnings: [String]? }
struct UploadResponse: Decodable { var validation: UploadValidation?; var checklist: Checklist? }
struct Step: Decodable, Hashable, Identifiable {
    var id: String { key ?? label ?? "step" }
    var key: String?
    var label: String?
    var state: StepState?
    var note: String?
}
struct OpsUpdate: Decodable, Hashable { var message: String? }
struct Timeline: Decodable { var claimNumber: String?; var status: ClaimStatus?; var steps: [Step]?; var openQueries: [Query]?; var latestOpsUpdate: OpsUpdate? }
struct Grounded: Decodable, Hashable { var policyNumber: String?; var claimNumber: String? }
struct ChatReply: Decodable { var answer: String; var followUps: [String]?; var grounded: Grounded? }
struct Query: Decodable, Identifiable {
    var id: String
    var message: String?
    var requestedDocType: DocumentType?
    var status: QueryStatus?
    var claim: ClaimRef?
    var document: UploadResponse?
}
struct AppNotification: Decodable, Identifiable, Hashable { var id: String; var claimId: String?; var title: String?; var body: String? }
struct NotificationsPage: Decodable { var items: [AppNotification]; var unread: Int? }
struct CoverageResult: Decodable { var warnings: [String]? }
struct QueryExplain: Decodable { var explanation: String? }
struct BankMasked: Decodable { var accountNumberMasked: String?; var ifsc: String? }
struct BankResponse: Decodable { var bank: BankMasked? }

struct PhoneBody: Encodable { let phone: String }
struct VerifyBody: Encodable { let phone: String; let otp: String }
struct ProfileBody: Encodable { var name: String; var email: String; var dob: String; var gender: String; var city: String? }
struct ProfilePatch: Encodable { var name: String?; var city: String? }
struct AddPolicyBody: Encodable { var insurer: String; var policyNumber: String; var sumInsured: Int; var startDate: String; var roomRentLimit: Int?; var coPayPercent: Double? }
struct BankBody: Encodable { var accountName: String; var accountNumber: String; var ifsc: String; var bankName: String?; var otp: String }
struct CreateClaimBody: Encodable {
    var policyId: String
    var type: String
    var hospital: String
    var hospitalCity: String?
    var reason: String
    var admissionType: String = "EMERGENCY"
    var billAmount: Int?
    var estimatedAmount: Int?
    var patientName: String
    var consentOtp: String?
}
struct ChatBody: Encodable { var message: String; var claimId: String? }

extension API {
    func sendOtp(_ phone: String) async throws -> OtpSent { try await request("auth/otp/send", method: "POST", json: PhoneBody(phone: phone)) }
    func verifyOtp(_ phone: String, _ otp: String) async throws -> AuthResponse { try await request("auth/otp/verify", method: "POST", json: VerifyBody(phone: phone, otp: otp)) }
    func me() async throws -> User { try await request("me") }
    func putProfile(_ body: ProfileBody) async throws -> ProfileResponse { try await request("me/profile", method: "PUT", json: body) }
    func patchProfile(_ body: ProfilePatch) async throws -> ProfileResponse { try await request("me/profile", method: "PATCH", json: body) }
    func home() async throws -> Home { try await request("me/home") }
    func policies() async throws -> [Policy] { try await request("me/policies") }
    func addPolicy(_ body: AddPolicyBody) async throws -> AddPolicyResponse { try await request("me/policies", method: "POST", json: body) }

    func addPolicyPdf(_ body: AddPolicyBody, bytes: Data, filename: String, mime: String) async throws -> AddPolicyResponse {
        var form = Multipart()
        form.field("insurer", body.insurer)
        form.field("policyNumber", body.policyNumber)
        form.field("sumInsured", String(body.sumInsured))
        form.field("startDate", body.startDate)
        if let room = body.roomRentLimit { form.field("roomRentLimit", String(room)) }
        if let copay = body.coPayPercent { form.field("coPayPercent", String(copay)) }
        form.file(filename: filename, mime: mime, bytes: bytes)
        return try await request("me/policies", method: "POST", body: form.finalized(), contentType: form.contentType)
    }
    func analyze(_ id: String) async throws -> PolicyAnalysis { try await request("me/policies/\(id)/analyze", method: "POST") }
    func saveBank(_ body: BankBody) async throws -> BankResponse { try await request("me/bank", method: "POST", json: body) }
    func checkCoverage(_ body: CreateClaimBody) async throws -> CoverageResult { try await request("claims/check-coverage", method: "POST", json: body) }
    func createClaim(_ body: CreateClaimBody) async throws -> Claim { try await request("claims", method: "POST", json: body) }
    func preauth(_ id: String) async throws { let _: EmptyBody = try await request("claims/\(id)/preauth", method: "POST") }
    func claims(status: String? = nil) async throws -> [Claim] { try await request("claims", query: ["status": status]) }
    func checklist(_ id: String) async throws -> Checklist { try await request("claims/\(id)/checklist") }
    func timeline(_ id: String) async throws -> Timeline { try await request("claims/\(id)/timeline") }
    func settlement(_ id: String) async throws -> Settlement { try await request("claims/\(id)/settlement") }
    func queries(status: String? = "OPEN") async throws -> [Query] { try await request("queries", query: ["status": status]) }
    func explainQuery(_ id: String) async throws -> QueryExplain { try await request("queries/\(id)/explain") }
    func chat(_ message: String, claimId: String?) async throws -> ChatReply { try await request("ai/chat", method: "POST", json: ChatBody(message: message, claimId: claimId)) }
    func notifications() async throws -> NotificationsPage { try await request("notifications") }
    func markRead(_ id: String) async throws { let _: EmptyBody = try await request("notifications/\(id)/read", method: "POST") }
    func markAllRead() async throws { let _: EmptyBody = try await request("notifications/read-all", method: "POST") }

    func upload(claimId: String, bytes: Data, filename: String, mime: String, type: String?) async throws -> UploadResponse {
        var form = Multipart()
        form.file(filename: filename, mime: mime, bytes: bytes)
        if let type { form.field("type", type) }
        return try await request("claims/\(claimId)/documents", method: "POST", body: form.finalized(), contentType: form.contentType)
    }

    func respond(queryId: String, text: String, bytes: Data?, filename: String?, mime: String?, type: String?) async throws -> Query {
        var form = Multipart()
        form.field("response", text)
        if let type { form.field("type", type) }
        if let bytes, let filename, let mime { form.file(filename: filename, mime: mime, bytes: bytes) }
        return try await request("queries/\(queryId)/respond", method: "POST", body: form.finalized(), contentType: form.contentType)
    }
}
