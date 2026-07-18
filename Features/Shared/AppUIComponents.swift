import SwiftUI

enum AppCardStyle {
    case lightweight
    case emphasized
}

struct AppCardSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var cornerRadius: CGFloat = AppRadius.card
    var fillColor: Color = AppTheme.panel
    var strokeOpacity: Double = 0.78
    var style: AppCardStyle = .lightweight

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), reduceTransparency == false {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor.opacity(0.32))
                )
                .glassEffect(.regular.tint(fillColor.opacity(0.18)), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            AppTheme.line.opacity(strokeOpacity * (colorSchemeContrast == .increased ? 1 : 0.72)),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                }
                .shadow(
                    color: AppTheme.cardShadow.opacity(style == .emphasized ? 0.76 : 0.28),
                    radius: style == .emphasized ? AppShadow.cardRadius : 3,
                    y: style == .emphasized ? AppShadow.cardY : 1
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            AppTheme.line.opacity(strokeOpacity),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                }
                .shadow(
                    color: AppTheme.cardShadow.opacity(style == .emphasized ? 1 : 0.46),
                    radius: style == .emphasized ? AppShadow.cardRadius : 3,
                    y: style == .emphasized ? AppShadow.cardY : 1
                )
        }
    }
}

extension View {
    func appCardSurface(
        cornerRadius: CGFloat = AppRadius.card,
        fillColor: Color = AppTheme.panel,
        strokeOpacity: Double = 0.78,
        style: AppCardStyle = .lightweight
    ) -> some View {
        modifier(
            AppCardSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: fillColor,
                strokeOpacity: strokeOpacity,
                style: style
            )
        )
    }
}

struct AppPageScaffold<Content: View>: View {
    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    var horizontalPadding: CGFloat = AppSpacing.page
    var topPadding: CGFloat = 16
    var bottomPadding: CGFloat = 28
    @ViewBuilder let content: Content

    init(
        title: String,
        titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large,
        horizontalPadding: CGFloat = AppSpacing.page,
        topPadding: CGFloat = 16,
        bottomPadding: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(titleDisplayMode)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *), reduceTransparency == false {
            configuration.label
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppTheme.panelStrong)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .glassEffect(.regular.tint(AppTheme.accent.opacity(0.34)).interactive(), in: .rect(cornerRadius: AppRadius.control))
                .opacity(configuration.isPressed ? 0.92 : 1)
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
                .animation(.smooth(duration: 0.14), value: configuration.isPressed)
        } else {
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
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
                .animation(.smooth(duration: 0.14), value: configuration.isPressed)
        }
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .animation(.smooth(duration: 0.14), value: configuration.isPressed)
    }
}

struct AppGhostButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.meta.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.panelSoft.opacity(configuration.isPressed ? 0.95 : 1), in: Capsule())
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppTactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
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
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .textCase(nil)
    }
}

struct AppPageHeader<ActionContent: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let actions: ActionContent

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> ActionContent = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTypography.sectionSubtitle)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension AppPageHeader where ActionContent == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actions = EmptyView()
    }
}

struct AppCircleIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 44, height: 44)
                .background(AppTheme.panelStrong, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.line.opacity(0.68), lineWidth: 1)
                }
        }
        .buttonStyle(AppTactileButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppInlineSearchField: View {
    let placeholder: String
    @Binding var text: String

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.mutedInk)

            TextField(placeholder, text: $text)
                .font(AppTypography.rowValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if trimmedText.isEmpty == false {
                Button {
                    text = ""
                    AppHaptics.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.icon)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppTheme.line.opacity(0.70), lineWidth: 1)
        }
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

struct AppToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.accent)
            Text(message)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appCardSurface(cornerRadius: 18, fillColor: AppTheme.panelStrong, style: .emphasized)
    }
}

struct AppUndoToast: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.success)

            Text(message)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button(actionTitle, action: action)
                .font(AppTypography.bodyStrong)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appCardSurface(cornerRadius: 18, fillColor: AppTheme.panelStrong, style: .emphasized)
        .accessibilityElement(children: .contain)
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

struct AppCreateHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var systemImage: String = "plus"

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .font(AppTypography.meta.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)

                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AppTypography.meta)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: systemImage)
                .font(AppTypography.icon)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.panelStrong, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.line.opacity(0.72), lineWidth: 1)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(fillColor: AppTheme.panelSoft)
    }
}

struct AppEditorCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(fillColor: AppTheme.panel)
    }
}

struct AppEditorLabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AppTypography.meta.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)

            content
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.inputSurface, in: RoundedRectangle(cornerRadius: AppRadius.control - 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control - 4, style: .continuous)
                        .stroke(AppTheme.line.opacity(0.64), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppEditorDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.line.opacity(0.5))
            .frame(height: 1)
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
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                .font(AppTypography.icon)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(2)
                .truncationMode(.tail)
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
