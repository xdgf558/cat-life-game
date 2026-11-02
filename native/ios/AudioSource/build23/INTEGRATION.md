# 原生音频接入说明 — 0.5.0（23）

本文依据当前源码记录音频接线与行为，供后续维护和验收使用。资产来源、编码与信号指标见 [README](README.md)、[manifest.json](manifest.json) 和 [资产 QA](../../QA/audio-build23/audio-assets-verification.json)。这里不把源码行为、数值检查或播放器状态等同于真实设备的听觉验收。

## 播放器与会话

[GameAudioController](../../CatLife/AudioRuntime/GameAudioController.swift) 是 `GameStore` 持有的单一音频控制器，通过 `AVAudioPlayer` 读取包内 `Audio/*.caf`。播放器及可观察状态由 `MainActor` 管理；可能等待系统服务的 `AVAudioSession.setCategory` 和 `setActive` 则交给专用串行 `sessionQueue` 异步执行，完成结果再返回主线程，避免会话激活或停用阻塞 UI。每次激活使用 `AVAudioSession.Category.ambient`、`.default` 模式，没有录音需求，也不请求麦克风权限。`.ambient` 的系统契约是允许与其他音频混合，并受响铃/静音状态及锁屏影响；这是 Apple 文档定义，不代表已经在本轮真机逐项验证。[Apple：Audio Session Categories and Modes](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionCategoriesandModes/AudioSessionCategoriesandModes.html)

控制器还主动查询 `secondaryAudioShouldBeSilencedHint`：系统要求次要音频让位时暂停游戏 BGM，保留音效自身的开关和触发规则；提示变化时重新评估，而不缓存过期状态。加载未完成、读档失败或应用不在前台时不播放。

背景音乐设置 `numberOfLoops = -1`。更换曲目时新旧音乐以约 0.6 秒交叉淡化，旧播放器约 0.65 秒后停止；同一曲目恢复或调整音量使用约 0.25 秒淡入。当前播放位置仅存在内存中，不写入存档。音效启用时，会话成功激活后为每种资源准备两个播放器，实际播放前也有相同的延迟准备入口；全局最多同时播放四个。同种音效最小触发间隔为普通音效 0.15 秒、点击 0.065 秒、猫叫 1.2 秒，触发频率或同时播放数量超过限制的请求直接忽略。

只要有任一类声音启用且音量大于零，欢迎页准备完成或回到前台时就会请求激活会话，即使只开启音效也如此。异步激活期间最多暂存四条音效请求；同种音效同时按最近已播放和最近待播放时间限流。成功激活后仅播放请求年龄不超过 0.5 秒、且仍满足前台、开关及并发条件的音效，过期请求直接丢弃，因此不会在系统激活缓慢后补播一长串声音。激活失败会清空待播请求并保持静音，不从失败回调立即重试；后续前台、配置变化或用户操作才可能发起新尝试。

会话停用会递增 `sessionGeneration`，清空待播音效并作废正在进行的激活结果。进入后台、尚未准备好、音频中断、原输出设备不可用、全部声音关闭或归零，以及媒体服务重置均会走相应的失效处理。停用操作与激活操作在同一串行队列中排序；旧激活完成回到主线程时必须核对 generation，过期结果不能重新发布 active 状态或启动播放器。仅关闭音效时也会立即清空待播音效，但如果音乐仍可播放则保留会话。

## 背景音乐选择

[GameStore.syncAudio()](../../CatLife/Store/GameStore.swift) 在存档快照、功能页、前后台及进入小家的状态变化时同步场景。优先级按下表从上到下判断；打开其他功能页不会终止正在进行的打工或睡眠背景音乐。

| 条件 | 曲目 |
| --- | --- |
| 仍在欢迎页、尚未进入小家 | `bgm-home.caf`，成功读档并完成启动准备后才允许播放 |
| 已进入小家，玩家存在 `activeSleep` | `bgm-sleep.caf` |
| 已进入小家，没有睡眠，存在 `activeWork` 或当前打开打工页 | `bgm-work.caf` |
| 其余状态 | `bgm-home.caf` |

这里的 sleep 指玩家睡眠状态，猫跳上猫窝或坐垫休息不会切换睡眠音乐。

## 十二种音效的实际触发点

| 文件 | 当前触发行为 |
| --- | --- |
| `sfx-tap.caf` | 功能弹页打开或关闭、设置页显示状态改变、布置模式改变；通用成功操作的 `ActionKind.none` 也使用此音效。并非所有 SwiftUI 控件都有全局点击拦截。 |
| `sfx-enter.caf` | 用户在欢迎页点击进入小家且进入条件成立。若有等待展示的打工结算，则改播完成音效。 |
| `sfx-purchase.caf` | `ActionKind.purchase` 成功且保存完成，例如购买补给或家具。 |
| `sfx-work-start.caf` | `ActionKind.workStarted` 成功且保存完成。 |
| `sfx-work-complete.caf` | 打工完成同步及保存成功，或进入小家时展示已有的待处理打工结果；受前台及音效开关限制。 |
| `sfx-place.caf` | `ActionKind.layout` 成功且保存完成，包括提交布局等对应操作；不是拖动每一帧都发声。 |
| `sfx-feed.caf` | 正常动作中，猫完成靠近、对碗与低头动作，播放到第一口接触粮的动画位置后触发一次；不是扣除猫粮的瞬间。 |
| `sfx-clean.caf` | 清洁动作序列实际开始时触发一次，与猫的表情及抖动动作相连。 |
| `sfx-play.caf` | 正常扑玩动作完成跃起、到达落地段时触发一次。 |
| `sfx-cat-meow.caf` | 点房间里的猫查看猫咪时，以及声音设置中的试听按钮；不做定时自动叫声。 |
| `sfx-sleep.caf` | 玩家 `ActionKind.sleepStarted` 成功且保存完成。 |
| `sfx-wake.caf` | 玩家 `ActionKind.sleepEnded` 成功且保存完成。 |

普通状态操作走 [GameStore.perform / playCommittedSound](../../CatLife/Store/GameStore.swift)：先计算候选状态，成功保存并更新快照后，才发布场景反馈和操作音效。保存失败保留旧状态并显示存档错误，不播放该操作的成功音。导航、查看猫和设置试听本身没有存档变更，因此可直接发声。

照料音效的链路为 `GameStore` 保存成功后的 `RoomFeedback` → [RoomScene](../../CatLife/Scene/RoomScene.swift) → [CatActor](../../CatLife/Scene/CatActor.swift) 动作中的 `onSound` → [RoomSceneHost](../../CatLife/Views/RoomSceneHost.swift) → `GameStore.playSceneSound` → 控制器。喂食路径校验失败时仅执行替代表情，不提前播放正常进食音效。启用“减弱动态效果”时，喂食、清洁、玩耍均使用简化表情序列，并在该序列开始时发出对应音效，因此该模式没有完整移动、抖动或落地的同步点。

## 独立设置及存档

[SettingsView](../../CatLife/Views/SettingsView.swift) 的二级声音页面提供背景音乐与交互音效两个独立开关、两个独立音量滑块和猫叫试听。默认均开启，音乐音量 35%，音效音量 65%；滑块范围 0–100%，步长 5%。关闭某类声音保留其音量设置，音效关闭或归零时立即停止正在播放的音效。

设置保存在既有存档的 `settings.audio` 中，字段为 `musicEnabled`、`effectsEnabled`、`musicVolume`、`effectsVolume`。开关变更、滑块拖动结束及离开声音页会尝试保存；只有保存成功的设置才应用到控制器，失败时 UI 恢复已保存值并使用正常的存档错误提示。设置保存期间禁用相关控件。

[AudioSettings](../../CatGameCore/Sources/CatGameCore/GameSettings.swift) 对缺失或错误类型字段使用默认值，对有限音量限制在 0…1，对非有限数使用默认音量。老存档没有音频字段时按默认值加载，不建立额外存档文件，也不改变既有进度字段。

## 前后台、中断和耳机路由

[RoomHomeView](../../CatLife/Views/RoomHomeView.swift) 把 SwiftUI `scenePhase == .active` 交给 `GameStore.setForeground`。离开 active 状态会暂停音乐、停止并归零短音效，以 `.notifyOthersOnDeactivation` 停用音频会话。返回前台后按当前存档状态、音量和系统提示重新选择音乐；被停止的短音效不补播。

收到中断开始通知时暂停全部声音并标记会话失效；中断结束带 `.shouldResume` 时尝试恢复音乐，没有该标志则保持暂停，等待新的显式交互或再次回到前台。由于系统不保证每次开始通知都有对应的结束通知，前台返回及显式交互也会尝试重新激活会话；如果系统拒绝激活，则保持静音。这与 Apple 对中断与会话恢复的说明一致。[Apple：Responding to Interruptions](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html)

收到 `.oldDeviceUnavailable` 路由变化时暂停全部声音，防止耳机断开后直接外放；下一次显式交互或再次回到前台可解除暂停。代码不强制扬声器、不指定蓝牙设备，也不会仅因新耳机接入而自动清除这次暂停。系统负责当前输出路由；路由丢失处理参照 Apple 的暂停建议。[Apple：Responding to Route Changes](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html)

媒体服务重置通知会暂停声音、作废当前激活结果、排入必要的会话停用，并丢弃现有音乐及音效播放器；随后按当前前台、暂停与设置条件重新请求激活和重建播放器。这个分支不更改游戏存档。

## 验收边界

资源清单、编码与信号验证已经单独记录；源码中的 `musicPlaying`、音效计数和加载失败计数可辅助集成测试，但它们不能证明扬声器实际出声，也不能检测用户听到的音量或静音开关效果。

本说明不宣称真实静音开关、锁屏、电话或 Siri 中断、蓝牙连接与断开、不同耳机的输出切换已经完成真机验收。真实设备的扬声器/耳机试听、三首音乐的循环听感、猫叫自然度、动作与声音的感知同步以及游戏内混音平衡仍需主观验收；已生成的试听文件不等于已试听通过。构建、安装和真机交付状态以独立整合 QA 为准。
