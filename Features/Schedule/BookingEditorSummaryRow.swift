import SwiftUI

struct BookingEditorSummaryRow: View {
    let systemImage: String
    let title: String
    let value: String
    var subtitle: String?
    var valueIsPlaceholder = false
    var showsDisclosure = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var horizontalLayout: some View {
        HStack(spacing: 14) {
            rowIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Text(value)
                .font(AppTypography.rowValue)
                .foregroundStyle(valueIsPlaceholder ? AppTheme.secondaryInk : AppTheme.ink)
                .lineLimit(1)

            disclosureIcon
        }
    }

    private var verticalLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            rowIcon

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppTheme.ink)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Text(value)
                    .font(AppTypography.rowValue)
                    .foregroundStyle(valueIsPlaceholder ? AppTheme.secondaryInk : AppTheme.ink)
            }

            Spacer(minLength: 8)
            disclosureIcon
        }
    }

    private var rowIcon: some View {
        Image(systemName: systemImage)
            .font(AppTypography.icon)
            .foregroundStyle(AppTheme.accent)
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var disclosureIcon: some View {
        if showsDisclosure {
            Image(systemName: "chevron.right")
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
                .accessibilityHidden(true)
        }
    }
}
