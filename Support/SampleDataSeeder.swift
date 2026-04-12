import Foundation

enum SampleDataSeeder {
    static func makeSnapshot(now: Date = .now) -> StudioStoreSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        let weddingClientID = UUID()
        let brandClientID = UUID()
        let familyClientID = UUID()
        let portraitClientID = UUID()
        let eventClientID = UUID()
        let maternityClientID = UUID()

        let weddingBookingID = UUID()
        let brandBookingID = UUID()
        let familyBookingID = UUID()
        let portraitBookingID = UUID()
        let eventBookingID = UUID()
        let middayBookingID = UUID()
        let maternityBookingID = UUID()

        let weddingClient = ClientRecord(
            id: weddingClientID,
            name: "宋知意",
            city: "上海",
            phoneNumber: "13800001111",
            sourceChannel: "转介绍",
            notesText: "偏好纪实感，流程稳定比复杂机位更重要。",
            stage: .booked,
            tier: .signature,
            createdAt: now.addingTimeInterval(-86_400 * 28),
            lastContactAt: now.addingTimeInterval(-86_400),
            nextContactAt: now.addingTimeInterval(86_400)
        )

        let brandClient = ClientRecord(
            id: brandClientID,
            name: "Lumen Atelier",
            city: "杭州",
            phoneNumber: "13700002222",
            sourceChannel: "社媒咨询",
            notesText: "春季 campaign 进入二轮报价，可能追加短视频套餐。",
            stage: .negotiating,
            tier: .focus,
            createdAt: now.addingTimeInterval(-86_400 * 15),
            lastContactAt: now.addingTimeInterval(-86_400 * 2),
            nextContactAt: now.addingTimeInterval(86_400 * 2)
        )

        let familyClient = ClientRecord(
            id: familyClientID,
            name: "林嘉禾一家",
            city: "苏州",
            phoneNumber: "13600003333",
            sourceChannel: "老客复购",
            notesText: "全家福已拍，关注相册封面与交付体验。",
            stage: .retained,
            tier: .focus,
            createdAt: now.addingTimeInterval(-86_400 * 45),
            lastContactAt: now.addingTimeInterval(-86_400 * 3),
            nextContactAt: now.addingTimeInterval(86_400 * 4)
        )

        let portraitClient = ClientRecord(
            id: portraitClientID,
            name: "周屿",
            city: "南京",
            phoneNumber: "13900004444",
            sourceChannel: "Instagram",
            notesText: "个人品牌形象照，希望平日傍晚开拍。",
            stage: .discovery,
            tier: .standard,
            createdAt: now.addingTimeInterval(-86_400 * 8),
            lastContactAt: now.addingTimeInterval(-86_400 * 4),
            nextContactAt: now.addingTimeInterval(-86_400)
        )

        let eventClient = ClientRecord(
            id: eventClientID,
            name: "曜石文化",
            city: "上海",
            phoneNumber: "13500005555",
            sourceChannel: "商务合作",
            notesText: "同一天有论坛主会场和嘉宾区，现场要靠分工板控节奏。",
            stage: .booked,
            tier: .signature,
            createdAt: now.addingTimeInterval(-86_400 * 18),
            lastContactAt: now.addingTimeInterval(-86_400),
            nextContactAt: now.addingTimeInterval(86_400 * 2)
        )

        let maternityClient = ClientRecord(
            id: maternityClientID,
            name: "许念",
            city: "上海",
            phoneNumber: "13300006666",
            sourceChannel: "微信咨询",
            notesText: "傍晚外景，重点是情绪与肢体引导。",
            stage: .booked,
            tier: .focus,
            createdAt: now.addingTimeInterval(-86_400 * 6),
            lastContactAt: now.addingTimeInterval(-86_400),
            nextContactAt: now.addingTimeInterval(86_400)
        )

        let weddingBooking = BookingRecord(
            id: weddingBookingID,
            title: "外滩婚礼全天跟拍",
            category: .wedding,
            status: .confirmed,
            startAt: date(dayOffset: 5, hour: 9),
            endAt: date(dayOffset: 5, hour: 18),
            venue: "上海外滩源壹号",
            city: "上海",
            fee: 23_800,
            depositPaid: 8_000,
            deliverableText: "精修 180 张，婚礼预告片 1 支",
            notesText: "需要提前确认 first look 时间线。",
            shootingAttributes: [.photo, .video],
            crewAssignments: [
                BookingCrewAssignment(memberName: "阿杰", role: .leadPhoto, taskText: "婚礼全天主拍", venueText: "上海外滩源壹号"),
                BookingCrewAssignment(memberName: "小李", role: .video, taskText: "仪式与接亲摄像", venueText: "宴会厅 / 接亲路线"),
                BookingCrewAssignment(memberName: "Mia", role: .coordinator, taskText: "现场统筹与流程提醒", venueText: "全场跟进")
            ],
            clientID: weddingClientID
        )

        let brandBooking = BookingRecord(
            id: brandBookingID,
            title: "春季 Lookbook 棚拍",
            category: .commercial,
            status: .tentative,
            startAt: date(dayOffset: 3, hour: 10),
            endAt: date(dayOffset: 3, hour: 17),
            venue: "天目里摄影棚",
            city: "杭州",
            fee: 16_500,
            depositPaid: 0,
            deliverableText: "静态 36 张，短视频 2 条",
            notesText: "需等客户确认模特和造型表。",
            shootingAttributes: [.photo, .video, .color],
            crewAssignments: [
                BookingCrewAssignment(memberName: "小周", role: .leadPhoto, taskText: "棚拍主机位", venueText: "天目里摄影棚"),
                BookingCrewAssignment(memberName: "小陈", role: .support, taskText: "布光与道具协调", venueText: "棚内"),
                BookingCrewAssignment(memberName: "阿森", role: .color, taskText: "后期调色", venueText: "返修阶段")
            ],
            clientID: brandClientID
        )

        let familyBooking = BookingRecord(
            id: familyBookingID,
            title: "春日家庭写真",
            category: .family,
            status: .editing,
            startAt: date(dayOffset: -3, hour: 14),
            endAt: date(dayOffset: -3, hour: 17),
            venue: "金鸡湖草坪",
            city: "苏州",
            fee: 6_200,
            depositPaid: 6_200,
            deliverableText: "精修 48 张，相册 1 本",
            notesText: "本周需要发出相册封面方案。",
            shootingAttributes: [.photo],
            crewAssignments: [
                BookingCrewAssignment(memberName: "小米", role: .leadPhoto, taskText: "家庭写真主拍", venueText: "金鸡湖草坪")
            ],
            clientID: familyClientID
        )

        let portraitBooking = BookingRecord(
            id: portraitBookingID,
            title: "创作者形象照",
            category: .portrait,
            status: .inquiry,
            startAt: date(dayOffset: 11, hour: 16),
            endAt: date(dayOffset: 11, hour: 19),
            venue: "鼓楼工作室",
            city: "南京",
            fee: 3_800,
            depositPaid: 0,
            deliverableText: "精修 12 张",
            notesText: "先给妆造与服装参考。",
            shootingAttributes: [.photo],
            clientID: portraitClientID
        )

        let eventBooking = BookingRecord(
            id: eventBookingID,
            title: "品牌论坛上午场",
            category: .event,
            status: .confirmed,
            startAt: date(dayOffset: 0, hour: 9),
            endAt: date(dayOffset: 0, hour: 12),
            venue: "西岸艺术中心",
            city: "上海",
            fee: 8_800,
            depositPaid: 4_000,
            deliverableText: "论坛纪实照 + 嘉宾短采访",
            notesText: "主会场、签到区、嘉宾区要同时覆盖。",
            shootingAttributes: [.photo, .video],
            crewAssignments: [
                BookingCrewAssignment(memberName: "小周", role: .leadPhoto, taskText: "主会场主拍", venueText: "主舞台"),
                BookingCrewAssignment(memberName: "Mia", role: .coordinator, taskText: "嘉宾接待与流程串联", venueText: "签到区 / 会场"),
                BookingCrewAssignment(memberName: "阿森", role: .video, taskText: "嘉宾采访与花絮", venueText: "嘉宾区")
            ],
            clientID: eventClientID
        )

        let middayBooking = BookingRecord(
            id: middayBookingID,
            title: "品牌补拍半日",
            category: .commercial,
            status: .shooting,
            startAt: date(dayOffset: 0, hour: 13),
            endAt: date(dayOffset: 0, hour: 16),
            venue: "静安工作室",
            city: "上海",
            fee: 4_800,
            depositPaid: 2_000,
            deliverableText: "精修 20 张",
            notesText: "今天补拍配饰与细节页素材。",
            shootingAttributes: [.photo, .video],
            crewAssignments: [
                BookingCrewAssignment(memberName: "阿杰", role: .leadPhoto, taskText: "产品主照片", venueText: "静安工作室"),
                BookingCrewAssignment(memberName: "小李", role: .video, taskText: "花絮与短视频", venueText: "静安工作室")
            ],
            clientID: brandClientID
        )

        let maternityBooking = BookingRecord(
            id: maternityBookingID,
            title: "孕妈傍晚外景",
            category: .maternity,
            status: .confirmed,
            startAt: date(dayOffset: 0, hour: 17),
            endAt: date(dayOffset: 0, hour: 20),
            venue: "滨江步道",
            city: "上海",
            fee: 5_600,
            depositPaid: 2_000,
            deliverableText: "精修 28 张 + 预告短片 1 条",
            notesText: "黄金日落时段，现场多做引导。",
            shootingAttributes: [.photo, .video],
            crewAssignments: [
                BookingCrewAssignment(memberName: "阿杰", role: .leadPhoto, taskText: "外景主拍", venueText: "滨江步道"),
                BookingCrewAssignment(memberName: "Mia", role: .coordinator, taskText: "妆造补位与节奏提醒", venueText: "外景全程")
            ],
            clientID: maternityClientID
        )

        let touchpoints = [
            TouchpointRecord(
                title: "发送婚礼时间线确认表",
                detailsText: "确认接亲流程、彩排时间和宴会厅入场节点。",
                dueAt: now.addingTimeInterval(86_400),
                channel: .wechat,
                priority: .urgent,
                clientID: weddingClientID,
                bookingID: weddingBookingID
            ),
            TouchpointRecord(
                title: "推进 lookbook 二轮报价",
                detailsText: "补充短视频工时说明，争取本周锁定档期。",
                dueAt: now.addingTimeInterval(3600 * 8),
                channel: .email,
                priority: .high,
                clientID: brandClientID,
                bookingID: brandBookingID
            ),
            TouchpointRecord(
                title: "确认相册封面方案",
                detailsText: "准备两版封面提案供客户选择。",
                dueAt: now.addingTimeInterval(86_400 * 3),
                channel: .wechat,
                priority: .medium,
                clientID: familyClientID,
                bookingID: familyBookingID
            ),
            TouchpointRecord(
                title: "发送形象照风格参考",
                detailsText: "先发 3 组职业向样片，缩短客户决策时间。",
                dueAt: now.addingTimeInterval(-3600 * 10),
                channel: .wechat,
                priority: .high,
                clientID: portraitClientID,
                bookingID: portraitBookingID
            ),
            TouchpointRecord(
                title: "核对论坛分工板",
                detailsText: "把主会场、嘉宾区和签到区负责人在拍摄前一天发给客户。",
                dueAt: date(dayOffset: -1, hour: 18),
                channel: .wechat,
                priority: .urgent,
                clientID: eventClientID,
                bookingID: eventBookingID
            ),
            TouchpointRecord(
                title: "确认孕妈外景集合点",
                detailsText: "把停车点、集合时间和服装清单再确认一遍。",
                dueAt: date(dayOffset: 0, hour: 11),
                channel: .wechat,
                priority: .high,
                clientID: maternityClientID,
                bookingID: maternityBookingID
            )
        ]

        return StudioStoreSnapshot(
            clients: [weddingClient, brandClient, familyClient, portraitClient, eventClient, maternityClient],
            bookings: [weddingBooking, brandBooking, familyBooking, portraitBooking, eventBooking, middayBooking, maternityBooking],
            touchpoints: touchpoints
        )
    }
}
