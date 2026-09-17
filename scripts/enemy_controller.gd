extends RefCounted
const Combat = preload("res://scripts/combat_math.gd")
var actor: CharacterBody3D
var director: Node3D
var route := PackedVector2Array()
var route_index := 0
var repath := 0.0
var cooldown := 3.5
var interval := 4.5
var damage := 17.0
var stuck_time := 0.0
var reverse_time := 0.0
var previous := Vector3.ZERO
var side := 1.0
var shots_fired := 0

func setup(body: CharacterBody3D, battle: Node3D, id: int) -> void:
	actor = body
	director = battle
	previous = body.position
	side = -1.0 if id%2 == 0 else 1.0
	cooldown += (id%3)*0.5
	if actor.variant == "轻型坦克":
		interval = 3.5
		damage = 13
	elif actor.variant == "重型坦克":
		interval = 5.0
		damage = 24

func tick(dt: float) -> void:
	if actor.dead:
		return
	var game: Node3D = director.game
	cooldown = maxf(0,cooldown-dt)
	repath -= dt
	var target: Node3D = game.tank if not is_instance_valid(director.base) or actor.position.distance_to(game.tank.position)<72 else director.base
	var target_point: Vector3 = target.global_position+Vector3(0,1.25,0)
	if target == director.base:
		target_point = director.base.global_position+Vector3(0,0.8,0)
	var eye: Vector3 = actor.model.barrel.global_position
	actor.aim_point = Combat.ballistic_aim(eye,target_point)
	var excluded: Array[RID] = [actor.get_rid()]
	var line: Dictionary = game.ray(eye,target_point,excluded)
	var visible: bool = not line.is_empty() and line.collider == target
	var distance: float = actor.position.distance_to(target.position)
	var firing_range := 45.0 if actor.variant == "重型坦克" else 33.0
	if visible and distance < firing_range:
		actor.throttle = 0
		actor.steering = 0
		actor.brake = true
	else:
		actor.brake = false
		if repath <= 0 or route.is_empty():
			route = director.navigation.path(actor.position,target.position)
			route_index = 0
			repath = 2.0
		var waypoint := target.position
		while route_index < route.size():
			waypoint = Vector3(route[route_index].x,actor.position.y,route[route_index].y)
			if Vector2(waypoint.x-actor.position.x,waypoint.z-actor.position.z).length()>3:
				break
			route_index += 1
		var direction: Vector3 = waypoint-actor.position
		var desired := atan2(-direction.x,-direction.z)
		var error := wrapf(desired-actor.rotation.y,-PI,PI)
		actor.steering = clampf(error*2,-1,1)
		actor.throttle = 0.8 if absf(error)<0.9 else 0.0
		if actor.position.distance_to(previous)<0.008 and actor.throttle>0.1:
			stuck_time += dt
		else:
			stuck_time = 0
		if stuck_time>1.5:
			reverse_time = 1.1
			stuck_time = 0
			repath = 0
		if reverse_time>0:
			reverse_time -= dt
			actor.throttle = -0.7
			actor.steering = side
	previous = actor.position
	var barrel_direction: Vector3 = -actor.model.muzzle.global_basis.z
	var desired_direction: Vector3 = (actor.aim_point-actor.model.muzzle.global_position).normalized()
	if visible and distance < 80 and cooldown <= 0 and barrel_direction.dot(desired_direction)>0.998:
		game.fire_actor(actor,damage)
		cooldown = interval
		shots_fired += 1
