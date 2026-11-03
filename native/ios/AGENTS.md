# 原生 iOS 版本发布规则

本文件适用于 `native/ios` 下的原生项目；仓库根目录的其它约束继续生效。

- 每次向玩家交付新的更新，必须同时提升 `CatLife/Info.plist` 中的 `CFBundleShortVersionString`（对外版本号）并递增 `CFBundleVersion`（构建号），不能只改变构建号。
- 修复或界面微调递增 patch，例如 `0.1.0 → 0.1.1`；明显功能迭代递增 minor，例如 `0.1.x → 0.2.0`；主版本按发布规划调整。
- 同一次尚未发布更新的调试可以保留对外版本号；新安装包的构建号按需要递增。此例外不适用于已向玩家交付后发生的新更新。
- 同步 `CatLife/Views/SettingsView.swift` 中 `AppRelease.history` 的当前记录、`CatLife/Localization/GameStrings.swift` 中对应的三语更新文案，以及版本相关测试期望。最近已交付版本为 `0.7.1 (32)`。
- 历史已发布记录不可回写版本号、构建号或日期。第13版及更早版本实际发布为 `0.1.0`，保留原记录；文档和 QA 应区分准备包、已构建验证和已安装交付，不把旧包结果当作新包结果。
