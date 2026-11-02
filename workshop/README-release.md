# I can touch forever! v0.1.9

Repentance+ mod. No REPENTOGON required.

v0.1.9：原 Mouse Pickup／鼠标拾取更名为 I can touch forever!。游戏及 MCM 显示名称更新；原工坊条目、安装目录、存档标识和玩法保持兼容。

v0.1.9 renames Mouse Pickup to I can touch forever! in the game and MCM. The existing Workshop item, installation directory, save identity and gameplay are preserved.

Source / 源码：[GitHub](https://github.com/hdydhsdexe/i-can-touch-forever). MIT License; see `LICENSE`.

v0.1.8 新增可选 MCM 设置页：总开关、右键／中键／鼠标键 4／5 改键、冲突自动交换、光标／选框／状态显示和 EID 联动开关。默认右键拾取、中键切换。配置按存档槽保存，关闭菜单、重新启用或改键后须松开再按。中文版可切中英，Pure 固定英文，两版分别使用。MCM 为可选依赖。

Windows 10 来宾核心流程、重启保存及两个存档槽隔离已检查；187 项模拟／接口检查、43 条成功原生断言与 23 项独立读回分开统计。2026-10-21 用户人工验收通过：物理鼠标及驱动映射、第三存档槽、MCM 延迟加载／实例替换、精确回调边界的排队与进行中普通拾取／装袋取消、其他固定 EID 说明的优先权、魂石菱形开关、镜像／滚动房间、商店和完整危险专项。依据用户在本会话确认“全部待验收项目均已人工通过”；未提供逐项步骤、截图或日志，不计入自动检查数量。

v0.1.8 adds optional MCM settings: master switch, RMB/MMB/M4/M5 bindings with automatic conflict swapping, separate cursor/bracket/status visibility and EID hover control. Settings persist per save slot. Release and press again after closing the menu, enabling or rebinding. Chinese MCM supports Chinese/English; Pure uses English. Use the two editions separately; MCM is optional.

Guest core flows, restart persistence and two save slots were checked. Counts remain separate: 187 simulated/API checks, 43 successful native assertions and 23 independent readbacks. On 2026-10-21 the user confirmed manual acceptance of physical mouse/drivers, slot 3, late/replaced MCM, queued/in-flight pickup and bag cancellation boundaries, permanent EID priority, soul diamond toggles, mirror/scrolling rooms, shops and the complete hazard checks listed for this round. No case logs were supplied for this manual confirmation, and no automated counts were added.

Workshop / 创意工坊：https://steamcommunity.com/sharedfiles/filedetails/?id=3819617165

## 安装与使用

将 `mouse_pickup` 文件夹放入游戏 `mods` 目录，在 MODS 菜单启用 **I can touch forever!** 并重新开始一局。入口应为 `mods/mouse_pickup/main.lua`。订阅版和手动版只启用一份。

清房后右键高亮掉落物，角色保持原位。一次按下处理一个目标，长按不连收。绿色可尝试领取，黄色表示费用／风险，红色表示不可用。须有符合领取者能力的安全通路；费用、容量、替换、二选一及箱子遵循原生规则。举起合成宝袋后右键材料执行一次原生挥袋，下一次需重新举袋，不自动合成。支持里蓝人大小翔块和可选 EID 悬停说明。

v0.1.7 增加单人多实体支持：

| 角色／效果 | 领取规则与光标 |
|---|---|
| 普通双子 | 中键切雅各白色／以扫红色 |
| 普通遗骸 | 跟随原生身体灰色／灵魂蓝色，不用中键切形态 |
| 里遗骸 | 仅身体落地静止时固定身体领取，灰色；抱起、投掷、召回禁用 |
| 里拉撒路（含长子名分） | 跟随当前前台，白色；后台不进入选择 |
| 里雅各两种状态 | 当前角色白色，暗以扫不作为领取者 |
| 普通单角色＋一个稻草人／一次双子魂石／一次遗骸魂石 | 中键主角色白色 ↔ 同伴金／红／灰色 |
| 普通单角色＋小以扫 | 原生前台白／红色，中键不切身体 |

普通双子、普通遗骸、无长子名分里拉撒路还可分别叠加一个稻草人或一次两种魂石效果；不混用。双子顺序为雅各 → 原生以扫 → 同伴；遗骸／里拉撒路为本体当前形态／前台 → 同伴。普通遗骸＋遗骸魂石包含长子名分。遗骸魂石只提供原生实际存在的临时身体，不生成灵魂。

双子＋双子魂石的临时以扫、遗骸＋遗骸魂石的临时身体使用同色空心菱形包围 `+`，区分同色本体。其他组合保持普通 `+`，无角色文字。颜色透明度为 0.8，物品状态提示保留原色。

成员稳定时切房保留选择；成员生成、死亡、消失、替换、形态或关系改变时取消旧请求并重置选择。新局／续局重建选择；魂石同伴按原生规则消失。恢复后必须松开再右键，不自动补领。所有领取判断和宝袋归属跟随领取者；其他同组成员举袋／挥袋时暂时阻止目标移动。已发生的原生收益不回滚，普通走动拾取保持可用。

不支持多人、第三方多实体组合、多个稻草人、重复魂石、混用效果、小以扫叠加特殊角色、里拉撒路长子名分叠加效果、里遗骸／里雅各叠加效果及未列出的组合。战斗、暂停、切房和打开 Mod Config Menu 时停用；不支持结局物品、床和传送设施。

v0.1.7 历史验收：九组模拟 160 项、原生检查 1732 项通过，另完成真实鼠标及正常续局。多实体验收引擎为 Windows 10 来宾 v1.9.7.15.J374。里雅各为“2026-10-19 用户人工验收通过”，不计入自动数量。镜像／高射程此前在 v1.9.7.17.J460 验收。本轮新增的人工验收范围见上方；第三方自定义交互不保证兼容。

## Installation and use

Place `mouse_pickup` in the game's `mods` directory, enable **I can touch forever!** in MODS, and start a new run. The entry point is `mods/mouse_pickup/main.lua`. Enable only one copy if also subscribed on Workshop.

After clearing a room, right-click a highlighted pickup without moving your character. One target per press; holding never repeats. Green means an attempt is available, yellow indicates a cost/risk, red means unavailable. A safe path using the recipient's abilities is required. Native costs, capacity, swaps, options and chest rules apply. Raise Bag of Crafting to bag one material with a native swing; raise it again for the next swing. No automatic crafting. Tainted Blue Baby's poop nuggets and optional EID hover descriptions are supported.

v0.1.7 supports Jacob and Esau (middle-click white Jacob/red Esau); The Forgotten (native gray body/blue soul); grounded, stationary Tainted Forgotten (body only); Tainted Lazarus including Birthright (foreground only); and both Tainted Jacob states (current player, excluding Dark Esau).

An ordinary single character may separately use one Strawman, one Soul of Jacob effect or one Soul of the Forgotten effect: middle-click cycles the white main character and gold/red/gray companion. Esau Jr. follows the native foreground, white/red, without middle-click body switching. Only the temporary Forgotten body actually supplied by the engine is offered; no soul is generated.

Jacob and Esau, The Forgotten, and Tainted Lazarus without Birthright may each combine with one Strawman or one of the two soul effects, used separately. Twins cycle Jacob → original Esau → companion; Forgotten/Lazarus cycle current native form/foreground → companion. Forgotten with Birthright + Soul of the Forgotten is included. A same-color hollow diamond surrounds `+` only for temporary Esau in twins + Soul of Jacob and the temporary body in Forgotten + Soul of the Forgotten. Other cursors keep the plain `+`. Opacity remains 0.8; status colors remain unchanged.

Stable members preserve selection between rooms. Member, form or relationship changes cancel requests and reset selection. New runs and Continue rebuild it; soul companions follow native removal. Release and press right-click again after availability returns. All recipient checks and bag ownership use the selected entity. Another group member raising/swinging a bag temporarily blocks target movement. Already granted native rewards are not rolled back; ordinary walking pickup remains available.

Co-op, third-party groups, multiple Strawmen, repeated/mixed effects, Esau Jr. stacked with special characters, effects stacked with Tainted Lazarus's Birthright, Tainted Forgotten or Tainted Jacob, and unlisted combinations are unsupported. Combat, pause, room transitions and open Mod Config Menu disable interaction. Ending objects, beds and transport objects are unsupported.

Historical v0.1.7 verification: 160 checks across nine simulation suites, 1732 native checks, plus real mouse and normal Continue checks. Multi-entity tests used Windows 10 guest v1.9.7.15.J374. Tainted Jacob was accepted manually by the user on 2026-10-19, outside automated counts. Mirror/high-range features were previously tested on v1.9.7.17.J460. See the current manual acceptance scope above; third-party custom interactions are not guaranteed.

Keep `mpickup/development.lua` set to `return false`. No debug console or MouseControl setting change is needed.
