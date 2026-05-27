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

    private func shortLocationText(for state: BookingReminderActivityAttributes.ContentState) -> String {
        let venue = state.venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if venue.isEmpty == false { return venue }

        let city = state.city.trimmingCharacters(in: .whitespacesAndNewlines)
        if city.isEmpty == false { return city }

        return "地点待补充"
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
        let secondsUntilStart = state.startAt.timeIntervalSince(.now)
        let secondsUntilEnd = state.endAt.timeIntervalSince(.now)

        if secondsUntilStart <= 0 && secondsUntilEnd > 0 {
            return "拍摄中"
        }

        if secondsUntilStart <= 0 {
            return "已结束"
        }

        let minutes = Int(ceil(secondsUntilStart / 60))
        if minutes < 60 {
            return "\(max(minutes, 1))分钟后"
        }

        let hours = Int(ceil(secondsUntilStart / 3_600))
        if hours <= 24 {
            return "\(hours)小时后"
        }

        return chineseMonthDayText(for: state.startAt)
    }

    private func scheduleLine(for state: BookingReminderActivityAttributes.ContentState) -> String {
        "\(weekdayText(for: state.startAt)) \(chineseMonthDayText(for: state.startAt)) \(timeText(for: state.startAt))"
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                brandMark(size: 30, state: state)

                VStack(alignment: .leading, spacing: 2) {
                    Text("影期拍摄提醒")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryTextColor(for: state))
                    Text(countdownText(for: state))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryTextColor(for: state))
                        .monospacedDigit()
                }

                Spacer(minLength: 6)

                Text(compactTimeText(for: state))
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(primaryTextColor(for: state))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryTextColor(for: state))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    Label(clientText(for: state), systemImage: "person.fill")
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(secondaryTextColor(for: state).opacity(0.6))
                    Label(shortLocationText(for: state), systemImage: "location.fill")
                        .lineLimit(1)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(secondaryTextColor(for: state))
            }

            Divider()
                .overlay(primaryTextColor(for: state).opacity(0.12))

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("拍摄时间")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryTextColor(for: state))
                    Text(scheduleLine(for: state))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(primaryTextColor(for: state))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    actionLink(
                        title: "导航",
                        systemImage: "location.fill",
                        url: navigationURL(for: state),
                        state: state
                    )

                    actionLink(
                        title: "联系",
                        systemImage: "phone.fill",
                        url: contactURL(for: state),
                        state: state
                    )
                }
                .frame(maxWidth: 176)
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
                Text(shortLocationText(for: state))
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryTextColor(for: state))
        }
        .multilineTextAlignment(.trailing)
    }

    @ViewBuilder
    private func islandBottom(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(scheduleLine(for: state), systemImage: "clock.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondaryTextColor(for: state))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(clientText(for: state))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(primaryTextColor(for: state))
                    .lineLimit(1)
            }

            Label(locationText(for: state).isEmpty ? "地点待补充" : locationText(for: state), systemImage: "location.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(secondaryTextColor(for: state))
                .lineLimit(1)

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
            Text("拍摄")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func compactTrailing(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        Text(countdownText(for: state))
            .font(.caption2.monospacedDigit().weight(.semibold))
            .lineLimit(1)
    }

    @ViewBuilder
    private func minimalIndicator(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        ZStack {
            Circle()
                .fill(accentColor(for: state).opacity(0.28))
            Image(systemName: "camera.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(primaryTextColor(for: state))
        }
        .frame(width: 18, height: 18)
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
        .font(.caption.weight(.semibold))
        .foregroundStyle(disabled ? primaryTextColor(for: state).opacity(0.38) : primaryTextColor(for: state))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(primaryTextColor(for: state).opacity(disabled ? 0.05 : 0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(primaryTextColor(for: state).opacity(disabled ? 0.06 : 0.12), lineWidth: 1)
        }
    }

    private func cardBackground(for state: BookingReminderActivityAttributes.ContentState) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(backgroundGradient(for: state))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(primaryTextColor(for: state).opacity(0.14), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(accentColor(for: state).opacity(0.14))
                    .frame(width: 112, height: 112)
                    .blur(radius: 24)
                    .offset(x: 18, y: -18)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(primaryTextColor(for: state).opacity(0.045))
                    .frame(width: 136, height: 136)
                    .blur(radius: 30)
                    .offset(x: -24, y: 32)
            }
    }

    private func backgroundGradient(for state: BookingReminderActivityAttributes.ContentState) -> LinearGradient {
        let palette = state.themeStyle.palette
        return LinearGradient(
            colors: [
                Color(uiColor: palette.deepLight.mixed(with: UIColor.black, ratio: 0.12)),
                Color(uiColor: palette.primaryLight.mixed(with: palette.deepLight, ratio: 0.36)),
                Color(uiColor: palette.primaryLight.mixed(with: palette.softLight, ratio: 0.18))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func backgroundTint(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        Color(uiColor: state.themeStyle.palette.deepLight.mixed(with: UIColor.black, ratio: 0.10))
    }

    private func accentColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        Color(uiColor: state.themeStyle.palette.softLight.mixed(with: state.themeStyle.palette.primaryLight, ratio: 0.44))
    }

    private func primaryTextColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        Color(uiColor: state.themeStyle.palette.surfaceLight.mixed(with: UIColor.white, ratio: 0.22))
    }

    private func secondaryTextColor(for state: BookingReminderActivityAttributes.ContentState) -> Color {
        primaryTextColor(for: state).opacity(0.74)
    }

    @ViewBuilder
    private func brandMark(size: CGFloat, state: BookingReminderActivityAttributes.ContentState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(primaryTextColor(for: state).opacity(0.12))

            Image(systemName: "camera.fill")
                .font(.system(size: size * 0.48, weight: .bold))
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
