extends Control

var game: Node3D
var menu: Control
var title: Label
var button: Button
var secondary: Button
var subtitle: Label
var controls: Label
var modes: HBoxContainer
var upgrades: VBoxContainer
var font: Font = preload("res://assets/fonts/ui_chinese.tres")
var ivory := Color("e4e6d5")
var amber := Color("e9b56b")
var muted := Color("a2b3aa")

func _ready() -> void:
	theme = Theme.new()
	theme.default_font = font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = Control.new()
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.055, 0.79)
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	menu.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 100
	column.offset_right = 600
	column.offset_top = -280
	column.offset_bottom = 280
	column.custom_minimum_size = Vector2(570, 500)
	column.add_theme_constant_override("separation", 14)
	var kicker := Label.new()
	kicker.text = "单机作战 / 基地防守 · 无尽生存 · 限时歼灭"
	kicker.add_theme_color_override("font_color", amber)
	kicker.add_theme_font_size_override("font_size", 14)
	column.add_child(kicker)
	title = Label.new()
	title.text = "钢铁战场"
	var title_font: FontVariation = font.duplicate()
	# Godot reports the OpenType weight axis (wght) as this numeric tag.
	title_font.variation_opentype = {2003265652: 700.0}
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ivory)
	column.add_child(title)
	subtitle = Label.new()
	subtitle.text = "守住指挥基地，击退五波敌军。\n利用掩体、侧翼射击与战地补给赢得战斗。"
	subtitle.add_theme_color_override("font_color", muted)
	subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(subtitle)
	button = Button.new()
	button.text = "进入训练场    →"
	button.custom_minimum_size = Vector2(430, 58)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("bd955c")
	style.content_margin_left = 25
	style.content_margin_right = 25
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("172326"))
	button.pressed.connect(_primary_pressed)
	column.add_child(button)
	modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation",12)
	column.add_child(modes)
	for item in [["survival","无尽生存 / 挑战更多波次"],["elimination","限时歼灭 / 180 秒击毁 12 辆"]]:
		var mode_button := Button.new()
		mode_button.text = item[1]
		mode_button.custom_minimum_size = Vector2(278,48)
		mode_button.add_theme_font_size_override("font_size",15)
		mode_button.pressed.connect(game.start_mode.bind(item[0]))
		modes.add_child(mode_button)
	secondary = Button.new()
	secondary.text = "自由训练"
	secondary.custom_minimum_size = Vector2(430,40)
	secondary.add_theme_font_size_override("font_size",16)
	secondary.pressed.connect(func():
		if game.started:
			game.get_tree().reload_current_scene()
		else:
			game.set_playing(true))
	column.add_child(secondary)
	upgrades = VBoxContainer.new()
	upgrades.add_theme_constant_override("separation",10)
	column.add_child(upgrades)
	for item in [["armor","强化装甲：最大生命 +30，维修 +45"],["reload","高效装填：装填时间缩短 14%"],["mobility","机动强化：最高速度 +15%，维修 +15"]]:
		var upgrade := Button.new()
		upgrade.text = item[1]
		upgrade.custom_minimum_size = Vector2(530,50)
		upgrade.add_theme_font_size_override("font_size",17)
		upgrade.pressed.connect(game.battle.apply_upgrade.bind(item[0]))
		upgrades.add_child(upgrade)
	upgrades.hide()
	controls = Label.new()
	controls.text = "W A S D 驾驶    鼠标 瞄准\n左键 / 空格 开火    右键 开镜    Shift 制动\n滚轮 调整镜头    E 应急维修（战斗中）\nEsc 暂停    R 返回主菜单"
	controls.add_theme_color_override("font_color", muted)
	controls.add_theme_font_size_override("font_size", 15)
	column.add_child(controls)

func _primary_pressed() -> void:
	if game.battle.finished():
		game.get_tree().reload_current_scene()
	elif game.started:
		game.set_playing(true)
	else:
		game.start_defense()

func update_menu() -> void:
	if not is_instance_valid(menu):
		return
	menu.visible = not game.playing
	var battle: Node3D = game.battle
	var choosing: bool = battle.phase == "upgrade"
	upgrades.visible = choosing
	button.visible = not choosing
	secondary.visible = not choosing and not battle.finished()
	controls.visible = not choosing
	modes.visible = not game.started
	secondary.text = "返回主菜单" if game.started else "自由训练"
	if choosing:
		title.text = "战地整备"
		subtitle.text = "第 %d 波已清除，选择一项强化。\n坦克生命 %d / %d" % [battle.wave,game.tank.health,game.tank.max_health]
		if battle.mode=="defense":
			subtitle.text += "    基地耐久 %d / %d" % [battle.base_health,battle.base_max_health]
	elif battle.finished():
		title.text = ("防守胜利" if battle.mode=="defense" else "歼灭成功") if battle.phase == "won" else "生存结束" if battle.mode=="survival" else "任务失败"
		subtitle.text = "%s\n得分 %d · 击毁 %d 辆 · 坚守 %d 分 %02d 秒\n射击 %d 次 · 命中 %d 次" % [battle.result_reason,battle.score,battle.kills,int(battle.elapsed)/60,int(battle.elapsed)%60,game.shots,game.hits]
		if battle.mode=="survival":
			subtitle.text += "\n抵达第 %d 波" % battle.wave
		button.text = "返回主菜单    →"
	elif game.started:
		title.text = "战斗暂停" if battle.active() else "训练暂停"
		subtitle.text = "战斗已暂停，敌军和炮弹均已停止。\n点击下方按钮继续。"
		button.text = "继续战斗    →" if battle.active() else "继续训练    →"
	else:
		title.text = "钢铁战场"
		subtitle.text = "守住指挥基地，击退五波敌军。\n利用掩体、侧翼射击与战地补给赢得战斗。"
		button.text = "开始基地防守    →"
	queue_redraw()

func label_at(pos: Vector2, text: String, size_px: int = 16, color: Color = Color("e4e6d5")) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	if not game.playing:
		return
	var w := size.x
	var h := size.y
	var c := size * 0.5
	draw_rect(Rect2(28, 26, 295, 74), Color(0.03, 0.07, 0.08, 0.78))
	draw_rect(Rect2(28, 26, 3, 74), amber)
	label_at(Vector2(46, 53), "钢铁战场", 21)
	label_at(Vector2(46, 80), game.battle.mode_name()+" / 单机战斗" if game.battle.active() else "原型版本 / 训练场", 13, muted)
	draw_rect(Rect2(w - 275, 26, 247, 74), Color(0.03, 0.07, 0.08, 0.78))
	label_at(Vector2(w - 255, 49), game.battle.progress_text() if game.battle.active() else "已摧毁   %02d / 06" % game.destroyed, 19)
	label_at(Vector2(w - 255, 75), "得分 %d    击毁 %d 辆" % [game.battle.score,game.battle.kills] if game.battle.active() else "射击 %02d 次    命中 %02d 次" % [game.shots,game.hits], 13, muted)
	if game.battle.active():
		draw_battle_status()
	# Heading tape.
	var heading := fposmod(-rad_to_deg(game.yaw), 360)
	for i in range(-4, 5):
		var x := c.x + i * 44
		draw_line(Vector2(x, 30), Vector2(x, 36 if i % 2 else 42), muted)
	label_at(Vector2(c.x - 27, 63), "%03d°" % int(heading), 16)
	draw_line(Vector2(c.x, 17), Vector2(c.x, 27), amber, 2)
	if game.scoped:
		var radius := h * 0.43
		draw_circle(c, radius, Color(0.025, 0.04, 0.04, 0.85), false, 5, true)
		draw_line(Vector2(0, c.y), c - Vector2(70, 0), Color(0.05, 0.07, 0.05, 0.8), 1)
		draw_line(c + Vector2(70, 0), Vector2(w, c.y), Color(0.05, 0.07, 0.05, 0.8), 1)
		for i in range(1, 8):
			draw_line(c + Vector2(-5, i * 18), c + Vector2(5, i * 18), ivory, 1)
	# White: mouse target. Amber: actual muzzle trajectory.
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + direction * 10, c + direction * 22, ivory, 1.5, true)
	draw_circle(c, 2, ivory)
	var point: Vector3 = game.muzzle_hit
	if not game.camera.is_position_behind(point):
		var p: Vector2 = game.camera.unproject_position(point)
		p = p.clamp(Vector2(20, 110), Vector2(w - 20, h - 110))
		draw_arc(p, 9, 0, TAU, 30, Color("e67553") if game.blocked else amber, 2, true)
	if game.hit_flash > 0:
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(c + direction * 25, c + direction * 35, amber, 3, true)
	var distance: float = game.tank.global_position.distance_to(game.aim_point)
	label_at(c + Vector2(33, 5), "%03d 米" % int(distance), 13)
	if game.blocked:
		label_at(c + Vector2(-78, 64), "炮口被掩体遮挡", 13, Color("f39973"))
	draw_rect(Rect2(28, h - 124, 270, 96), Color(0.03, 0.07, 0.08, 0.80))
	label_at(Vector2(46, h - 91), "M-01 / 中型坦克", 13, muted)
	label_at(Vector2(46, h - 48), "%02d" % int(absf(game.tank.speed) * 3.6), 36)
	label_at(Vector2(107, h - 49), "公里/时", 13, muted)
	label_at(Vector2(208, h - 49), "倒车" if game.tank.speed < -0.1 else "前进", 16, amber)
	draw_rect(Rect2(c.x - 150, h - 129, 300, 91), Color(0.03, 0.07, 0.08, 0.7))
	var progress: float = 1 - game.cooldown / game.reload_time
	draw_rect(Rect2(c.x - 130, h - 91, 260, 3), Color(0.1, 0.15, 0.15, 0.9))
	draw_rect(Rect2(c.x - 130, h - 91, progress * 260, 3), amber)
	label_at(Vector2(c.x - 130, h - 106), "105 毫米 / " + ("装填就绪" if game.cooldown <= 0 else "装填中 %.1f 秒" % game.cooldown), 15)
	label_at(Vector2(c.x - 130, h - 62), game.message, 12, ivory)
	label_at(Vector2(w - 302, h - 78), "右键 开镜   左键 / 空格 开火", 13)
	label_at(Vector2(w - 302, h - 51), "Shift 制动     Esc 暂停", 13, muted)
	label_at(Vector2(30, h - 10), "白色十字：瞄准目标    黄色圆圈：预测落点    /    开发版本", 12, muted)

func health_bar(rect: Rect2, value: int, maximum: int, color: Color) -> void:
	draw_rect(rect,Color(0.1,0.13,0.13,0.9))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(float(value)/maximum,0,1),rect.size.y)),color)

func draw_battle_status() -> void:
	var battle: Node3D = game.battle
	var w := size.x
	var h := size.y
	draw_rect(Rect2(28,h-210,270,72),Color(0.03,0.07,0.08,0.85))
	label_at(Vector2(46,h-180),"坦克生命 %d / %d" % [game.tank.health,game.tank.max_health],16)
	health_bar(Rect2(46,h-164,232,7),game.tank.health,game.tank.max_health,Color("72c9a1"))
	if battle.mode=="defense":
		draw_rect(Rect2(w-275,112,247,75),Color(0.03,0.07,0.08,0.85))
		label_at(Vector2(w-255,141),"基地耐久 %d / %d" % [battle.base_health,battle.base_max_health],15)
		health_bar(Rect2(w-255,158,208,7),battle.base_health,battle.base_max_health,Color("69b8c7"))
	elif battle.mode=="elimination":
		draw_rect(Rect2(w-275,112,247,75),Color(0.03,0.07,0.08,0.85))
		label_at(Vector2(w-255,141),"剩余时间 %02d:%02d" % [ceili(battle.time_left)/60,ceili(battle.time_left)%60],18,amber)
		label_at(Vector2(w-255,169),"180 秒内击毁 12 辆敌军",13,muted)
	if battle.phase == "countdown":
		draw_rect(Rect2(28,112,295,40),Color(0.03,0.07,0.08,0.85))
		label_at(Vector2(46,138),("任务将在 %d 秒后开始" % ceili(battle.countdown)) if battle.mode=="elimination" else ("第 %d 波将在 %d 秒后抵达" % [battle.wave+1,ceili(battle.countdown)]),16,amber)
	label_at(Vector2(w-302,h-125),"E 应急维修：剩余 %d 次" % battle.repair_charges,14,Color("88d7b2"))
	if battle.fast_reload_time>0:
		label_at(Vector2(size.x*0.5-130,h-146),"急速装填：剩余 %d 秒" % ceili(battle.fast_reload_time),14,amber)
	# North-up tactical radar; all enemies are intentionally visible here.
	var radar := Rect2(w-205,h-355,177,177)
	draw_rect(radar,Color(0.03,0.07,0.08,0.86))
	draw_rect(radar,Color(0.4,0.55,0.5,0.6),false,1)
	label_at(radar.position+Vector2(9,19),"战术雷达 · 北 ↑",12,muted)
	var center := radar.position+Vector2(88,100)
	var scale_factor := 0.63
	if is_instance_valid(battle.base):
		var base_point := center+Vector2(battle.base.position.x,battle.base.position.z)*scale_factor
		draw_rect(Rect2(base_point-Vector2(4,4),Vector2(8,8)),Color("65cdb8"))
	for enemy in battle.enemies:
		draw_circle(center+Vector2(enemy.position.x,enemy.position.z)*scale_factor,3,Color("f1936b"))
		var point: Vector3 = enemy.position+Vector3(0,3.1,0)
		if game.camera.is_position_behind(point) or enemy.position.distance_to(game.tank.position)>110:
			continue
		var line: Dictionary = game.ray(game.camera.global_position,enemy.position+Vector3(0,1.3,0))
		if line.is_empty() or line.collider != enemy:
			continue
		var screen: Vector2 = game.camera.unproject_position(point)
		if screen.x<60 or screen.x>w-60 or screen.y<100 or screen.y>h-140:
			continue
		label_at(screen+Vector2(-42,-8),enemy.variant,13,Color("ffb491"))
		health_bar(Rect2(screen-Vector2(45,0),Vector2(90,5)),enemy.health,enemy.max_health,Color("e58e67"))
	for supply in battle.supplies:
		draw_circle(center+Vector2(supply.node.position.x,supply.node.position.z)*scale_factor,2,Color("88deb2"))
	var player_point := center+Vector2(game.tank.position.x,game.tank.position.z)*scale_factor
	draw_circle(player_point,4,ivory)
	draw_line(player_point,player_point+Vector2(-sin(game.tank.rotation.y),-cos(game.tank.rotation.y))*11,ivory,2)
	if battle.damage_flash>0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.8,0.18,0.12,battle.damage_flash*0.7),false,10)
