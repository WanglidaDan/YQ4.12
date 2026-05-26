import SwiftUI

struct BookingCrewAssignmentDraft: Identifiable {
    let id = UUID()
    var assignment: BookingCrewAssignment
    let replacingAssignmentID: UUID?
    let title: String

    static func new(title: String = "添加分工") -> BookingCrewAssignmentDraft {
        BookingCrewAssignmentDraft(
            assignment: BookingCrewAssignment(memberName: "", role: .leadPhoto),
            replacingAssignmentID: nil,
            title: title
        )
    }

    static func edit(_ assignment: BookingCrewAssignment) -> BookingCrewAssignmentDraft {
        BookingCrewAssignmentDraft(
            assignment: assignment,
            replacingAssignmentID: assignment.id,
            title: "编辑分工"
        )
    }
}

struct BookingCrewAssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    @Binding var assignment: BookingCrewAssignment
    let title: String
    let onSave: (BookingCrewAssignment) -> Void

    private var canSave: Bool {
        assignment.memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var activeMemberSuggestions: [String] {
        store.activeCrewMembers.map(\.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("成员姓名", text: $assignment.memberName)

                    Picker("角色", selection: $assignment.role) {
                        ForEach(BookingCrewRole.allCases) { role in
                            Label(role.title, systemImage: role.symbolName)
                                .tag(role)
                        }
                    }
                } header: {
                    Text("成员")
                } footer: {
                    if activeMemberSuggestions.isEmpty == false {
                        Text("可直接填写，也可以从工作区已启用成员里快速选择。")
                    }
                }

                if activeMemberSuggestions.isEmpty == false {
                    Section("快捷选择") {
                        ForEach(activeMemberSuggestions, id: \.self) { name in
                            Button {
                                assignment.memberName = name
                            } label: {
                                HStack {
                                    Text(name)
                                        .foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    if assignment.memberName == name {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("执行内容") {
                    TextField("负责什么", text: $assignment.taskText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("去哪场 / 去哪个地点", text: $assignment.venueText, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("备注", text: $assignment.notesText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("填写建议") {
                    Text("例如：张三 · 主拍 · 婚礼接亲 + 宴会；李四 · 摄像 · 直播中控。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        assignment.memberName = assignment.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
                        assignment.taskText = assignment.taskText.trimmingCharacters(in: .whitespacesAndNewlines)
                        assignment.venueText = assignment.venueText.trimmingCharacters(in: .whitespacesAndNewlines)
                        assignment.notesText = assignment.notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(assignment)
                        AppHaptics.success()
                        dismiss()
                    }
                    .disabled(canSave == false)
                }
            }
        }
    }
}
