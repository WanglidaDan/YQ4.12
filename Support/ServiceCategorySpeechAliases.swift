import Foundation

extension ServiceCategory {
    /// 语音解析中“跟拍 / 纪实”统一归入纪录片类目，避免新增不存在的枚举 case 影响 Archive。
    static var documentary: ServiceCategory { .documentaryFilm }
}
