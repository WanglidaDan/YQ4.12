import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct BookingReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BookingReminderActivityAttributes.self) { context in
            lockScreenContent(for: context.state)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(for: context.state))
            .activityBackgroundTint(backgroundTint(for: context.state))
            .activitySystemActionForegroundColor(primaryTextColor(for: context.state))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandLeading(for: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandTrailing(for: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    islandBottom(for: context.state)
                }
            } compactLeading: {
                compactLeading(for: context.state)
            } compactTrailing: {
                compactTrailing(for: context.state)
            } minimal: {
                minimalIndicator(for: context.state)
            }
            .keylineTint(accentColor(for: context.state))
        }
    }

    private func locationText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        [state.city, state.venue, state.addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }

    private func navigationQueryText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        [state.city, state.venue, state.addressText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private func compactTimeText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        timeText(for: state.startAt)
    }

    private func countdownText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        let hours = max(Int(state.startAt.timeIntervalSince(.now) / 3_600), 0)
        switch hours {
        case 0:
            return "即将开拍"
        case 1...9:
            return "\(hours)小时后"
        default:
            return chineseMonthDayText(for: state.startAt)
        }
    }

    private func durationText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        let interval = max(state.endAt.timeIntervalSince(state.startAt), 0)
        let minutes = Int(interval / 60)
        if minutes <= 60 {
            return "\(minutes) 分钟"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(remainder) 分"
    }

    private func clientText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        let text = state.clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "未绑定客户" : text
    }

    private func contactURL(for state: BookingReminderActivityAttributes.ContentState) -> URL? {
        let digits = sanitizedPhoneNumber(state.clientPhoneNumber)
        guard digits.isEmpty == false else { return nil }
        return URL(string: "tel://\(digits)")
    }

    private func navigationURL(for state: BookingReminderActivityAttributes.ContentState) -> URL? {
        let query = navigationQueryText(for: state)
        guard query.isEmpty == false else { return nil }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://maps.apple.com/?daddr=\(encodedQuery)&dirflg=d")
    }

    @ViewBuilder
    private func lockScreenContent(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("拍摄提醒")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(secondaryTextColor(for: state))

                Spacer(minLength: 6)

                Text("\(weekdayText(for: state.startAt)) · \(chineseMonthDayText(for: state.startAt))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryTextColor(for: state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(state.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(primaryTextColor(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: 5) {
                detailLine(title: "客户", value: clientText(for: state), state: state)
                detailLine(title: "地点", value: locationText(for: state), state: state, lineLimit: 2)
                detailLine(title: "时间", value: "\(weekdayText(for: state.startAt)) \(compactTimeText(for: state))", state: state)
            }

            HStack(spacing: 10) {
                actionLink(
                    title: "导航",
                    systemImage: "location.fill",
                    url: navigationURL(for: state),
                    state: state
                )

                actionLink(
                    title: "联系客户",
                    systemImage: "phone.fill",
                    url: contactURL(for: state),
                    state: state
                )
            }
        }
    }

    @ViewBuilder
    private func islandLeading(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        HStack(alignment: .center, spacing: 8) {
            brandMark(size: 18, state: state)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(clientText(for: state))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryTextColor(for: state))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func islandTrailing(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(compactTimeText(for: state))
                .font(.subheadline.monospacedDigit().weight(.bold))
            Text(countdownText(for: state))
                .font(.caption2.weight(.medium))
                .foregroundStyle(secondaryTextColor(for: state))
        }
        .multilineTextAlignment(.trailing)
    }

    @ViewBuilder
    private func islandBottom(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(locationText(for: state), systemImage: "location.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondaryTextColor(for: state))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(weekdayText(for: state.startAt))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondaryTextColor(for: state))
            }

            HStack(spacing: 10) {
                actionLink(
                    title: "导航",
                    systemImage: "location.fill",
                    url: navigationURL(for: state),
                    state: state
                )

                actionLink(
                    title: "联系客户",
                    systemImage: "phone.fill",
                    url: contactURL(for: state),
                    state: state
                )
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func compactLeading(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        HStack(spacing: 4) {
            brandMark(size: 14, state: state)
            Text("影期")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func compactTrailing(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        Text(countdownText(for: state))
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
    }

    @ViewBuilder
    private func minimalIndicator(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        ZStack {
            Circle()
                .fill(accentColor(for: state).opacity(0.22))
            brandMark(size: 14, state: state)
        }
    }

    @ViewBuilder
    private func actionLink(
        title: String,
        systemImage: String,
        url: URL?,
        state: BookingReminderActivityAttributes.ContentState
    ) -> some View {
        if let url {
            if #available(iOS 18.0, *) {
                Button(intent: OpenURLIntent(url)) {
                    actionLabel(title: title, systemImage: systemImage, state: state)
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: url) {
                    actionLabel(title: title, systemImage: systemImage, state: state)
                }
            }
        } else {
            actionLabel(title: title, systemImage: systemImage, state: state, disabled: true)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func actionLabel(
        title: String,
        systemImage: String,
        state: BookingReminderActivityAttributes.ContentState,
        disabled: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(disabled ? primaryTextColor(for: state).opacity(0.38) : primaryTextColor(for: state))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(primaryTextColor(for: state).opacity(disabled ? 0.05 : 0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke(primaryTextColor(for: state).opacity(disabled ? 0.06 : 0.10), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func detailLine(
        title: String,
        value: String,
        state: BookingReminderActivityAttributes.ContentState,
        lineLimit: Int = 1
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor(for: state))
                .frame(width: 34, alignment: .leading)

            Text(value.isEmpty ? "暂无" : value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(primaryTextColor(for: state))
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func detailCard(
        title: String,
        value: String,
        lineLimit: Int = 1,
        state: BookingReminderActivityAttributes.ContentState
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor(for: state))

            Text(value.isEmpty ? "暂无" : value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(primaryTextColor(for: state))
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: lineLimit > 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(primaryTextColor(for: state).opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primaryTextColor(for: state).opacity(0.10), lineWidth: 1)
        }
    }

    private func cardBackground(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(backgroundGradient(for: state))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(primaryTextColor(for: state).opacity(0.14), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(accentColor(for: state).opacity(0.16))
                    .frame(width: 108, height: 108)
                    .blur(radius: 22)
                    .offset(x: 20, y: -12)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(primaryTextColor(for: state).opacity(0.05))
                    .frame(width: 132, height: 132)
                    .blur(radius: 28)
                    .offset(x: -20, y: 28)
            }
    }

    private func backgroundGradient(for state: BookingReminderActivityAttributes.ContentState) -> LinearGradient {
        let palette = state.themeStyle.palette
        return LinearGradient(
            colors: [
                Color(uiColor: palette.deepLight),
                Color(uiColor: palette.primaryLight.mixed(with: palette.deepLight, ratio: 0.18)),
                Color(uiColor: palette.primaryLight.mixed(with: palette.softLight, ratio: 0.12))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func backgroundTint(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        Color(uiColor: state.themeStyle.palette.deepLight)
    }

    private func accentColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        Color(uiColor: state.themeStyle.palette.primaryLight)
    }

    private func panelBackgroundColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        let palette = state.themeStyle.palette
        return Color(uiColor: palette.surfaceLight.mixed(with: palette.primaryLight, ratio: 0.12)).opacity(0.92)
    }

    private func primaryTextColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        let palette = state.themeStyle.palette
        return Color(uiColor: palette.surfaceLight.mixed(with: UIColor.white, ratio: 0.18))
    }

    private func secondaryTextColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        primaryTextColor(for: state).opacity(0.76)
    }

    @ViewBuilder
    private func brandMark(size: CGFloat, state: BookingReminderActivityAttributes.ContentState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor(for: state),
                            Color(uiColor: state.themeStyle.palette.deepLight)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("影")
                .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor(for: state))
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .stroke(primaryTextColor(for: state).opacity(0.14), lineWidth: 1)
        }
    }

    private func weekdayText(for date: Date) -> String {
        Self.chineseWeekdayText(for: date)
    }

    private func sanitizedPhoneNumber(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }

    private func timeText(for date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func chineseMonthDayText(for date: Date) -> String {
        Self.monthDayFormatter.string(from: date)
    }

    private static let chineseLocale = Locale(identifier: "zh_CN")
    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = chineseLocale
        return calendar
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = gregorianCalendar
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = gregorianCalendar
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let chineseWeekdays = [
        "周日", "周一", "周二", "周三", "周四", "周五", "周六"
    ]

    private static func chineseWeekdayText(for date: Date) -> String {
        let weekday = gregorianCalendar.component(.weekday, from: date)
        let index = max(0, min(weekday - 1, chineseWeekdays.count - 1))
        return chineseWeekdays[index]
    }
}
