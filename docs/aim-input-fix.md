# 0.4.1 鼠标瞄准修复

用户在 Windows 实机反馈炮塔无法旋转，要求同时考虑 macOS。当前环境没有 Windows，无法确认原始触发条件。

检查发现炮塔 aim_point 到旋转的计算正常；鼠标输入原先只走 _unhandled_input，因此前景 Control 消费事件时会停止瞄准。另使用 relative 导致位移受视口拉伸影响。新增 tests/aim_input.gd 通过真实 Viewport/Input 事件通路验证，模拟前景控件覆盖和视口缩放：旧代码 3 项失败，修改后 8 项全部通过。不是直接调用炮塔旋转函数来代替输入测试。

修复：playing 时在 _input 处理鼠标移动，使用 screen_relative，处理后标记已消费。按键和滚轮沿用原处理；暂停与焦点丢失的门禁不变。自动场景/截图测试同时关闭新旧两个输入回调，防止实际鼠标干扰测试相机。

验证：完整回归、Mac Forward+ 窗口输入测试、两端导出 PCK 输入与玩法回归。Windows EXE 的实际运行问题仍需用户使用 0.4.1 复测；不把跨平台资源检查说成 Windows 实机验证。

图形窗口回归最初受桌面鼠标事件和失焦自动暂停干扰。最终测试等待窗口激活，仅在注入事件时启用输入回调；保留独立的焦点丢失测试。最终导出 PCK / Metal Forward+ 验证：playing=true，camera yaw=-0.5，turret yaw=-0.50425，8 项通过。
