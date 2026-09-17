extends RefCounted

static func advance(position: Vector3, velocity: Vector3, dt: float) -> Dictionary:
	var gravity := Vector3(0, -9.81, 0)
	return {"position": position + velocity * dt + gravity * dt * dt * 0.5,
		"velocity": velocity + gravity * dt}

static func elevation(local_direction: Vector3) -> float:
	return clampf(atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length()), deg_to_rad(-9), deg_to_rad(22))

static func armor_damage(raw: float, travel_direction: Vector3, hull: Basis) -> int:
	if raw <= 0:
		return 0
	var incoming := -travel_direction.normalized()
	var frontal := incoming.dot(-hull.z.normalized())
	var multiplier := 0.65 if frontal > 0.6 else 1.4 if frontal < -0.6 else 1.0
	return maxi(1,roundi(raw*multiplier))

static func ballistic_aim(origin: Vector3, target: Vector3, speed: float = 115.0) -> Vector3:
	var flight_time := origin.distance_to(target)/speed
	return target+Vector3.UP*4.905*flight_time*flight_time
