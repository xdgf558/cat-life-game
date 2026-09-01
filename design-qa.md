# 游戏厅 Arcade Floor 重构 · Design QA

Final result: passed

## Visual truth and comparison inputs

- Source visual truth: [design-reference-arcade-floor.png](docs/arcade-floor/design-reference-arcade-floor.png) — 用户选择的第二个 “Arcade Floor” 方向。
- Final implementation capture: [design-qa-arcade-floor-final-clean.png](docs/arcade-floor/design-qa-arcade-floor-final-clean.png)。
- Same-input comparison: [design-qa-arcade-floor-comparison.png](docs/arcade-floor/design-qa-arcade-floor-comparison.png)，左侧为视觉参考，右侧为最终实现。
- Responsive focused capture: [design-qa-arcade-floor-mobile.png](docs/arcade-floor/design-qa-arcade-floor-mobile.png)。视觉证据集中在 `docs/arcade-floor/`，不属于运行时资源。

## Viewport, density, and state

- CSS viewport: `1658 × 949`; browser runtime reported `window.innerWidth = 1658`, `window.innerHeight = 949`, `devicePixelRatio = 1`。
- Final browser raster: `1451 × 940` JPEG，由本地浏览器容器的截图表面返回；对比图将参考图等比 contain 到同一 `1451 × 940` 面板，未拉伸内容，并保留上下留白。
- Reference state: 游戏厅、老虎机选中、下注 20 金币、本地彩票奖池 1,000,000 金币、无票据、无游戏记录。
- Final implementation state: 游戏厅、老虎机选中、下注 20 金币、本地彩票奖池 1,000,000 金币、无票据、空记录引导；主按钮完整位于首屏内。

## Full-view comparison evidence

通过同一张对比输入检查了整体层级：页面标题与金币状态 → “老虎机 / 本地彩票”玩法切换 → 主老虎机舞台 → 彩票奖池快照 → 我的记录。实现沿用原项目的报纸式站点外壳和导航，同时把游戏厅内部重构为橙色主动作、鼠尾草绿色信息轨、奶油色卡片的 Arcade Floor。真实老虎机柜图片位于 `src/assets/arcade/slot-machine-cabinet.webp`，其上只叠加真实游戏转轮和状态信息。

机柜资源已按最大展示尺寸压缩为 `1000 × 637` WebP，最终文件约 `66 KB`；`img` 同步声明了 `width` / `height`，避免图片加载期间发生布局跳动。

## Focused-region comparison evidence

重点检查了老虎机舞台、下注选择器、主 CTA 和彩票快照。第一次实现中老虎机舞台过高，主 CTA 只露出一部分；压缩舞台高度后重新截图，Playwright 测得 CTA `bottom = 910`、视口底部 `949`，完整可见。窄屏 `390 × 844` 检查确认内容改为单列、移动导航固定在底部，老虎机仍保持可见且不被导航遮挡。

## Interaction and accessibility checks

- 点击 `50 金币` 后，下注按钮变为 `aria-pressed="true"`，主 CTA 更新为“开始转动 · 投入 50 金币”。
- 点击主 CTA 后，转轮进入动画状态，结算后金额和“我的记录”按原游戏系统更新。
- 点击“我的记录”卡片中的“查看全部”后，会打开并聚焦下方“查看规则与完整记录”，不会错误跳到彩票页。
- 切换到本地彩票后，当前开奖、倒计时、奖池、六位选号和购票动作可用；将第一位选择为 `7` 后号码预览更新为 `700000`。
- 已开奖未中奖票使用 `lottery_lost` 翻译键，中文显示“未中奖”，英文显示“No prize”。
- “查看规则与完整记录”可展开，保留老虎机赔率、彩票奖级、待结算、历史开奖、票据与按期查询。
- 使用语义化 `tablist / tab / tabpanel`、`aria-selected`、`aria-pressed`、选号 `label` 与 `aria-label`；浏览器错误日志为 0。

## Iteration history

| Priority | Finding | Change | Verification |
| --- | --- | --- | --- |
| P0 | 未发现阻断核心玩法的问题。 | 无需迭代。 | 桌面与窄屏核心路径可用，错误日志为 0。 |
| P1 | 初版舞台高度让首屏主 CTA 只部分露出。 | 将桌面老虎机舞台收敛到最高 280px，并保持移动端 280px 的可读裁切。 | 最终测量 CTA 完整落在 `0–949` 视口内。 |
| P2 | 初始截图中的存档载入 toast 会遮挡视觉对比区域。 | 等待 toast 生命周期结束后再截取最终 clean state。 | 最终对比图无 toast 遮挡；同时保留真实运行状态 QA。 |

## Automated checks

- `npm test` → `UI regression checks passed.`
- `node --check` across every file under `src/js` → passed。
- Local browser interaction QA at `1658 × 949` and `390 × 844` → passed。
