extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func _initialize() -> void:
	var rules = load("res://scripts/combat_math.gd")
	if not rules.has_method("armor_damage"):
		check(false,"Directional armor damage must be implemented")
		quit(1)
		return
	check(rules.armor_damage(100,Vector3.BACK,Basis.IDENTITY)==65,"Front armor reduces damage")
	check(rules.armor_damage(100,Vector3.FORWARD,Basis.IDENTITY)==140,"Rear armor is vulnerable")
	check(rules.armor_damage(100,Vector3.RIGHT,Basis.IDENTITY)==100,"Side armor applies normal damage")
	check(rules.armor_damage(100,Vector3.RIGHT,Basis(Vector3.UP,PI/2))==65,"Armor direction follows hull rotation")
	check(rules.armor_damage(0,Vector3.BACK,Basis.IDENTITY)==0,"Zero damage stays zero")
	print("BATTLE RULES RESULT: ",failures," failures")
	quit(0 if failures==0 else 1)
