# 奶牛猫素材 · 0.7.0（31）

使用内置 image_gen，以现有橘猫素材为姿态编辑目标、首张奶牛猫为形象参考，生成 10 张透明 PNG。原橘猫图片未覆盖。最终图片位于 `../../CatLife/Assets.xcassets/cat-cow-*.imageset/`，此目录只保留提示词和校准记录，避免重复保存大图。

包括头像、坐姿、舔嘴静态图，以及 expressions、walk、rise、meal、play、rest、step 七套各八帧动作。除 rest 为两列四行外，其余动作均为四列两行。形象保持白底黑斑、金色眼睛、粉鼻和橙色领结。

`prompts.json` 记录生成提示词。`asset-verification.json` 记录尺寸、校验值、透明背景与接触点。SpriteKit 使用独立奶牛猫前后爪锚点；进食图左侧扫描避开前一格胡须。透明预览中外部色点最高仅 3/255 alpha，没有额外实体，实际房间合成仍需交互回归确认。

未生成新的场景、家具、音频或第三只猫。
