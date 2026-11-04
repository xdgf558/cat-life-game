# 卡通职业与猫町图标 · 0.11.1（41）

使用内置 image_gen 逐张生成 12 张透明 PNG：5 个职业人物与 7 个猫町地点。最终图片位于 `../../CatLife/Assets.xcassets/<asset>.imageset/<asset>.png`，完整名称、提示词及生成模式见 [prompts.json](prompts.json)。此目录只保留来源说明与校验记录，避免重复保存大图。

职业包括发传单、便利店、宠物店、IT 和猫咖；地点包括邻居街、宠物医院、猫咖、中央广场、留言板、交换集市与空地。沿用暖色圆润 3D 卡通、奶油/薄荷/蜂蜜配色与透明背景。猫咖人物首稿误生成猫脸，已通过定点编辑修正为人类，最终提示词保留在 refinementPrompt。现有 icon-work、icon-town、icon-home、icon-shop 分别复用于打工街、领养、小家和商店及相关入口。

生成结果直接复制到资源目录，未裁剪、重绘或抠图。12 张均为 1254×1254 RGBA，真实 alpha 为 0…255；像素尺寸、SHA-256 与路径见 [asset-verification.json](asset-verification.json)。小尺寸展示由 SwiftUI 等比例缩放，卡片外框、房间与猫咪尺寸保持原值。锁定职业保留插画和锁角标，未来地点仍为未开放预览。

所有 PNG 由 Git LFS 管理，资源预检清单与 Xcode sandbox 输入列表同步更新。未生成新玩家形象、猫咪动画、房间或玩法内容。
