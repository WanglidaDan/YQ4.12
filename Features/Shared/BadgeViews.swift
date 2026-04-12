import SwiftUI

struct BookingStatusBadge: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let status: BookingStatus

    var body: some View {
        CapsuleBadge(
            title: status.title,
            systemImage: symbolName,
            tint: color,
            fillOpacity: fillOpacity,
            differentiateWithoutColor: differentiateWithoutColor
        )
    }

    private var color: Color {
        switch status {
        case .inquiry: AppTheme.secondaryInk
        case .tentative: AppTheme.warning
        case .confirmed: AppTheme.warning
        case .shooting: AppTheme.info
        case .editing: AppTheme.accentWarmDeep
        case .delivered: AppTheme.success
        case .cancelled: AppTheme.danger
        }
    }

    private var fillOpacity: Double {
        switch status {
        case .confirmed:
            0.1
        default:
            0.12
        }
    }

    private var symbolName: String {
        switch status {
        case .inquiry: "text.bubble"
        case .tentative: "clock"
        case .confirmed: "checkmark.seal.fill"
        case .shooting: "camera.shutter.button.fill"
        case .editing: "slider.horizontal.3"
        case .delivered: "shippingbox.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }
}

struct TierBadge: View {
    let tier: ClientTier

    var body: some View {
        CapsuleBadge(
            title: tier.title,
            systemImage: symbolName,
            tint: color,
            fillOpacity: 0.16,
            differentiateWithoutColor: false
        )
    }

    private var color: Color {
        switch tier {
        case .standard: AppTheme.secondaryInk
        case .focus: AppTheme.accent
        case .signature: AppTheme.accentWarmDeep
        }
    }

    private var symbolName: String {
        switch tier {
        case .standard: "circle.fill"
        case .focus: "star.leadinghalf.filled"
        case .signature: "crown.fill"
        }
    }
}

struct PriorityBadge: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let priority: TouchpointPriority

    var body: some View {
        CapsuleBadge(
            title: priority.title,
            systemImage: symbolName,
            tint: color,
            differentiateWithoutColor: differentiateWithoutColor
        )
    }

    private var color: Color {
        switch priority {
        case .low: AppTheme.priorityLow
        case .medium: AppTheme.priorityMedium
        case .high: AppTheme.priorityHigh
        case .urgent: AppTheme.priorityUrgent
        }
    }

    private var symbolName: String {
        switch priority {
        case .low: "circle"
        case .medium: "exclamationmark.circle"
        case .high: "exclamationmark.circle.fill"
        case .urgent: "flame.fill"
        }
    }
}

struct LeadStageBadge: View {
    let stage: LeadStage

    var body: some View {
        CapsuleBadge(
            title: stage.title,
            systemImage: symbolName,
            tint: color,
            fillOpacity: 0.14,
            differentiateWithoutColor: false
        )
    }

    private var color: Color {
        switch stage {
        case .discovery: AppTheme.info
        case .negotiating: AppTheme.warning
        case .booked: AppTheme.accent
        case .retained: AppTheme.success
        }
    }

    private var symbolName: String {
        switch stage {
        case .discovery: "sparkles"
        case .negotiating: "text.bubble.fill"
        case .booked: "checkmark.circle.fill"
        case .retained: "heart.fill"
        }
    }
}

struct PaymentStatusBadge: View {
    let status: PaymentStatus

    var body: some View {
        CapsuleBadge(
            title: status.title,
            systemImage: symbolName,
            tint: color,
            fillOpacity: 0.14,
            differentiateWithoutColor: false
        )
    }

    private var color: Color {
        switch status {
        case .unpaidDeposit: AppTheme.warning
        case .depositReceived: AppTheme.info
        case .balanceDue: AppTheme.priorityHigh
        case .paidInFull: AppTheme.success
        case .refunded: AppTheme.danger
        }
    }

    private var symbolName: String {
        switch status {
        case .unpaidDeposit: "clock.badge.exclamationmark"
        case .depositReceived: "banknote"
        case .balanceDue: "creditcard.trianglebadge.exclamationmark"
        case .paidInFull: "checkmark.circle.fill"
        case .refunded: "arrow.uturn.backward.circle.fill"
        }
    }
}

struct ServiceCategoryBadge: View {
    let category: ServiceCategory

    var body: some View {
        CapsuleBadge(
            title: category.title,
            systemImage: category.symbolName,
            tint: color,
            fillOpacity: 0.14,
            differentiateWithoutColor: false
        )
    }

    private var color: Color {
        switch category {
        case .wedding: AppTheme.accentWarmDeep
        case .engagement: AppTheme.accentWarmDeep
        case .travel: AppTheme.info
        case .portrait: AppTheme.info
        case .couple: AppTheme.accentWarm
        case .bestie: AppTheme.accent
        case .maternity: AppTheme.accentWarm
        case .newborn: AppTheme.success
        case .children: AppTheme.success
        case .family: AppTheme.success
        case .graduation: AppTheme.info
        case .pet: AppTheme.info
        case .documentary: AppTheme.warning
        case .documentaryFilm: AppTheme.warning
        case .aerial: AppTheme.info
        case .video: AppTheme.accentWarmDeep
        case .event: AppTheme.warning
        case .corporate: AppTheme.accentWarmDeep
        case .product: AppTheme.accentWarmDeep
        case .ecommerce: AppTheme.accentWarmDeep
        case .food: AppTheme.accentWarmDeep
        case .space: AppTheme.accentWarmDeep
        case .commercial: AppTheme.accentWarmDeep
        }
    }
}

private struct CapsuleBadge: View {
    let title: String
    let systemImage: String
    let tint: Color
    var fillOpacity: Double = 0.12
    var differentiateWithoutColor: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text(title)
                .lineLimit(1)
        }
        .font(AppTypography.badge)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(fillOpacity), in: RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous))
        .overlay {
            if differentiateWithoutColor {
                RoundedRectangle(cornerRadius: AppRadius.badge, style: .continuous)
                    .strokeBorder(tint.opacity(0.65), lineWidth: 1)
            }
        }
    }
}
