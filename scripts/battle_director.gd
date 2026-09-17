extends Node3D
const Tank = preload("res://scripts/tank.gd")
const Visual = preload("res://scripts/tank_visual.gd")
const Field = preload("res://scripts/battlefield.gd")
const Navigation = preload("res://scripts/battle_navigation.gd")
const EnemyAI = preload("res://scripts/enemy_controller.gd")
const Assets = preload("res://scripts/battle_assets.gd")
const WAVE_COUNTS := [2,3,4,4,5]
var game: Node3D
var mode := "defense"
var time_left := 180.0
const ELIMINATION_TARGET := 12
var phase := "training"
var wave := 0
var countdown := 5.0
var pending := 0
var spawn_timer := 0.0
var spawned := 0
var enemies: Array[CharacterBody3D] = []
var controllers: Array[RefCounted] = []
var supplies: Array[Dictionary] = []
var navigation: RefCounted
var base: StaticBody3D
var base_health := 360
var base_max_health := 360
var kills := 0
var score := 0
var repair_charges := 2
var fast_reload_time := 0.0
var elapsed := 0.0
var result_reason := ""
var damage_flash := 0.0

func active() -> bool:
	return phase != "training"

func finished() -> bool:
	return phase == "won" or phase == "lost"

func mode_name() -> String:
	return {"defense":"基地防守","survival":"无尽生存","elimination":"限时歼灭"}.get(mode,"基地防守")

func progress_text() -> String:
	if mode == "elimination":
		return "歼灭 %02d / %02d" % [kills,ELIMINATION_TARGET]
	if mode == "survival":
		return "波次 %02d · 敌军 %d" % [wave,remaining()]
	return "波次 %02d / 05 · 敌军 %d" % [wave,remaining()]

func start(selected_mode: String = "defense") -> void:
	if active():
		return
	mode = selected_mode if selected_mode in ["defense","survival","elimination"] else "defense"
	navigation = Navigation.new()
	for target in game.field.targets:
		if is_instance_valid(target):
			target.collision_layer = 0
			target.queue_free()
	game.field.targets.clear()
	if mode == "defense":
		base = game.field.block(Vector3(8.8,3.4,6.8),Vector3(0,Field.height(0,65)+1.7,65),Visual.material(Color("4f7775")),false)
		base.collision_layer = 4
		base.set_meta("base",true)
		var building: Node3D = Assets.headquarters(base)
		building.position.y = -1.7
		# Roof overhang and parapet remain solid to shells as well as vehicles.
		var roof := CollisionShape3D.new()
		var roof_shape := BoxShape3D.new()
		roof_shape.size = Vector3(9.3,0.38,7.3)
		roof.shape = roof_shape
		roof.position.y = 1.52
		base.add_child(roof)
		for side in [-1.0,1.0]:
			var bags := CollisionShape3D.new()
			var bags_shape := BoxShape3D.new()
			bags_shape.size = Vector3(0.62,1.15,3.20)
			bags.shape = bags_shape
			bags.position = Vector3(side*3.55,-1.12,-3.02)
			base.add_child(bags)
		var badge := Label3D.new()
		badge.text = "指挥基地"
		badge.font = preload("res://assets/fonts/ui_chinese.tres")
		badge.font_size = 38
		badge.pixel_size = 0.016
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.position = Vector3(0,4.5,0)
		base.add_child(badge)
	navigation.build(game.field)
	game.tank.eliminated.connect(player_eliminated)
	game.tank.damaged.connect(func(_amount: int): damage_flash = 0.45)
	phase = "countdown"
	game.message = "保护身后基地，准备迎敌" if mode=="defense" else "准备迎敌 / " + mode_name()

func remaining() -> int:
	return pending+enemies.size()

func tick(dt: float) -> void:
	if not active() or finished() or phase == "upgrade":
		return
	if mode == "elimination" and phase == "combat":
		time_left = maxf(0,time_left-dt)
		if time_left <= 0:
			finish(false,"时间耗尽，未完成 12 辆歼灭目标")
			return
	elapsed += dt
	damage_flash = maxf(0,damage_flash-dt)
	fast_reload_time = maxf(0,fast_reload_time-dt)
	update_supplies(dt)
	if phase == "countdown":
		countdown -= dt
		if countdown <= 0:
			begin_wave()
	elif phase == "combat":
		spawn_timer -= dt
		if pending>0 and enemies.size()<4 and spawn_timer<=0:
			spawn_enemy()
		for controller in controllers.duplicate():
			if is_instance_valid(controller.actor) and not controller.actor.dead:
				controller.tick(dt)
		if pending == 0 and enemies.is_empty():
			if mode == "elimination":
				finish(true,"歼灭目标达成")
			elif mode == "defense" and wave == WAVE_COUNTS.size():
				finish(true,"全部敌军已被击退，基地守住了")
			else:
				phase = "upgrade"
				game.set_playing(false)

func begin_wave() -> void:
	if phase != "countdown":
		return
	wave += 1
	phase = "combat"
	pending = ELIMINATION_TARGET if mode=="elimination" else mini(12,wave+2) if mode=="survival" else WAVE_COUNTS[wave-1]
	spawn_timer = 0
	game.message = "第 %d 波来袭，注意雷达" % wave
	spawn_enemy()

func spawn_enemy() -> CharacterBody3D:
	if pending <= 0:
		return null
	var actor := Tank.new()
	actor.faction = 1
	actor.variant = "重型坦克" if (wave>=3 or mode=="elimination") and spawned%3==0 else "轻型坦克" if spawned%3==1 else "标准坦克"
	actor.max_health = 135 if actor.variant=="重型坦克" else 65 if actor.variant=="轻型坦克" else 90
	actor.max_forward_speed = 4.2 if actor.variant=="重型坦克" else 7.0 if actor.variant=="轻型坦克" else 5.5
	var lane: float = [-24.0,0.0,24.0][spawned%3]
	var pos: Vector3 = navigation.safe_position(Vector3(lane,0,-30-mini(wave,5)*7-(spawned%2)*10))
	# Avoid spawning into a surviving tank in the same lane.
	for enemy in enemies:
		if enemy.position.distance_to(pos)<8:
			pos = navigation.safe_position(pos+Vector3(12,0,-8))
	add_child(actor)
	actor.position = pos
	actor.spawn_point = pos
	actor.rotation.y = PI
	actor.eliminated.connect(enemy_eliminated)
	enemies.append(actor)
	var controller := EnemyAI.new()
	controller.setup(actor,self,spawned)
	controllers.append(controller)
	spawned += 1
	pending -= 1
	spawn_timer = 2.5 if mode=="elimination" else 5.0
	return actor

func enemy_eliminated(actor: CharacterBody3D) -> void:
	if not enemies.has(actor):
		return
	enemies.erase(actor)
	for i in range(controllers.size()-1,-1,-1):
		if controllers[i].actor == actor:
			controllers.remove_at(i)
	kills += 1
	score += 150 if actor.variant=="重型坦克" else 100
	game.destroyed = kills
	game.message = "击毁%s / +%d 分" % [actor.variant,150 if actor.variant=="重型坦克" else 100]
	game.fx.impact(actor.position+Vector3.UP,Vector3.UP,true)
	drop_supply(actor.position,"repair" if kills%2==1 else "reload")
	actor.queue_free()
	if mode=="elimination" and kills>=ELIMINATION_TARGET:
		finish(true,"在时限内完成 12 辆歼灭目标")

func player_eliminated(_actor: CharacterBody3D) -> void:
	finish(false,"你的坦克已被击毁")

func damage_base(amount: float) -> void:
	if finished() or not active() or mode != "defense":
		return
	base_health = maxi(0,base_health-roundi(amount))
	game.message = "基地受到攻击！"
	if base_health == 0:
		finish(false,"指挥基地失守")

func finish(won: bool, reason: String) -> void:
	if finished():
		return
	phase = "won" if won else "lost"
	result_reason = reason
	if won:
		score += 500+(base_health if mode=="defense" else ceili(time_left)*5 if mode=="elimination" else 0)
	game.set_playing(false)

func use_repair() -> bool:
	if not active() or finished() or repair_charges<=0 or game.tank.health>=game.tank.max_health:
		return false
	var restored: int = game.tank.repair(40)
	if restored<=0:
		return false
	repair_charges -= 1
	game.message = "应急维修 / 恢复 %d 生命" % restored
	return true

func apply_upgrade(kind: String) -> bool:
	if phase != "upgrade" or kind not in ["armor","reload","mobility"]:
		return false
	match kind:
		"armor":
			game.tank.max_health += 30
			game.tank.repair(45)
		"reload":
			game.reload_time = maxf(1.1,game.reload_time*0.86)
		"mobility":
			game.tank.max_forward_speed = minf(20,game.tank.max_forward_speed*1.15)
			game.tank.repair(15)
	phase = "countdown"
	countdown = 7.0
	game.message = "整备完成，准备下一波"
	game.set_playing(true)
	return true

func drop_supply(pos: Vector3, kind: String) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(pos.x,Field.height(pos.x,pos.z)+0.7,pos.z)
	var color := Color("6fd3a0") if kind=="repair" else Color("e2b75f")
	Visual.box(node,Vector3(0.85,0.7,0.85),Vector3.ZERO,Visual.material(color,0.25))
	Visual.box(node,Vector3(0.60,0.10,0.12),Vector3(0,0.4,0),Visual.material(Color.WHITE))
	if kind=="repair":
		Visual.box(node,Vector3(0.12,0.10,0.60),Vector3(0,0.4,0),Visual.material(Color.WHITE))
	supplies.append({"node":node,"kind":kind,"life":40.0,"base_y":node.position.y})

func collect_supply(kind: String) -> void:
	if kind=="repair":
		var restored: int = game.tank.repair(30)
		game.message = "拾取维修补给 / 恢复 %d 生命" % restored
	else:
		fast_reload_time = 12.0
		game.message = "急速装填 / 持续 12 秒"
	score += 25

func update_supplies(dt: float) -> void:
	for i in range(supplies.size()-1,-1,-1):
		var supply := supplies[i]
		supply.life -= dt
		supply.node.rotation.y += dt*0.7
		supply.node.position.y = supply.base_y+sin(elapsed*2)*0.12
		var near: bool = supply.node.position.distance_to(game.tank.position)<3.3
		if near:
			collect_supply(supply.kind)
		if near or supply.life<=0:
			supply.node.queue_free()
			supplies.remove_at(i)
