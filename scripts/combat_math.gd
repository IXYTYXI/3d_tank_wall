extends RefCounted

static func advance(position: Vector3, velocity: Vector3, dt: float) -> Dictionary:
	var gravity := Vector3(0, -9.81, 0)
	return {"position": position + velocity * dt + gravity * dt * dt * 0.5,
		"velocity": velocity + gravity * dt}

static func elevation(local_direction: Vector3) -> float:
	return clampf(atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length()), deg_to_rad(-9), deg_to_rad(22))
