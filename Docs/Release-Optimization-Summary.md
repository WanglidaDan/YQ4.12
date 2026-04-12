# 送审前最终整改摘要

最后更新：2026-03-23

## 代码与工程清理
- 删除未使用的 `Support/BusinessModulesSupport.swift`
- 删除未启用的 `Support/StudioLocationService.swift`
- 清理 `.derived`、`.codex-home`、`__MACOSX`、`xcuserdata` 等无用文件
- 工程改为竖屏，降低横屏适配风险

## 功能收口
- “系统日历 / Google Calendar 双向同步”改为“外部日历整备”
- “多人实时协作”改为“团队权限与操作留痕”
- 当前正式版不默认启用定位、天气、系统日历写入或 Google Calendar 自动同步

## 数据与安全
- 付款状态、已收金额、待回款统一使用付款流水口径
- Apple ID 与工作区隔离增强
- Google Calendar 敏感凭证不再进入普通快照与备份
- 完整备份升级为包含附件资料的备份包

## 性能优化
- 付款缓存：按订单缓存付款流水与付款汇总
- 关系缓存：按客户缓存订单与跟进
- 报表缓存：经营分析改为缓存快照，减少重复计算
- 附件导入补齐 security-scoped 访问与 MIME 识别

## 送审材料
- 更新 App Store Listing 模板
- 更新 Review Notes 模板
- 更新 Privacy Policy 模板与 HTML 页面
- 更新 Support 页面模板与 HTML 页面
