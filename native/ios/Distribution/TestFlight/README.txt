打工养猫日记 · TestFlight 0.9.2（37）

发布状态（2026-11-04）：Release 归档和本地签名、隐私入包检查已完成，尚未上传；不代表已获批或已向测试者开放。
目标 App Store Connect App：待核对或创建。最初提供的链接包含 App ID 6822797145，但尚未确认它属于本游戏，不作为已核对的上传目标。
本地 Bundle ID：com.stationcat.catlife.native
发布分支：codex/testflight-0.9.2
下方“测试版介绍”“测试重点”“审核备注”可分别粘贴到 TestFlight 对应字段，内外部测试使用同一套说明。

简体中文 · 测试版介绍
这是一款温暖的单机养猫生活游戏。通过打工积累金币和经验，照料与领养猫咪，装扮角色并布置小家。本次测试重点是成长任务、日常照料、打工结算以及更新后的存档兼容。游戏提供简体中文、繁体中文和英语。

简体中文 · 测试重点
- 任务：成功领取奖励后，返回列表且该任务隐藏；检查金币与经验只增加一次。提升打工等级至 2、4、6、10 时，检查新增目标；每页最多显示 3 项，翻页和空列表提示应正常。
- 照料：尝试喂食、清洁、陪玩，以及切换陪伴猫，检查猫咪动作、属性变化和用品消耗是否一致。
- 打工恢复：开始打工后切到后台，再返回游戏；检查剩余时间、完成结算与奖励，重复打开页面不应重复到账。
- 房间：尝试摆放、拖动和回收家具；升级房间后，用双指缩放并检查家具点击、猫咪移动是否正常。
- 存档：已有安装请直接覆盖更新；关闭再打开游戏，检查角色与猫咪名字、金币、背包、房间布置和已领取任务是否保留。
- 音乐与音效：切换背景音乐、音效开关及音量；尝试点击、照料、打工等操作，并在后台与前台间切换，检查播放与设置保存。
请通过 TestFlight 反馈复现步骤、设备型号、系统版本和相关截图。
游戏进度仅保存在本机，没有云存档；删除 App 会失去本地进度，建议覆盖更新，不要先卸载。

简体中文 · 审核备注／无登录说明
无需注册或登录，不需要演示账号。打开游戏后等待加载完成，点击“进入小家”即可开始。设置中可以更换语言。核心玩法离线可用，存档保存在设备本地。

English · Beta App Description
A cozy, single-player cat care and life game. Earn coins and experience through jobs, care for and adopt cats, dress your character, and decorate your home. This beta focuses on level-based goals, daily care, job rewards, and save compatibility after updating. Simplified Chinese, Traditional Chinese, and English are available.

English · What to Test
- Goals: Claim a reward and check that you return to the list, the claimed goal disappears, and coins and experience are awarded only once. Check new goals at work levels 2, 4, 6, and 10, three goals per page, page navigation, and empty-list messages.
- Cat care: Try feeding, cleaning, playing, and switching your companion cat. Check that animations, stat changes, and item consumption match the action.
- Job recovery: Start a job, put the app in the background, and return. Check the remaining time, completion, and rewards. Reopening a page must not award the same job twice.
- Room: Place, move, and put furniture back into your bag. After upgrading the room, try two-finger zoom and check furniture selection and cat movement.
- Saves: Update an existing installation directly. Close and reopen the app, then check character and cat names, coins, inventory, furniture placement, and claimed goals.
- Music and sounds: Change music and sound toggles and volume. Try navigation, care, and job actions, then switch between background and foreground. Check playback and whether settings are saved.
Please send reproduction steps, your device model, OS version, and relevant screenshots through TestFlight feedback.
Progress is stored only on your device, with no cloud save. Deleting the app removes local progress; update in place instead of uninstalling first.

English · Beta App Review Notes / Sign-in
No registration, sign-in, or demo account is required. Open the app, wait for loading to finish, and tap the enter-home button to begin. Language can be changed in Settings. Core gameplay works offline and saves remain on the device.

发布与继续开发约定
- 同时准备内外部测试：上传时不要选择 TestFlight Internal Only；该模式的构建不能转给外部测试者。
- 外测首个构建需经 Apple TestFlight App Review（Beta Review）；上传成功、处理完成、审核通过和测试开放须分别记录，不能混写为已发布。
- 审核联系人、反馈邮箱和隐私政策 URL 尚未提供；保持待补，不编造联系人、邮箱或链接，不将占位内容提交给 Apple。
- 本轮测试固定使用 0.9.2（37）的提交及归档，后续开发另开 codex/ 分支；新交付按仓库规则同步递增对外版本号和构建号。
- 后续存档变更必须兼容已有进度；归档、上传及真机验证分别留下脱敏记录，不在本目录放签名私钥、设备标识或玩家真实存档。
- 当前待完成：核对或创建正确的应用记录、分发签名与上传、补齐外测资料、Apple Beta Review，以及内外部测试反馈。

Apple 官方流程依据（核对于 2026-11-04）：
https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers
https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
