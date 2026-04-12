import SwiftUI

struct BookingMultilineField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.panelStrong)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(minHeight: minHeight, alignment: .topLeading)
                    .background(Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.line.opacity(0.52), lineWidth: 1)
            }
        }
        .padding(.vertical, 2)
    }
}
