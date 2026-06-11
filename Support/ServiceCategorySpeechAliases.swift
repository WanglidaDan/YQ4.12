import Foundation

extension ServiceCategory {
    /// 语音解析中“跟拍 / 纪实”优先归入活动类目，避免引用项目中可能不存在的纪录片枚举值影响 Archive。
    static var documentary: ServiceCategory { .event }
}
