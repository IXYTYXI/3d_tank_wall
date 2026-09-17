extends RefCounted
const Field = preload("res://scripts/battlefield.gd")
const ORIGIN := -112.0
const CELL := 4.0
const COUNT := 57
var grid := AStarGrid2D.new()

func build(field: Node3D) -> void:
	grid.region = Rect2i(0,0,COUNT,COUNT)
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = Vector2(ORIGIN,ORIGIN)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for body in field.get_children():
		if not body is StaticBody3D or body.has_meta("target"):
			continue
		for child in body.get_children():
			if not child is CollisionShape3D or child.shape is ConcavePolygonShape3D:
				continue
			var bounds: AABB = child.shape.get_debug_mesh().get_aabb()
			var half: Vector3 = bounds.size*0.5
			var basis: Basis = child.global_basis
			var extent: Vector3 = basis.x.abs()*half.x+basis.y.abs()*half.y+basis.z.abs()*half.z
			var center: Vector3 = child.global_transform*bounds.get_center()
			var left := clampi(ceili((center.x-extent.x-2.9-ORIGIN)/CELL),0,COUNT-1)
			var right := clampi(floori((center.x+extent.x+2.9-ORIGIN)/CELL),0,COUNT-1)
			var top := clampi(ceili((center.z-extent.z-2.9-ORIGIN)/CELL),0,COUNT-1)
			var bottom := clampi(floori((center.z+extent.z+2.9-ORIGIN)/CELL),0,COUNT-1)
			for z in range(top,bottom+1):
				for x in range(left,right+1):
					grid.set_point_solid(Vector2i(x,z))

func cell(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((pos.x-ORIGIN)/CELL),0,COUNT-1),clampi(roundi((pos.z-ORIGIN)/CELL),0,COUNT-1))

func nearest_open(pos: Vector3) -> Vector2i:
	var center := cell(pos)
	for radius in range(12):
		var best := Vector2i(-1,-1)
		var score := INF
		for z in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var candidate := center+Vector2i(x,z)
				if not grid.region.has_point(candidate) or grid.is_point_solid(candidate):
					continue
				var dist := Vector2(candidate-center).length_squared()
				if dist < score:
					score = dist
					best = candidate
		if best.x >= 0:
			return best
	return center

func safe_position(pos: Vector3) -> Vector3:
	var id := nearest_open(pos)
	var p := grid.get_point_position(id)
	return Vector3(p.x,Field.height(p.x,p.y)+0.4,p.y)

func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	return grid.get_point_path(nearest_open(from),nearest_open(to))
