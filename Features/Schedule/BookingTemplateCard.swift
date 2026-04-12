import SwiftUI

struct BookingTemplateCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let template: BookingTemplate
    let isRecommended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ServiceCategoryBadge(category: template.category)

                if isRecommended {
                    Text("当前推荐")
                        .font(AppTypography.meta.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.82))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.panel.opacity(colorScheme == .dark ? 0.88 : 0.42), in: RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous)
                                .stroke(AppTheme.line.opacity(0.42), lineWidth: 0.8)
                        }
                }
            }

            Text(template.name)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Text(summaryText)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)

            Text(template.defaultDeliverableText)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(Array(template.defaultShootingAttributes.prefix(2)), id: \.id) { attribute in
                    HStack(spacing: 4) {
                        Image(systemName: attribute.symbolName)
                            .font(.caption2.weight(.semibold))
                        Text(attribute.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppTheme.panel.opacity(colorScheme == .dark ? 0.9 : 0.34), in: Capsule())
                }

                if template.defaultShootingAttributes.count > 2 {
                    Text("+\(template.defaultShootingAttributes.count - 2)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(AppTheme.panel.opacity(colorScheme == .dark ? 0.9 : 0.34), in: Capsule())
                }
            }
        }
        .frame(width: 210, alignment: .leading)
        .padding(18)
        .background(templateBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.line.opacity(colorScheme == .dark ? 0.8 : 0.4), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow.opacity(colorScheme == .dark ? 0.9 : 0.6), radius: 14, y: 8)
    }

    private var summaryText: String {
        "\(template.defaultDurationHours) 小时 · \(AppFormatters.currency(template.defaultPrice))"
    }

    private var templateBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color(uiColor: UIColor(hex: "#252A21")) : Color(uiColor: UIColor(hex: "#F8FAF1")),
                        colorScheme == .dark ? Color(uiColor: UIColor(hex: "#2D3527")) : Color(uiColor: UIColor(hex: "#F3F7E4")),
                        colorScheme == .dark ? Color(uiColor: UIColor(hex: "#38442F")) : Color(uiColor: UIColor(hex: "#EDF4D4"))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RadialGradient(
                    colors: [
                        Color(uiColor: UIColor(hex: "#E7FB86")).opacity(colorScheme == .dark ? 0.24 : 0.72),
                        Color(uiColor: UIColor(hex: "#E7FB86")).opacity(colorScheme == .dark ? 0.08 : 0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 118
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            }
    }
}
