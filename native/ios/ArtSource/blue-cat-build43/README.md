# 蓝影素材 · 0.12.0（43）

使用内置 image_gen，以现有橘猫素材为姿态编辑目标、首张蓝影坐姿为形象参考，生成十张透明 PNG。蓝影采用蓝灰短绒毛、蓝色眼睛、粉色鼻耳与橙色领结，保持现有卡通画风和房间中的猫咪尺寸。原橘猫、奶牛猫素材未覆盖。

运行素材位于 `../../CatLife/Assets.xcassets/cat-blue-*.imageset/`，通过 Git LFS 保存；本目录不重复存放大图。包含头像、坐姿、进食静态图，以及 expressions、walk、rise、meal、play、rest、step 七套八帧动作。rest 为两列四行，其余动画为四列两行。

`prompts.json` 保存生成提示词及仓库内参考素材路径。首张 meal 图有跨帧耳部，已弃用；`meal-frame-repair.txt` 记录重新生成要求。最终 PNG 原样接入，未用脚本改写、抠图或拼图。`asset-verification.json` 是只读像素分析，包含十张最终图片的尺寸、SHA256、透明区域、实体数量及爪部接触锚点。

SpriteKit 注册独立蓝影前后爪、脚底基线和进食口部锚点，仍使用现有统一的显示尺寸。最终运行和交互验证见 `../../QA/catalog-furniture-build43-summary.md`；像素分析本身不代替屏幕上的进食和上下家具验证。
