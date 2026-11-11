# 0.21.1（66）TestFlight 上传记录

2026-11-10 23:27:02（GMT+8），Xcode 返回 `Upload succeeded`、`EXPORT SUCCEEDED` 和 `Uploaded package is processing`。上传成功且 Apple 已开始处理；本次未确认处理完成或开放测试，未关联群组、邀请测试者或提交 Beta Review。内测、外测由用户手动添加。

PR #28 已合并，main 提交为 `aa89f1d8a8b22f310c3a8cdf09974bb49f8005da`，完整源码树与审查通过的 `a00086b3583c83f1c7ebded0c512fd80c5f7b4ec` 一致。从 main 新建签名归档并上传，没有使用复审修复前的候选。目标 App ID 为6830428076，Bundle ID为com.stationcat.catlife.native，版本0.21.1（66），最低iOS17。

归档、严格签名、有效描述文件、匹配dSYM、隐私清单、45份音频及61个测试启动参数隔离均通过。归档采用开发签名，Xcode导出时进行App Store重签；实际分发包的`get-task-allow=false`，无设备列表，Team与Bundle匹配。上传前后510项生产源码、配置和资源指纹全部一致。配置不自动修改版本号，未限制为Internal Only。

复用同源码的423项Core、344项App和SE/Pro各3次交互回归，共5个不同UI方法、6次执行全通过；本次未把这些记成合并后重跑。完整功能范围与原始失败的说明见[房间修复QA摘要](front-room-build66-summary.md)。原始归档、签名与分发验证、日志、截图、xcresult均保存在仓库外。

本轮未安装真机、读取或修改玩家存档。真机触摸、VoiceOver、八级密集家具/五猫/三视角的性能和耗电未测。正式上架前仍需把更新入口切换为App Store链接，并限制内部观察测试入口。
