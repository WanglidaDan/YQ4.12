import Foundation

enum BusinessDocumentTextRenderer {
    static func text(
        for document: BusinessDocumentRecord,
        booking: BookingRecord?,
        client: ClientRecord?,
        studioProfile: StudioProfile
    ) -> String {
        let addressLine = [studioProfile.city, studioProfile.address]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")

        let lineItemText = document.lineItems
            .enumerated()
            .map { index, item in
                let quantityText = item.quantity == floor(item.quantity)
                    ? String(Int(item.quantity))
                    : item.quantity.formatted()
                let detailsLine = item.detailsText.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleLine = "\(index + 1). \(item.title) x\(quantityText) · \(AppFormatters.currency(item.lineTotal))"
                guard detailsLine.isEmpty == false else { return titleLine }
                return [titleLine, "   说明：\(detailsLine)"].joined(separator: "\n")
            }
            .joined(separator: "\n")

        return [
            "【\(document.title)】\(document.kind.title)",
            "状态：\(document.status.title)",
            "编号：\(document.number)",
            "抬头：\(document.recipientName.isEmpty ? (client?.name ?? "未填写") : document.recipientName)",
            booking.map { "关联订单：\($0.title)" },
            client.map { "关联客户：\($0.name)" },
            "开具日期：\(AppFormatters.shortDate(document.issueDate))",
            document.dueDate.map { "到期日期：\(AppFormatters.shortDate($0))" },
            studioProfile.displayName.isEmpty ? nil : "工作室：\(studioProfile.displayName)",
            studioProfile.legalName.isEmpty ? nil : "签约主体：\(studioProfile.legalName)",
            "",
            "明细：",
            lineItemText.isEmpty ? "暂无明细" : lineItemText,
            "",
            "小计：\(AppFormatters.currency(document.subtotalAmount))",
            document.discountAmount > 0 ? "优惠：-\(AppFormatters.currency(document.discountAmount))" : nil,
            document.taxRate > 0 ? "税额：\(AppFormatters.currency(document.taxAmount))" : nil,
            "总额：\(AppFormatters.currency(document.totalAmount))",
            "",
            document.notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "备注：\(document.notesText)",
            document.termsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "条款：\(document.termsText)",
            studioProfile.contactPhone.isEmpty ? nil : "联系电话：\(studioProfile.contactPhone)",
            studioProfile.contactEmail.isEmpty ? nil : "联系邮箱：\(studioProfile.contactEmail)",
            addressLine.isEmpty ? nil : "工作室地址：\(addressLine)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}
