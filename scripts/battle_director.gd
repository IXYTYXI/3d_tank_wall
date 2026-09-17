extends Node3D
const Tank = preload("res://scripts/tank.gd")
const Visual = preload("res://scripts/tank_visual.gd")
const Field = preload("res://scripts/battlefield.gd")
const Navigation = preload("res://scripts/battle_navigation.gd")
const EnemyAI = preload("res://scripts/enemy_controller.gd")
const WAVE_COUNTS := [2,3,4,4,5]
var game: Node3D
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

func start() -> void:
	if active():
		return
	navigation = Navigation.new()
	navigation.build(game.field)
	for target in game.field.targets:
		if is_instance_valid(target):
			target.collision_layer = 0
			target.queue_free()
	game.field.targets.clear()
	base = game.field.block(Vector3(8,3,6),Vector3(0,Field.height(0,65)+1.5,65),Visual.material(Color("4f7775"),0.25))
	base.collision_layer = 4
	base.set_meta("base",true)
	Visual.box(base,Vector3(5,0.15,4),Vector3(0,1.6,0),Visual.material(Color("718882")))
	Visual.cylinder(base,0.07,6,Vector3(2.7,4,0),Visual.material(Color("b0bcb2"),0.5))
	Visual.box(base,Vector3(1.8,1,0.06),Vector3(3.6,6.5,0),Visual.material(Color("52bfaa")))
	var badge := Label3D.new()
	badge.text = "指挥基地"
	badge.font = preload("res://assets/fonts/ui_chinese.tres")
	badge.font_size = 64
	badge.pixel_size = 0.025
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.position = Vector3(0,4,0)
	base.add_child(badge)
	game.tank.eliminated.connect(player_eliminated)
	game.tank.damaged.connect(func(_amount: int): damage_flash = 0.45)
	phase = "countdown"
	game.message = "保护身后基地，准备迎敌"

func remaining() -> int:
	return pending+enemies.size()

func tick(dt: float) -> void:
	if not active() or finished() or phase == "upgrade":
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
			if wave == WAVE_COUNTS.size():
				finish(true,"全部敌军已被击退，基地守住了")
			else:
				phase = "upgrade"
				game.set_playing(false)

func begin_wave() -> void:
	if phase != "countdown":
		return
	wave += 1
	phase = "combat"
	pending = WAVE_COUNTS[wave-1]
	spawn_timer = 0
	game.message = "第 %d 波来袭，注意雷达" % wave
	spawn_enemy()

func spawn_enemy() -> CharacterBody3D:
	if pending <= 0:
		return null
	var actor := Tank.new()
	actor.faction = 1
	actor.variant = "重型坦克" if wave>=3 and spawned%3==0 else "轻型坦克" if spawned%3==1 else "标准坦克"
	actor.max_health = 135 if actor.variant=="重型坦克" else 65 if actor.variant=="轻型坦克" else 90
	actor.max_forward_speed = 4.2 if actor.variant=="重型坦克" else 7.0 if actor.variant=="轻型坦克" else 5.5
	var lane: float = [-24.0,0.0,24.0][spawned%3]
	var pos: Vector3 = navigation.safe_position(Vector3(lane,0,-30-wave*7-(spawned%2)*10))
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
	spawn_timer = 5.0
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

func player_eliminated(_actor: CharacterBody3D) -> void:
	finish(false,"你的坦克已被击毁")

func damage_base(amount: float) -> void:
	if finished() or not active():
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
		score += 500+base_health
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
