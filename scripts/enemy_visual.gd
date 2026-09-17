extends Node3D
const Parts = preload("res://scripts/tank_visual.gd")
const Geometry = preload("res://scripts/armor_geometry.gd")
var turret: Node3D
var barrel: Node3D
var muzzle: Marker3D
var armor: StandardMaterial3D
var gun: Node3D
var recoil := 0.0
var variant := "标准坦克"

func _ready() -> void:
	var color := Color("745443")
	if variant == "轻型坦克":
		color = Color("8a7050")
	elif variant == "重型坦克":
		color = Color("5d4240")
	armor = Parts.material(color,0.35,0.65)
	var dark := Parts.material(Color("202422"),0.15)
	Geometry.plate(self,Vector3(2.8,0.85,4.5),Vector3(0,1.02,0),armor,0.09,0.12)
	for side in [-1.0,1.0]:
		Geometry.plate(self,Vector3(0.65,0.92,4.6),Vector3(side*1.53,0.61,0),dark,0.15)
		for i in range(6):
			var wheel := Parts.cylinder(self,0.34,0.7,Vector3(side*1.54,0.60,-1.72+i*0.69),armor)
			wheel.rotation.z = PI/2
		Geometry.plate(self,Vector3(0.12,0.42,4.12),Vector3(side*1.92,1.07,0),armor,0.04)
	var front := Geometry.plate(self,Vector3(2.7,0.15,1.1),Vector3(0,1.21,-2.04),armor,0.05)
	front.rotation.x = 0.4
	turret = Node3D.new()
	add_child(turret)
	turret.position = Vector3(0,1.65,-0.25)
	Geometry.plate(turret,Vector3(2.15,0.72,2),Vector3(0,0.32,0.15),armor,0.15,0.14)
	Parts.cylinder(turret,0.3,0.1,Vector3(0.4,0.74,0.2),dark)
	Parts.cylinder(turret,0.012,1.15,Vector3(-0.7,1.12,0.8),dark)
	barrel = Node3D.new()
	turret.add_child(barrel)
	barrel.position = Vector3(0,0.38,-0.94)
	gun = Node3D.new()
	barrel.add_child(gun)
	var tube := Parts.cylinder(gun,0.115,3.5,Vector3(0,0,-1.75),armor)
	tube.rotation.x = PI/2
	Parts.box(barrel,Vector3(0.65,0.42,0.4),Vector3.ZERO,dark)
	muzzle = Marker3D.new()
	barrel.add_child(muzzle)
	muzzle.position.z = -3.72

func kick_recoil() -> void:
	recoil = 0.25
	gun.position.z = recoil

func animate(_speed: float, dt: float, _turn_rate: float = 0.0) -> void:
	recoil = move_toward(recoil,0,dt*0.75)
	gun.position.z = recoil
