import SwiftUI

struct AppCardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    var fillColor: Color = AppTheme.panel
    var strokeOpacity: Double = 0.78

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.line.opacity(strokeOpacity), lineWidth: 1)
            }
            .shadow(color: AppTheme.cardShadow, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }
}

extension View {
    func appCardSurface(
        cornerRadius: CGFloat = AppRadius.card,
        fillColor: Color = AppTheme.panel,
        strokeOpacity: Double = 0.78
    ) -> some View {
        modifier(
            AppCardSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: fillColor,
                strokeOpacity: strokeOpacity
            )
        )
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyStrong)
            .foregroundStyle(AppTheme.panelStrong)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(AppTheme.accent)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.32), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyStrong)
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(AppTheme.panel)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.82), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.94 : 1)
    }
}

struct AppGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.panelSoft.opacity(configuration.isPressed ? 0.95 : 1), in: Capsule())
    }
}

struct AppSectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppTheme.ink)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(AppTypography.sectionSubtitle)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .textCase(nil)
    }
}

struct AppEmptyState: View {
    let title: String
    let subtitle: String
    var systemImage: String = "square.stack.3d.up.slash"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
        }
    }
}

struct AppInfoCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(title: title, subtitle: subtitle)
            content
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
    }
}

struct AppMetricTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var fillColor: Color = AppTheme.panelStrong
    var valueColor: Color = AppTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(AppTypography.dataCompact)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fillColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
        }
    }
}

struct AppKeyValueRow: View {
    let title: String
    let value: String
    var valueColor: Color = AppTheme.ink
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 12)
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
    }
}

struct AppInlineNote: View {
    let systemImage: String
    let text: String
    var tint: Color = AppTheme.secondaryInk

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppSettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(value)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.trailing)
        }
    }
}
