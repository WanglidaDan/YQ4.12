import SwiftUI

struct PaymentEditorView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let bookingID: UUID

    @State private var amount: Double = 0
    @State private var paymentType: PaymentType = .balance
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("回款信息") {
                    Picker("类型", selection: $paymentType) {
                        ForEach(PaymentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    TextField("金额", value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let booking = store.booking(id: bookingID) {
                    Section("当前订单") {
                        LabeledContent("项目", value: booking.title)
                        LabeledContent("待收", value: AppFormatters.currency(store.outstandingAmount(for: booking)))
                    }
                }
            }
            .navigationTitle("记录回款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel, action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark", action: save)
                        .bold()
                }
            }
            .onAppear(perform: fillSuggestedAmount)
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if $0 == false { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "请检查回款信息。")
            }
        }
    }

    private func fillSuggestedAmount() {
        guard amount == 0, let booking = store.booking(id: bookingID) else { return }
        amount = store.outstandingAmount(for: booking)
    }

    private func save() {
        guard amount > 0 else {
            errorMessage = "请输入大于 0 的金额。"
            AppHaptics.error()
            return
        }

        store.upsert(payment: PaymentRecord(
            bookingID: bookingID,
            amount: amount,
            paymentType: paymentType,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        AppHaptics.success()
        dismiss()
    }
}
