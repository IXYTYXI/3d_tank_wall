extends SceneTree
const Update = preload("res://scripts/game_update.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func release(tag: String, suffix: String, url: String = "") -> Dictionary:
	return {"tag_name":tag,"assets":[{"name":"SteelFront"+suffix,"state":"uploaded","browser_download_url":Update.DOWNLOAD_PREFIX+tag+"/SteelFront"+suffix if url.is_empty() else url}]}
func _initialize() -> void:
	var win := "-Windows-x64.zip"
	var mac := "-macOS-universal.dmg"
	check(Update.newer(Update.version("v0.10.0-preview"),Update.version("0.9.9")),"Versions compare numerically")
	check(Update.version("vwrong").is_empty(),"Malformed versions are rejected")
	check(Update.select_release(null,"0.4.2","Windows").has("error"),"Invalid response is an error, not up to date")
	check(Update.select_release([release("v0.4.2-preview",win)],"0.4.2","Windows").is_empty(),"Current version is not offered again")
	var data := [release("v0.5.0-preview",mac),release("v0.4.3-preview",win),release("v0.6.0-preview",win,"https://example.com/unsafe.exe")]
	check(Update.select_release(data,"0.4.2","Windows").get("version")=="0.4.3","Select newest matching platform and allow only repository assets")
	check(Update.select_release(data,"0.4.2","macOS").get("version")=="0.5.0","Mac selects universal DMG")
	var draft := release("v9.0.0-preview",win)
	draft.draft = true
	check(Update.select_release([draft],"0.4.2","Windows").is_empty(),"Draft releases are ignored")
	check(Update.select_release([],"0.4.2","Linux").has("unsupported"),"Unsupported systems use release page")
	print("UPDATE RESULT: ",failures," failures")
	quit(1 if failures else 0)
