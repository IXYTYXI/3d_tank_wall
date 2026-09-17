# 可驾驶画质样板实施计划

用户已确认以一辆坦克和局部战场为样板，对照参考图改进实际渲染。沿用已批准方向，在当前分支执行，不再次请求批准。

目标：改善实际游戏的天空、地表和近景层次，并提供实机截图与性能记录。保持既有四种模式、碰撞与 Windows/macOS 兼容渲染路径。

架构：天空与地表使用独立 shader；草石由独立 scenery_detail.gd 确定性生成、MultiMesh 批量渲染并限制显示距离；坦克材质调整不改变动画和战斗逻辑。程序资产仍属于原型，不声称达到宣传图品质。

- [x] 保存修改前相同镜头截图，记录基线。
- [x] shaders/battle_sky.gdshader：分层阴云、亮部和冷色天际；scripts/main.gd 接入并调整主光、补光与雾。
- [x] shaders/ground.gdshader：土路、双履带车辙、碎石、潮湿粗糙度及地面法线细节。
- [x] scripts/scenery_detail.gd：仅装饰性的批量草丛和小石，避开中央行车路线；scripts/battlefield.gd 接入。
- [x] shaders/painted_armor.gdshader：多尺度漆面变化、露底、粗糙度差异。
- [x] tests/render_slice_visual.gd：相同镜头前后截图、常规驾驶视角、暖机后的固定路径渲染耗时统计。
- [x] 执行 scripts/check.sh，实际渲染检查 shader 报错与图像；必要时调整。
- [x] 保存可展示截图，更新 README，提交推送。先交付画质样板，安装包不覆盖已有稳定版本。

验收补充：实际比较后新增可选 Forward+ 启动脚本，默认兼容模式不变。M4 上两种路径均已渲染截图；Forward+ 使用 SSAO、低密度体积雾、ACES 和辉光。完整 133 项玩法/模型检查通过，材质最终调整另做实际渲染和模型检查。安装包保持原有版本。

最终实机采样：Apple M4 / Metal Forward+，1280×800，240 帧静态训练场；平均 117.1 FPS，P95 帧时 11.4 ms，772 draws。最终画面检查修正了远景树林根部与山体的高度衔接。截图输出与测试日志保存在被忽略的 outputs/、work/render-slice/。
