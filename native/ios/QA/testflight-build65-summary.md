# TestFlight 0.21.0（65）发布记录

2026-11-10 18:50（GMT+8），Xcode 返回 `Upload succeeded` / `EXPORT SUCCEEDED`，并确认 `Uploaded package is processing`。**上传成功、Apple 已开始处理；尚未确认处理完成、Beta Review 或测试开放。** 目标 App ID 6830428076，Bundle ID com.stationcat.catlife.native。未修改测试组、邀请测试者或提交测试审核，内外测与审核分发由用户手动添加。

PR #27 与 #26 已依次合并。归档来自 main 提交 `960bac0b90ad25609147a486116044cced68e493`，源码树 `06145f2d28f40a3057b07e8b13e979906515ce3f` 与通过回归的 `56f927b` 完全一致；上传前后 507 项生产输入指纹保持。0.20.1（64）与原 0.21.0（63）候选未单独上传，本次一并交付。

新建签名 Release 归档 `CatLife-0.21.0-65-main.xcarchive`，版本、Bundle ID、严格签名、有效描述文件、dSYM UUID、隐私清单、45 份音频及 61 个 UI 测试启动参数隔离通过。自动开发描述文件允许通配 App ID，按实际签名中的精确应用 ID 验证匹配；App Store 导出完成分发重签，实际分发包严格签名有效、`get-task-allow=false`，描述文件不包含开发设备列表。没有自动调整版本号，没有选择 Internal Only。

归档二进制 SHA-256：`c0985540bcdc4270cd52ebbe3dc7820650bb4525b0b5eabfdab841b1a0c88bd9`。

实际分发重签后二进制 SHA-256：`ce50a2562689073f34f6b9b5d49f490138319dcb7fe152cee0fb6459e892e44a`。

复用同源码的 414 项 Core、328 项 App 全量通过记录及 15 个不同 UI 方法分轮通过记录，本次不计作重新执行测试；具体范围和历史失败见 [Build 65 整合摘要](cat-habits-build65-summary.md)。H1/H2/H3 真人观察、真实 VoiceOver/触感、密集家具/五猫/三视角与一起玩场景的真机帧率和耗电仍待验收，自动化和上传不能替代这些结论。当前为 Beta；正式 App Store 分发前仍需隐藏内部观察说明，并切换更新链接。

原始归档、上传日志、签名/分发验证 JSON 与输入指纹留在 Git 外，只提交脱敏发布摘要和 [可复制的测试重点](cat-habits-build65-test-notes.txt)。不覆盖用户已经在工作区删除的旧 Distribution 文件。本次未安装真实设备，未读取或修改玩家存档，网页版保持独立。
