import Foundation

struct PaymentRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var bookingID: UUID
    var amount: Double
    var paymentType: PaymentType
    var date: Date
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        bookingID: UUID,
        amount: Double,
        paymentType: PaymentType,
        date: Date,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.bookingID = bookingID
        self.amount = amount
        self.paymentType = paymentType
        self.date = date
        self.note = note
        self.createdAt = createdAt
    }
}
