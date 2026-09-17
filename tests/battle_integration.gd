extends SceneTree
var failures := 0
var game: Node3D
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func _initialize() -> void:
	call_deferred("run")
func session() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.start_defense()
	game.set_physics_process(false)
	game.tank.set_physics_process(false)
	await frames(3)
func dispose() -> void:
	game.queue_free()
	await frames(3)
func run() -> void:
	await session()
	var battle: Node3D = game.battle
	check(battle.phase=="countdown" and battle.base_health==360,"Defense starts with intact base and countdown")
	check(game.field.targets.is_empty(),"Training targets are removed in defense mode")
	check(battle.navigation.path(Vector3(0,0,43),Vector3(0,0,-40)).size()>1,"Navigation finds a route across the battlefield")
	check(not battle.use_repair() and battle.repair_charges==2,"Repair at full health consumes no charge")
	game.tank.take_damage(40,Vector3.BACK)
	check(battle.use_repair() and game.tank.health==game.tank.max_health and battle.repair_charges==1,"Emergency repair restores capped health and consumes one charge")
	battle.tick(6)
	check(battle.phase=="combat" and battle.wave==1 and battle.enemies.size()==1,"Countdown starts first wave with an enemy")
	var enemy: CharacterBody3D = battle.enemies[0]
	enemy.set_physics_process(false)
	game.tank.position = Vector3(0,12,0)
	game.tank.rotation = Vector3.ZERO
	game.tank.model.basis = Basis.IDENTITY
	game.tank.model.turret.rotation = Vector3.ZERO
	game.tank.model.barrel.rotation = Vector3.ZERO
	enemy.position = Vector3(0,12,-20)
	enemy.rotation.y = PI
	enemy.model.turret.rotation = Vector3.ZERO
	enemy.model.barrel.rotation = Vector3.ZERO
	await frames(3)
	var enemy_health: int = enemy.health
	game.fire()
	game.update_shells(0.20)
	check(enemy.health<enemy_health,"Player shell physically hits enemy armor")
	check(game.tank.health==game.tank.max_health,"Projectile excludes its own firing tank")
	var player_health: int = game.tank.health
	game.fire_actor(enemy,20)
	game.update_shells(0.20)
	check(game.tank.health<player_health,"Enemy shell physically damages player")
	var wall: StaticBody3D = game.field.block(Vector3(6,6,0.15),Vector3(0,14,-10),enemy.model.armor)
	await frames(3)
	enemy_health = enemy.health
	game.cooldown = 0
	game.fire()
	game.update_shells(0.20)
	check(enemy.health==enemy_health and game.shells.is_empty(),"Cover stops a player shell before the enemy")
	wall.queue_free()
	await frames(3)
	var friend = load("res://scripts/tank.gd").new()
	friend.faction = 1
	game.add_child(friend)
	friend.position = Vector3(0,12,-10)
	friend.set_physics_process(false)
	await frames(3)
	player_health = game.tank.health
	game.fire_actor(enemy,20)
	game.update_shells(0.20)
	check(friend.health==friend.max_health and game.tank.health==player_health,"Friendly tanks block shots without taking friendly damage")
	friend.queue_free()
	await frames(3)
	game.impact({"position":battle.base.position,"collider":battle.base},0,30,Vector3.FORWARD)
	check(battle.base_health==360,"Player cannot damage own base")
	game.impact({"position":battle.base.position,"collider":battle.base},1,30,Vector3.FORWARD)
	check(battle.base_health==330,"Enemy hits damage the base")
	game.tank.position = Vector3(0,load("res://scripts/battlefield.gd").height(0,43),43)
	game.tank.health = 80
	battle.drop_supply(game.tank.position,"repair")
	battle.update_supplies(0.1)
	check(game.tank.health==110 and battle.supplies.is_empty(),"Nearby repair supply is collected exactly once")
	battle.collect_supply("reload")
	game.cooldown = 0
	game.fire()
	check(is_equal_approx(game.cooldown,game.reload_time*0.65),"Reload supply reduces the next reload duration")
	battle.pending = 0
	enemy.take_damage(9999,Vector3.FORWARD)
	await frames(2)
	check(battle.kills==1 and battle.enemies.is_empty(),"Destroyed enemy counts once and leaves active list")
	battle.tick(0.01)
	check(battle.phase=="upgrade" and not game.playing,"Cleared wave pauses for upgrade selection")
	var old_max: int = game.tank.max_health
	check(battle.apply_upgrade("armor") and game.tank.max_health==old_max+30,"Armor upgrade increases maximum health")
	check(not battle.apply_upgrade("reload"),"Repeated upgrade click cannot grant another upgrade")
	game.set_playing(false)
	var timer: float = battle.countdown
	var life: float = battle.fast_reload_time
	game._physics_process(1)
	check(battle.countdown==timer and battle.fast_reload_time==life,"Pause freezes wave and buff timers")
	game.set_playing(true)
	for expected_wave in range(2,6):
		battle.tick(8)
		check(battle.wave==expected_wave and battle.phase=="combat","Wave %d starts after preparation" % expected_wave)
		while battle.remaining()>0:
			for unit in battle.enemies.duplicate():
				unit.take_damage(9999,Vector3.FORWARD)
			battle.tick(6)
			await frames(1)
		if expected_wave<5:
			var old_reload: float = game.reload_time
			var old_speed: float = game.tank.max_forward_speed
			var kind := "reload" if expected_wave==2 else "mobility"
			check(battle.apply_upgrade(kind),"Wave %d allows next upgrade" % expected_wave)
			check(game.reload_time<old_reload if kind=="reload" else game.tank.max_forward_speed>old_speed,"Selected upgrade changes its combat parameter")
	check(battle.kills==17,"Remaining waves spawn and count all scheduled enemies")
	check(battle.phase=="won" and not game.playing,"Clearing fifth wave wins and stops battle")
	game.set_playing(true)
	check(not game.playing,"Finished battle cannot resume")
	var score: int = battle.score
	battle.finish(true,"duplicate")
	check(battle.score==score,"Victory reward is awarded only once")
	await dispose()
	await session()
	game.battle.damage_base(9999)
	check(game.battle.phase=="lost" and not game.playing,"Destroyed base ends the battle in defeat")
	await dispose()
	await session()
	game.tank.take_damage(9999,Vector3.FORWARD)
	check(game.battle.phase=="lost" and game.tank.dead,"Destroyed player ends the battle in defeat")
	check(not game.battle.use_repair(),"Repair cannot resurrect a destroyed tank")
	await dispose()
	print("BATTLE INTEGRATION RESULT: ",failures," failures")
	quit(0 if failures==0 else 1)
