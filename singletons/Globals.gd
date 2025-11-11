extends Node

# warning-ignore:unused_class_variable
var spawnpoint = ""
var current_level = ""
var money = 0
var points = 0
var player_position = Vector2()
var lang_colors: Dictionary = {}
var mine_accumulation_rates: Dictionary = {} # Stores accumulation rates for each language mine
var upgrades: Dictionary = {} # Stores upgrade states {upgrade_name: level}
var pending_repository_data = null

func format_bytes(bytes: float) -> String:
	if bytes == 0:
		return "0 bytes"

	var units = ["bytes", "KB", "MB", "GB", "TB"]
	var unit_index = 0
	var value = bytes

	while value >= 1024 and unit_index < units.size() - 1:
		value /= 1024.0
		unit_index += 1

	if unit_index == 0:
		return str(int(bytes)) + " " + units[unit_index]
	else:
		return "%.1f %s" % [value, units[unit_index]]

func _ready():
	RenderingServer.set_default_clear_color(Color.WHITE)
	_load_language_colors()
	_initialize_upgrades()

func _load_language_colors():
	var colors_file = "res://data/lang-colors.json"
	if FileAccess.file_exists(colors_file):
		var file = FileAccess.open(colors_file, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var colors_data = json.get_data()
			for lang_name in colors_data:
				if colors_data[lang_name].has("color"):
					var color_hex = colors_data[lang_name]["color"]
					if color_hex != null and color_hex is String and color_hex.begins_with("#"):
						lang_colors[lang_name] = Color(color_hex)

func _initialize_upgrades():
	# Define available upgrades
	if not upgrades.has("Faster Keyboard"):
		upgrades["Faster Keyboard"] = 0

	pass
"""
Really simple save file implementation. Just saving some variables to a dictionary
"""
func save_game():
	var savefile = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	var save_dict = {}
	save_dict.spawnpoint = spawnpoint
	save_dict.current_level = current_level
	save_dict.money = money
	save_dict.points = points
	save_dict.player_position = {'x': player_position.x, 'y': player_position.y}
	save_dict.inventory = Inventory.list()
	save_dict.quests = Quest.get_quest_list()
	save_dict.mine_accumulation_rates = mine_accumulation_rates # Save mine accumulation rates
	save_dict.upgrades = upgrades # Save upgrade states
	# Save repository progress if available
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_repository_progress"):
		save_dict.repository_progress = current_scene.get_repository_progress()
	if current_scene and current_scene.has_method("get_repository_save_data"):
		save_dict.repositories = current_scene.get_repository_save_data()
	savefile.store_line(JSON.stringify(save_dict))
	savefile.close()
	pass

"""
If check_only is true it will only check for a valid save file and return true or false without
restoring any data
"""
func load_game(check_only = false):
	if not FileAccess.file_exists("user://savegame.save"):
		return false

	var savefile = FileAccess.open("user://savegame.save", FileAccess.READ)

	var test_json_conv = JSON.new()
	test_json_conv.parse(savefile.get_line())
	var save_dict = test_json_conv.get_data()
	if typeof(save_dict) != TYPE_DICTIONARY:
		return false
	if not check_only:
		_restore_data(save_dict)

	savefile.close()
	return true

"""
Restores data from the JSON dictionary inside the save files
"""
func _restore_data(save_dict):
	# JSON numbers are always parsed as floats. In this case we need to turn them into ints
	for key in save_dict.quests:
		save_dict.quests[key] = int(save_dict.quests[key])
	Quest.quest_list = save_dict.quests

	# JSON numbers are always parsed as floats. In this case we need to turn them into ints
	for key in save_dict.inventory:
		save_dict.inventory[key] = int(save_dict.inventory[key])
	Inventory.inventory = save_dict.inventory

	spawnpoint = save_dict.spawnpoint
	current_level = save_dict.current_level
	money = int(save_dict.money)
	if save_dict.has("points"):
		points = int(save_dict.points)
	if save_dict.has("player_position"):
		player_position = Vector2(save_dict.player_position.x, save_dict.player_position.y)

	if save_dict.has("mine_accumulation_rates"):
		mine_accumulation_rates = save_dict.mine_accumulation_rates

	if save_dict.has("upgrades"):
		upgrades = save_dict.upgrades

	# Restore repository progress if available
	if save_dict.has("repository_progress"):
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.has_method("set_repository_progress"):
			current_scene.set_repository_progress(save_dict.repository_progress)
	if save_dict.has("repositories"):
		# Store for later loading after scene change
		pending_repository_data = save_dict.repositories

	pass
