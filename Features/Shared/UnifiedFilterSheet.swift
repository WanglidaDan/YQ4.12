import SwiftUI

struct UnifiedFilterSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let summary: String
    let onReset: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        summary: String,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.onReset = onReset
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("当前筛选") {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                content
            }
            .scrollContentBackground(.hidden)
            .background(StudioBackdrop(mode: .ambient).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                if let onReset {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("重置") {
                            onReset()
                        }
                    }
                }
            }
        }
    }
}
