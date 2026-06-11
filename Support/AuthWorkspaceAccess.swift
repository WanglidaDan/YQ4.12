import Foundation

@MainActor
extension StudioStore {
    /// 登录/进入本地工作区属于身份建立动作，不能再依赖已有的团队管理权限，
    /// 否则会出现“未登录 -> 无管理权限 -> 无法写入登录身份”的死循环。
    func authenticateForAppEntry(_ profile: AuthProfile) {
        lastWorkspaceNoticeMessage = nil
        authProfile = profile

        if workspaceOwnerAppleUserID == nil || workspaceOwnerAppleUserID == "local-workspace-owner" || profile.appleUserID == "local-workspace-owner" {
            workspaceOwnerAppleUserID = profile.appleUserID
        }

        ensureOwnerMember(for: profile)
        normalizeAndPersistIfNeeded()
    }

    func enterLocalWorkspaceAsOwner() {
        let localProfile = AuthProfile(
            appleUserID: "local-workspace-owner",
            email: nil,
            fullName: "本地工作区"
        )
        workspaceOwnerAppleUserID = localProfile.appleUserID
        authProfile = localProfile
        lastWorkspaceNoticeMessage = nil
        ensureOwnerMember(for: localProfile)
        normalizeAndPersistIfNeeded()
    }

    private func ensureOwnerMember(for profile: AuthProfile) {
        let displayName = profile.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? profile.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "工作区所有者"
        let email = profile.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let index = workspaceMembers.firstIndex(where: { member in
            member.appleUserID == profile.appleUserID ||
            (email.isEmpty == false && member.email.caseInsensitiveCompare(email) == .orderedSame)
        }) {
            workspaceMembers[index].appleUserID = profile.appleUserID
            workspaceMembers[index].displayName = displayName
            workspaceMembers[index].email = email
            workspaceMembers[index].role = .owner
            workspaceMembers[index].status = .owner
            workspaceMembers[index].lastSeenAt = .now
            workspaceMembers[index].isActive = true
        } else {
            workspaceMembers.append(
                WorkspaceMemberRecord(
                    appleUserID: profile.appleUserID,
                    displayName: displayName,
                    email: email,
                    role: .owner,
                    status: .owner,
                    notesText: "系统自动创建的工作区所有者。",
                    createdAt: .now,
                    lastSeenAt: .now,
                    isActive: true
                )
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
