# 影期 YQ4.12

影期是一个面向摄影师个人与摄影工作室的 iOS 管理工具，用来处理档期、客户、跟进、团队分工与回款记录等日常经营事务。

这个仓库当前对应的是 `YQ4.12` 公开版本，重点放在更稳定的业务流程、送审收口和更清晰的工作台体验。

## 项目简介

影期希望把摄影工作里分散的安排整合到一个应用里，帮助团队更清楚地看到：

- 今天要做什么
- 谁负责哪场拍摄
- 每位客户处于什么跟进阶段
- 每笔订单的回款和待收状态
- 工作室资料如何备份与恢复

## 当前能力

- 档期管理：支持查看拍摄安排、多场同日拍摄和成员分工
- 客户管理：维护客户资料、等级、来源和跟进记录
- 跟进体系：记录触点、优先级、渠道和后续动作
- 经营中心：覆盖合同、报价、收据、发票等业务单据入口
- 团队协作：提供角色权限与关键操作留痕
- 回款管理：统一按付款流水统计已收、待收和状态
- 数据安全：支持本地备份恢复与显式 iCloud 同步
- 送审收口：避免宣传未正式启用的实时协作、自动日历同步等能力

## 技术栈

- Swift 5.9
- SwiftUI
- iOS 17+
- XcodeGen
- Widget / Live Activity 扩展

## 目录结构

```text
App/        应用入口与根导航
Features/   业务页面与界面模块
Models/     数据模型
Support/    存储、主题、导出、同步等基础能力
Resources/  资源文件、图标与隐私清单
Widgets/    小组件与 Live Activity
Tests/      单元测试
Docs/       上架、隐私、支持页与发布说明
Config/     构建配置与 entitlements
```

## 本地运行

### 环境要求

- Xcode 15 或更高版本
- iOS 17.0 或更高版本模拟器 / 真机
- 已安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 启动步骤

1. 安装 XcodeGen
2. 在仓库根目录执行 `xcodegen generate`
3. 打开 `YingQi.xcodeproj`
4. 选择 `YingQi` Scheme 后运行

如果你只想快速查看工程结构，也可以直接打开仓库内已有的 `YingQi.xcodeproj`。

## 测试与校验

当前仓库包含基础测试：

- `Tests/OverviewSnapshotBuilderTests.swift`
- `Tests/ReleaseReadinessTests.swift`

建议在提交或发版前重点验证以下场景：

- 一天多场拍摄时的档期展示
- 订单详情中的回款编辑与统计
- 客户与跟进数据的联动
- 备份导出与恢复流程
- 游客模式、登录流程与 iCloud 同步入口

## 文档

`Docs/` 目录中已经包含和上架、支持、隐私相关的说明，例如：

- `Docs/Release-Checklist.md`
- `Docs/Release-Optimization-Summary.md`
- `Docs/Feature-Expansion-Summary.md`
- `Docs/AppStore-Privacy-Policy.md`
- `Docs/AppStore-Support-Page.md`

## 仓库说明

这个仓库当前主要用于公开展示 `影期重制版 4.12` 的工程代码与发布资料整理结果。

如需继续演进功能，建议优先补充：

- 更完整的安装与演示截图
- 数据结构说明
- 构建签名与发布配置说明
- 更多自动化测试
