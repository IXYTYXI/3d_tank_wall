extends Node3D

const MAX_PARTICLES := 180
var particles: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var dust_accumulator := 0.0
var exhaust_accumulator := 0.0
var smoke_texture: ImageTexture
var quad: QuadMesh
var spark_mesh: BoxMesh
var smoke_base: StandardMaterial3D
var spark_base: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 20260917
	quad = QuadMesh.new()
	quad.size = Vector2.ONE
	spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.025,0.025,0.16)
	var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var p := Vector2(x-31.5,y-31.5)/31.5
			var alpha := pow(maxf(0,1-p.length()),1.4)
			alpha *= 0.72 + 0.28*sin(x*0.51+sin(y*0.37)*2)*sin(y*0.29)
			img.set_pixel(x,y,Color(1,1,1,alpha))
	smoke_texture = ImageTexture.create_from_image(img)
	smoke_base = StandardMaterial3D.new()
	smoke_base.albedo_texture = smoke_texture
	smoke_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_base.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_base.no_depth_test = false
	smoke_base.cull_mode = BaseMaterial3D.CULL_DISABLED
	spark_base = StandardMaterial3D.new()
	spark_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_base.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func particle(pos: Vector3, velocity: Vector3, color: Color, life: float, initial_size: float, growth: float, spark: bool = false) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front().node.queue_free()
	var node := MeshInstance3D.new()
	node.mesh = spark_mesh if spark else quad
	var mat: StandardMaterial3D = (spark_base if spark else smoke_base).duplicate()
	mat.albedo_color = color
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = pos
	node.scale = Vector3.ONE * initial_size
	particles.append({"node":node,"velocity":velocity,"age":0.0,"life":life,"size":initial_size,"growth":growth,"alpha":color.a,"spark":spark})

func fire(pos: Vector3, direction: Vector3) -> void:
	for i in range(12):
		var spread := Vector3(rng.randf_range(-0.6,0.6),rng.randf_range(-0.2,0.7),rng.randf_range(-0.6,0.6))
		particle(pos+direction*0.2, direction*rng.randf_range(1.5,4.8)+spread,Color(0.52,0.55,0.52,0.55),rng.randf_range(0.6,1.4),0.24,1.8)
	for i in range(7):
		particle(pos+direction*0.25,direction*rng.randf_range(7,15)+Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),0),Color("ffb54f"),0.18,1.0,0,true)
	var flame := MeshInstance3D.new()
	flame.mesh = quad
	var mat := smoke_base.duplicate()
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color("ffbb53")
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	flame.global_position = pos + direction*0.5
	flame.look_at(pos+direction*3)
	flame.scale = Vector3.ONE * 1.7
	var light := OmniLight3D.new()
	light.light_color = Color("ffc078")
	light.light_energy = 2.8
	light.omni_range = 6
	add_child(light)
	light.global_position = pos
	if flashes.size() >= 4:
		var oldest: Dictionary = flashes.pop_front()
		oldest.node.queue_free()
		oldest.light.queue_free()
	flashes.append({"node":flame,"light":light,"age":0.0,"life":0.075})

func impact(pos: Vector3, normal: Vector3, large: bool = false) -> void:
	var count := 20 if large else 10
	for i in range(count):
		var scatter := Vector3(rng.randf_range(-2,2),rng.randf_range(0.4,3.2),rng.randf_range(-2,2))
		particle(pos+normal*0.1,scatter+normal*1.5,Color(0.45,0.41,0.32,0.65),rng.randf_range(0.9,1.8),0.3,2.0 if large else 1.2)
	for i in range(18 if large else 9):
		var scatter := Vector3(rng.randf_range(-4,4),rng.randf_range(1,6),rng.randf_range(-4,4))
		particle(pos+normal*0.08,scatter+normal*2,Color("ffd18a"),rng.randf_range(0.2,0.6),1,0,true)

func drive(model: Node3D, speed: float, turning: float, dt: float) -> void:
	var intensity := minf(absf(speed)/8 + absf(turning)*0.5,1.0)
	if intensity > 0.08:
		dust_accumulator += dt*12*intensity
		if dust_accumulator >= 1:
			dust_accumulator = fmod(dust_accumulator,1)
			for side in [-1.0,1.0]:
				var pos: Vector3 = model.to_global(Vector3(side*1.6,0.18,1.9 if speed>=0 else -1.9))
				var drift: Vector3 = model.global_basis.z * signf(speed)*0.6+Vector3(0,0.35,0)
				particle(pos,drift,Color(0.53,0.48,0.36,0.28*intensity),1.1,0.5,1.8)
	exhaust_accumulator += dt
	if exhaust_accumulator > 0.28:
		exhaust_accumulator = 0
		var pos: Vector3 = model.to_global(Vector3(-0.65,1.0,2.55))
		particle(pos,Vector3(0,0.5,0)+model.global_basis.z*0.3,Color(0.26,0.29,0.28,0.17),1.25,0.25,0.65)

func tick(dt: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p := particles[i]
		p.age += dt
		if p.age >= p.life:
			p.node.queue_free()
			particles.remove_at(i)
			continue
		var ratio: float = p.age/p.life
		p.velocity += Vector3(0,-9.81 if p.spark else 0.25,0)*dt
		p.velocity *= exp(-dt*(0.4 if p.spark else 1.3))
		p.node.position += p.velocity*dt
		p.node.material_override.albedo_color.a = p.alpha*pow(1-ratio,0.8)
		if p.spark:
			if p.velocity.length_squared()>0.01:
				p.node.look_at(p.node.global_position+p.velocity)
		else:
			p.node.scale = Vector3.ONE*(p.size+p.age*p.growth)
	for i in range(flashes.size()-1,-1,-1):
		var flash := flashes[i]
		flash.age += dt
		if flash.age >= flash.life:
			flash.node.queue_free()
			flash.light.queue_free()
			flashes.remove_at(i)
		else:
			var strength: float = 1-flash.age/flash.life
			flash.light.light_energy = strength*2.8
			flash.node.material_override.albedo_color.a = strength
