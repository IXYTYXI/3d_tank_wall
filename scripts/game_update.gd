extends Node
signal checked(message: String, download_url: String)
const MANIFEST := "https://raw.githubusercontent.com/IXYTYXI/3d_tank_wall/prototype/first-playable/docs/latest-release.json"
const PAGE := "https://github.com/IXYTYXI/3d_tank_wall/releases"
const DOWNLOAD_PREFIX := "https://github.com/IXYTYXI/3d_tank_wall/releases/download/"
var request: HTTPRequest
var busy := false

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 12
	request.body_size_limit = 1048576
	add_child(request)
	request.request_completed.connect(_completed)

static func version(text: String) -> Array[int]:
	var regex := RegEx.new()
	regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)(?:-[A-Za-z0-9.-]+)?$")
	var found := regex.search(text)
	if not found: return []
	return [int(found.get_string(1)),int(found.get_string(2)),int(found.get_string(3))]

static func newer(a: Array[int], b: Array[int]) -> bool:
	for i in range(3):
		if a[i]!=b[i]: return a[i]>b[i]
	return false

static func select_release(data: Variant, current: String, platform: String) -> Dictionary:
	var installed := version(current)
	if not data is Array or installed.size()!=3:
		return {"error":true}
	var best := installed
	var selected: Dictionary = {}
	var suffix := "-macOS-universal.dmg" if platform=="macOS" else "-Windows-x64.zip" if platform=="Windows" else ""
	if suffix.is_empty(): return {"unsupported":true}
	for item in data:
		if not item is Dictionary or item.get("draft",false): continue
		var release_version := version(str(item.get("tag_name","")))
		if release_version.size()!=3 or not newer(release_version,best): continue
		var assets: Variant = item.get("assets",[])
		if not assets is Array: continue
		for asset in assets:
			if not asset is Dictionary: continue
			var url := str(asset.get("browser_download_url",""))
			if str(asset.get("name","")).ends_with(suffix) and url.begins_with(DOWNLOAD_PREFIX) and asset.get("state","")=="uploaded":
				best = release_version
				selected = {"version":"%d.%d.%d" % best,"url":url}
	return selected

func check_now() -> void:
	if busy: return
	busy = true
	var error := request.request(MANIFEST,["Accept: application/json","User-Agent: SteelFront-UpdateChecker"])
	if error!=OK:
		busy = false
		checked.emit("无法连接更新服务，请稍后重试或打开下载页。","")

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		checked.emit("检查失败（网络或服务限制），可重试或打开下载页。","")
		return
	var release := select_release(JSON.parse_string(body.get_string_from_utf8()),str(ProjectSettings.get_setting("application/config/version")),OS.get_name())
	if release.has("error"):
		checked.emit("更新信息无法读取，请打开下载页。","")
	elif release.has("unsupported"):
		checked.emit("请在下载页选择适合本机的版本。","")
	elif release.is_empty():
		checked.emit("当前已是本平台发布的最新版本。","")
	else:
		checked.emit("发现新版 %s。点击下载后，退出游戏再安装。" % release.version,release.url)
