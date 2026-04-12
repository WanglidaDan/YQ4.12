import Foundation

struct AuthProfile: Codable, Hashable, Sendable {
    var appleUserID: String
    var email: String?
    var fullName: String?
    var signedInAt: Date

    init(appleUserID: String, email: String? = nil, fullName: String? = nil, signedInAt: Date = .now) {
        self.appleUserID = appleUserID
        self.email = email
        self.fullName = fullName
        self.signedInAt = signedInAt
    }
}
