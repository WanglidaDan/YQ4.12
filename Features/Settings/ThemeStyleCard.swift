import SwiftUI

struct ThemeStyleCard: View {
    let style: AppThemeStyle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppTheme.ink)
                    Text(style.subtitle)
                        .font(AppTypography.meta)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.line)
            }

            HStack(spacing: 8) {
                ForEach(style.palette.previewSwatches, id: \.hex) { swatch in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: AppRadius.row, style: .continuous)
                            .fill(Color(uiColor: UIColor(hex: swatch.hex)))
                            .frame(height: 40)

                        Text(swatch.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)

                        Text(swatch.hex.uppercased())
                            .font(.caption2.monospaced())
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(width: 264, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(isSelected ? AppTheme.accent : AppTheme.line.opacity(0.68), lineWidth: isSelected ? 1.6 : 1)
        }
        .shadow(color: AppTheme.cardShadow, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }
}
