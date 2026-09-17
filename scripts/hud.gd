extends Control

var game: Node3D
var menu: Control
var title: Label
var button: Button
var font := ThemeDB.fallback_font
var ivory := Color("e4e6d5")
var amber := Color("e9b56b")
var muted := Color("a2b3aa")

func _ready() -> void:
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
	column.offset_top = -190
	column.offset_bottom = 190
	column.custom_minimum_size = Vector2(500, 380)
	column.add_theme_constant_override("separation", 18)
	var kicker := Label.new()
	kicker.text = "FIELD TEST  /  001                          SINGLE PLAYER"
	kicker.add_theme_color_override("font_color", amber)
	kicker.add_theme_font_size_override("font_size", 14)
	column.add_child(kicker)
	title = Label.new()
	title.text = "IRON FIELD"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ivory)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A THIRD-PERSON ARMOR PROTOTYPE\n\nDrive the ridge. Find your angle. Clear the range."
	subtitle.add_theme_color_override("font_color", muted)
	subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(subtitle)
	button = Button.new()
	button.text = "ENTER TRAINING RANGE    →"
	button.custom_minimum_size = Vector2(430, 58)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("bd955c")
	style.content_margin_left = 25
	style.content_margin_right = 25
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("172326"))
	button.pressed.connect(func(): game.set_playing(true))
	column.add_child(button)
	var controls := Label.new()
	controls.text = "W A S D   Drive      MOUSE   Aim      LMB   Fire\nRMB   Scope      SPACE   Brake      WHEEL   Zoom\nESC   Pause / cursor      R   Restart range"
	controls.add_theme_color_override("font_color", muted)
	controls.add_theme_font_size_override("font_size", 15)
	column.add_child(controls)

func update_menu() -> void:
	if not is_instance_valid(menu):
		return
	menu.visible = not game.playing
	button.text = "RESUME TRAINING    →" if game.started else "ENTER TRAINING RANGE    →"
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
	label_at(Vector2(46, 53), "IRON FIELD", 21)
	label_at(Vector2(46, 80), "PROTOTYPE  /  TRAINING RANGE", 12, muted)
	draw_rect(Rect2(w - 275, 26, 247, 74), Color(0.03, 0.07, 0.08, 0.78))
	label_at(Vector2(w - 255, 49), "TARGETS   %02d / 06" % game.destroyed, 19)
	label_at(Vector2(w - 255, 75), "SHOTS  %02d    HITS  %02d" % [game.shots, game.hits], 13, muted)
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
	label_at(c + Vector2(33, 5), "%03d m" % int(distance), 13)
	if game.blocked:
		label_at(c + Vector2(-78, 64), "BARREL OBSTRUCTED", 13, Color("f39973"))
	draw_rect(Rect2(28, h - 124, 270, 96), Color(0.03, 0.07, 0.08, 0.80))
	label_at(Vector2(46, h - 91), "M-01  /  MEDIUM TANK", 13, muted)
	label_at(Vector2(46, h - 48), "%02d" % int(absf(game.tank.speed) * 3.6), 36)
	label_at(Vector2(107, h - 49), "KM/H", 13, muted)
	label_at(Vector2(208, h - 49), "REV" if game.tank.speed < -0.1 else "FWD", 16, amber)
	draw_rect(Rect2(c.x - 150, h - 129, 300, 91), Color(0.03, 0.07, 0.08, 0.7))
	var progress: float = 1 - game.cooldown / game.reload_time
	draw_rect(Rect2(c.x - 130, h - 91, 260, 3), Color(0.1, 0.15, 0.15, 0.9))
	draw_rect(Rect2(c.x - 130, h - 91, progress * 260, 3), amber)
	label_at(Vector2(c.x - 130, h - 106), "105 MM  /  " + ("READY" if game.cooldown <= 0 else "RELOADING  %.1f s" % game.cooldown), 15)
	label_at(Vector2(c.x - 130, h - 62), game.message, 12, ivory)
	label_at(Vector2(w - 302, h - 78), "RMB  SCOPE     LMB  FIRE", 13)
	label_at(Vector2(w - 302, h - 51), "SPACE  BRAKE     ESC  PAUSE", 13, muted)
	label_at(Vector2(30, h - 10), "WHITE: CAMERA AIM     AMBER: SHELL IMPACT     /     DEVELOPMENT BUILD", 10, muted)
