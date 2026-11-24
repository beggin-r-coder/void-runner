class_name SaveStore
extends Node
## DashCore: versioned local save with atomic replacement and last-good backup.
## Write temp -> validate -> back up primary -> replace primary.
## Corrupt primary -> recover backup -> otherwise reset with a clear status.
## Unique reward IDs prevent duplicate credit (reward ledger).
## Note: local saves are not tamper-proof; never base paid/competitive claims on them.

signal changed

const SCHEMA_VERSION := 2
const MAX_LEDGER := 64
const DEFAULTS := {
	"schema_version": SCHEMA_VERSION,
	"credits": 0,
	"best_score": 0,
	"best_distance": 0,
	"total_runs": 0,
	"tutorial_done": false,
	"livery": "nova",
	"unlocked_liveries": ["nova"],
	"granted_rewards": [],
	"settings": {
		"reduced_motion": false,
		"invert_y": false,
		"quality": "high",
		"sfx_volume": 0.9,
		"haptics": true,
	},
}

var path: String = "user://void_runner_save.json"
var data: Dictionary = {}
## "loaded", "fresh", "recovered_backup" or "reset_corrupt"
var last_load_status: String = ""


func _ready() -> void:
	load_save()


func load_save() -> void:
	var primary: Variant = _read(path)
	if primary != null:
		data = migrate(primary)
		last_load_status = "loaded"
		return
	var backup: Variant = _read(path + ".bak")
	if backup != null:
		data = migrate(backup)
		last_load_status = "recovered_backup"
		commit()
		return
	data = migrate({})
	last_load_status = "reset_corrupt" if FileAccess.file_exists(path) else "fresh"


static func migrate(src: Dictionary) -> Dictionary:
	var out: Dictionary = src.duplicate(true)
	var version := int(out.get("schema_version", 1))
	if version < 2:
		# v1 stored "coins" and a flat "reduced_motion" flag.
		if out.has("coins"):
			out["credits"] = int(out["coins"])
			out.erase("coins")
		if out.has("reduced_motion"):
			var s: Dictionary = out.get("settings", {})
			s["reduced_motion"] = bool(out["reduced_motion"])
			out["settings"] = s
			out.erase("reduced_motion")
	for key in DEFAULTS:
		if not out.has(key):
			out[key] = _copy(DEFAULTS[key])
	var settings: Dictionary = out["settings"]
	for key in DEFAULTS["settings"]:
		if not settings.has(key):
			settings[key] = DEFAULTS["settings"][key]
	# JSON numbers come back as floats.
	for key in ["credits", "best_score", "best_distance", "total_runs"]:
		out[key] = int(out[key])
	out["schema_version"] = SCHEMA_VERSION
	return out


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var text := FileAccess.get_file_as_string(p)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


func commit() -> bool:
	var text := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if _read(tmp) == null:
		return false
	var abs_primary := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_primary, abs_primary + ".bak")
		DirAccess.remove_absolute(abs_primary)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_primary)
	changed.emit()
	return err == OK


func setting(key: String) -> Variant:
	return (data["settings"] as Dictionary).get(key, DEFAULTS["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	commit()


## Credits a reward exactly once per reward_id. Returns false for duplicates.
func grant_reward(reward_id: String, credits: int) -> bool:
	var ledger: Array = data["granted_rewards"]
	if reward_id in ledger:
		return false
	ledger.append(reward_id)
	while ledger.size() > MAX_LEDGER:
		ledger.pop_front()
	data["credits"] = int(data["credits"]) + credits
	commit()
	return true


func spend(credits: int) -> bool:
	if int(data["credits"]) < credits:
		return false
	data["credits"] = int(data["credits"]) - credits
	commit()
	return true
