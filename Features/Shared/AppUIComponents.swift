import SwiftUI

enum AppCardStyle {
    case lightweight
    case emphasized
}

struct AppCardSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    var fillColor: Color = AppTheme.panel
    var strokeOpacity: Double = 0.78
    var style: AppCardStyle = .lightweight

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
            .shadow(
                color: AppTheme.cardShadow.opacity(style == .emphasized ? 1 : 0.46),
                radius: style == .emphasized ? AppShadow.cardRadius : 3,
                y: style == .emphasized ? AppShadow.cardY : 1
            )
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
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(titleDisplayMode)
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
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                .font(.system(size: 17, weight: .semibold))
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

struct AppStepProgress: View {
    let titles: [String]
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                        .fill(index <= currentIndex ? AppTheme.accent : AppTheme.line.opacity(0.42))
                        .frame(height: 4)

                    Text(title)
                        .font(AppTypography.meta.weight(index == currentIndex ? .semibold : .regular))
                        .foregroundStyle(index == currentIndex ? AppTheme.ink : AppTheme.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(AppTypography.meta)
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
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

struct CreateBookingContext: Hashable {
    enum Source: Hashable {
        case overview
        case schedule
        case clientDetail
        case team
        case quickAction
    }

    var source: Source
    var defaultDate: Date?
    var defaultClientID: UUID?
    var defaultCrewMemberName: String?
    var defaultCategory: ServiceCategory?
    var defaultTitle: String?

    static let overview = CreateBookingContext(source: .overview)

    static func schedule(focusDate: Date, crewMemberName: String? = nil) -> CreateBookingContext {
        CreateBookingContext(
            source: .schedule,
            defaultDate: focusDate,
            defaultCrewMemberName: crewMemberName
        )
    }

    static func clientDetail(clientID: UUID) -> CreateBookingContext {
        CreateBookingContext(source: .clientDetail, defaultClientID: clientID)
    }
}

private enum ServiceCategoryGroup: String, CaseIterable, Identifiable {
    case lifeEvent
    case portraitFamily
    case commercial
    case eventVideo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lifeEvent: "婚礼纪实"
        case .portraitFamily: "人像家庭"
        case .commercial: "商业内容"
        case .eventVideo: "活动视频"
        }
    }

    var categories: [ServiceCategory] {
        switch self {
        case .lifeEvent:
            [.wedding, .engagement, .travel, .documentary]
        case .portraitFamily:
            [.portrait, .couple, .bestie, .maternity, .newborn, .children, .family, .graduation, .pet]
        case .commercial:
            [.corporate, .product, .ecommerce, .food, .space, .commercial]
        case .eventVideo:
            [.event, .video, .documentaryFilm, .aerial]
        }
    }

    static func group(for category: ServiceCategory) -> ServiceCategoryGroup {
        allCases.first { $0.categories.contains(category) } ?? .lifeEvent
    }
}

struct CreateBookingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudioStore.self) private var store

    private enum Step: Int, CaseIterable {
        case essentials
        case details
        case confirm

        var title: String {
            switch self {
            case .essentials: "快速创建"
            case .details: "补充信息"
            case .confirm: "确认档期"
            }
        }
    }

    let context: CreateBookingContext

    @State private var step: Step = .essentials
    @State private var title: String
    @State private var selectedClientID: UUID?
    @State private var categoryGroup: ServiceCategoryGroup
    @State private var category: ServiceCategory
    @State private var status: BookingStatus = .inquiry
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var city = ""
    @State private var venue: String
    @State private var addressText = ""
    @State private var fee: Double = 0
    @State private var depositPaid: Double = 0
    @State private var deliverableText = ""
    @State private var notesText: String
    @State private var shouldCreateFollowUp = true
    @State private var shouldSaveAsTemplate = false
    @State private var templateName = ""
    @State private var selectedCrewMemberName: String
    @State private var showingConflictConfirmation = false

    init(context: CreateBookingContext = .overview) {
        self.context = context
        let category = context.defaultCategory ?? .wedding
        let start = Self.normalizedStartDate(from: context.defaultDate ?? .now.addingTimeInterval(86_400))
        let end = Calendar.current.date(byAdding: .hour, value: 4, to: start) ?? start.addingTimeInterval(14_400)
        let contextTitle = context.defaultTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        _title = State(initialValue: contextTitle)
        _selectedClientID = State(initialValue: context.defaultClientID)
        _categoryGroup = State(initialValue: ServiceCategoryGroup.group(for: category))
        _category = State(initialValue: category)
        _startAt = State(initialValue: start)
        _endAt = State(initialValue: end)
        _venue = State(initialValue: "")
        _notesText = State(initialValue: "")
        _selectedCrewMemberName = State(initialValue: context.defaultCrewMemberName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    var body: some View {
        NavigationStack {
            AppPageScaffold(title: step.title, titleDisplayMode: .inline, topPadding: 14, bottomPadding: 28) {
                progressSection

                switch step {
                case .essentials:
                    essentialsSection
                case .details:
                    detailsSection
                case .confirm:
                    confirmSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .task {
                applyStoreDefaultsIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if step == .confirm {
                        Button("创建", action: saveTapped)
                            .disabled(isEssentialsIncomplete)
                    } else {
                        Button("下一步", action: goForward)
                            .disabled(isEssentialsIncomplete)
                    }
                }
            }
            .confirmationDialog("当前时间可能有冲突", isPresented: $showingConflictConfirmation) {
                Button("仍然创建") {
                    saveBooking()
                }
                Button("返回调整", role: .cancel) {}
            } message: {
                Text(conflictSummaryText)
            }
        }
    }

    private var progressSection: some View {
        AppStepProgress(titles: Step.allCases.map(\.title), currentIndex: step.rawValue)
    }

    private var essentialsSection: some View {
        Group {
            AppEditorCard(title: "拍摄内容") {
                AppEditorLabeledField("拍摄内容") {
                    TextField("例如：婚礼全天跟拍", text: $title)
                }

                AppEditorDivider()

                AppEditorLabeledField("类型大类") {
                    Picker("类型大类", selection: $categoryGroup) {
                        ForEach(ServiceCategoryGroup.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .onChange(of: categoryGroup) { _, newValue in
                        if newValue.categories.contains(category) == false,
                           let firstCategory = newValue.categories.first {
                            category = firstCategory
                        }
                    }
                }

                AppEditorDivider()

                AppEditorLabeledField("细分类型") {
                    Picker("细分类型", selection: $category) {
                        ForEach(categoryGroup.categories) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                AppEditorDivider()

                AppEditorLabeledField("当前状态") {
                    Picker("当前状态", selection: $status) {
                        ForEach(BookingStatus.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }
            }

            AppEditorCard(title: "时间与地点") {
                AppEditorLabeledField("开始时间") {
                    DatePicker("开始时间", selection: $startAt)
                        .labelsHidden()
                        .onChange(of: startAt) { oldValue, newValue in
                            shiftEndDate(from: oldValue, to: newValue)
                        }
                }

                AppEditorDivider()

                AppEditorLabeledField("结束时间") {
                    DatePicker("结束时间", selection: $endAt, in: startAt...)
                        .labelsHidden()
                }

                AppEditorDivider()

                AppEditorLabeledField("城市 / 区域") {
                    TextField("例如：上海", text: $city)
                }

                AppEditorDivider()

                AppEditorLabeledField("场地名称") {
                    TextField("影棚、酒店或外景地", text: $venue)
                }

                AppEditorDivider()

                AppEditorLabeledField("详细地址") {
                    TextField("门牌、楼层、集合点", text: $addressText, axis: .vertical)
                        .lineLimit(2...4)
                }
            }

            AppEditorCard(title: "负责人") {
                AppEditorLabeledField("默认负责人") {
                    Picker("默认负责人", selection: $selectedCrewMemberName) {
                        Text("暂不分配").tag("")
                        ForEach(store.activeCrewMemberNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                        if selectedCrewMemberName.isEmpty == false,
                           store.activeCrewMemberNames.contains(selectedCrewMemberName) == false {
                            Text(selectedCrewMemberName).tag(selectedCrewMemberName)
                        }
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            AppEditorCard(title: "报价与回款") {
                AppEditorLabeledField("总报价") {
                    TextField("0", value: $fee, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.decimalPad)
                }

                AppEditorDivider()

                AppEditorLabeledField("已收金额") {
                    TextField("0", value: $depositPaid, format: .number.precision(.fractionLength(0...0)))
                        .keyboardType(.decimalPad)
                }

                AppInlineNote(systemImage: "creditcard", text: "待收：\(AppFormatters.currency(max(fee - depositPaid, 0)))")
            }

            AppEditorCard(title: "交付与备注") {
                AppEditorLabeledField("交付内容") {
                    TextField("例如：精修 60 张 + 花絮 1 条", text: $deliverableText, axis: .vertical)
                        .lineLimit(2...5)
                }

                AppEditorDivider()

                AppEditorLabeledField("项目说明") {
                    TextField("客户偏好、流程注意事项", text: $notesText, axis: .vertical)
                        .lineLimit(3...8)
                }
            }

            AppEditorCard(title: "自动动作") {
                Toggle("创建拍前确认跟进", isOn: $shouldCreateFollowUp)
                AppInlineNote(systemImage: "bell.badge", text: "创建后会保留系统提醒，并可在详情里继续补充分工、回款和合同资料。")
            }

            AppEditorCard(title: "保存为模板") {
                Toggle("保存当前内容为模板", isOn: $shouldSaveAsTemplate)
                if shouldSaveAsTemplate {
                    AppEditorDivider()
                    AppEditorLabeledField("模板名称") {
                        TextField("例如：婚礼全天拍摄", text: $templateName)
                    }
                    AppInlineNote(systemImage: "square.grid.2x2", text: "模板只保存当前服务类型、时长、报价、交付和项目说明。")
                }
            }
        }
    }

    private var confirmSection: some View {
        Group {
            AppEditorCard(title: "档期摘要") {
                AppKeyValueRow(title: "拍摄内容", value: trimmedTitle)
                if selectedClientID != nil {
                    AppKeyValueRow(title: "客户", value: selectedClientName)
                }
                AppKeyValueRow(title: "类型", value: "\(categoryGroup.title) · \(category.title)")
                AppKeyValueRow(title: "时间", value: "\(AppFormatters.shortDate(startAt)) · \(AppFormatters.timeRange(start: startAt, end: endAt))")
                AppKeyValueRow(title: "地点", value: locationSummary)
                AppKeyValueRow(title: "负责人", value: selectedCrewMemberName.isEmpty ? "暂不分配" : selectedCrewMemberName)
                AppKeyValueRow(title: "报价", value: fee > 0 ? AppFormatters.currency(fee) : "未报价")
            }

            if conflictBookings.isEmpty == false {
                AppEditorCard(title: "冲突提醒") {
                    Label(conflictSummaryText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warning)
                }
            }

            AppEditorCard(title: "创建后自动生成") {
                Label("系统拍摄提醒", systemImage: "bell.badge")
                if shouldCreateFollowUp {
                    Label("拍前确认跟进", systemImage: "checklist")
                }
                if shouldSaveAsTemplate {
                    Label("保存为我的模板", systemImage: "square.grid.2x2")
                }
                Label("可继续补充合同、回款、收据和发票", systemImage: "doc.text")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEssentialsIncomplete: Bool {
        trimmedTitle.isEmpty
    }

    private var selectedClientName: String {
        guard let selectedClientID,
              let client = store.client(id: selectedClientID) else {
            return "暂不绑定"
        }
        return client.name
    }

    private var locationSummary: String {
        let parts = [city, venue, addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? "未填写地点" : parts.joined(separator: " · ")
    }

    private var normalizedFee: Double {
        max(fee, 0)
    }

    private var normalizedDeposit: Double {
        min(max(depositPaid, 0), normalizedFee)
    }

    private var crewAssignments: [BookingCrewAssignment] {
        let name = selectedCrewMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return [] }
        return [BookingCrewAssignment(memberName: name, role: .leadPhoto)]
    }

    private var conflictBookings: [BookingRecord] {
        store.activeBookings.filter { booking in
            booking.status != .cancelled &&
            Calendar.current.isDate(booking.startAt, inSameDayAs: startAt) &&
            booking.startAt < endAt && startAt < booking.endAt
        }
    }

    private var conflictSummaryText: String {
        if conflictBookings.isEmpty {
            return "当前时间没有发现重叠档期。"
        }
        let heads = conflictBookings.prefix(2).map { $0.title }.joined(separator: "、")
        if conflictBookings.count > 2 {
            return "该时间段已有 \(heads) 等 \(conflictBookings.count) 个档期。"
        }
        return "该时间段已有 \(heads)。"
    }

    private func goForward() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        AppHaptics.selection()
    }

    private func saveTapped() {
        if conflictBookings.isEmpty == false {
            showingConflictConfirmation = true
        } else {
            saveBooking()
        }
    }

    private func saveBooking() {
        let booking = BookingRecord(
            id: UUID(),
            title: trimmedTitle,
            category: category,
            status: status,
            startAt: startAt,
            endAt: endAt,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressText: addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationNote: "",
            latitude: nil,
            longitude: nil,
            fee: normalizedFee,
            depositPaid: normalizedDeposit,
            deliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            notesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            shootingAttributes: ShootingAttribute.defaultSelection(for: category),
            crewAssignments: crewAssignments,
            reminderOffsets: BookingReminderOffset.defaultSelection,
            createdAt: .now,
            clientID: selectedClientID
        )

        store.upsert(booking: booking)

        if shouldSaveAsTemplate {
            saveCurrentDraftAsTemplate()
        }

        if shouldCreateFollowUp {
            let dueAt = Calendar.current.date(byAdding: .day, value: -2, to: startAt) ?? startAt
            let reminder = TouchpointRecord(
                id: UUID(),
                title: "\(trimmedTitle) 拍前确认",
                detailsText: "确认时间线、地点、联系人与交付要求。",
                dueAt: dueAt,
                channel: .wechat,
                priority: status == .tentative ? .high : .medium,
                isComplete: false,
                completedAt: nil,
                createdAt: .now,
                clientID: selectedClientID,
                bookingID: booking.id,
                isArchived: false,
                archivedAt: nil,
                isSystemReminderEnabled: true,
                source: .systemPreShootConfirmation
            )
            store.upsert(touchpoint: reminder)
        }

        AppHaptics.success()
        dismiss()
    }

    private func saveCurrentDraftAsTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = trimmedTitle.isEmpty ? "\(category.title)模板" : trimmedTitle
        let durationHours = max(Int((endAt.timeIntervalSince(startAt) / 3_600).rounded()), 1)
        let depositRatio = normalizedFee > 0 ? min(max(normalizedDeposit / normalizedFee, 0), 1) : store.settings.defaultDepositRatio

        let template = BookingTemplate(
            name: name.isEmpty ? fallbackName : name,
            category: category,
            defaultDurationHours: durationHours,
            defaultPrice: normalizedFee,
            defaultDepositRatio: depositRatio,
            defaultReminderDays: 3,
            defaultDeliverableText: deliverableText.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultNotesText: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultShootingAttributes: ShootingAttribute.defaultSelection(for: category),
            isUserCreated: true
        )
        store.upsert(template: template)
    }

    private func applyStoreDefaultsIfNeeded() {
        guard venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        venue = store.settings.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        notesText = store.settings.defaultNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shiftEndDate(from oldValue: Date, to newValue: Date) {
        let duration = endAt.timeIntervalSince(oldValue)
        endAt = max(newValue.addingTimeInterval(duration), newValue.addingTimeInterval(1_800))
    }

    private static func normalizedStartDate(from date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if components.hour == 0 && components.minute == 0 {
            components.hour = 9
            components.minute = 0
        }
        return calendar.date(from: components) ?? date
    }
}
