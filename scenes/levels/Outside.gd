extends Node

# Repository and Mine Data
var repos_data: Array = []
var lang_colors: Dictionary = {}
var all_languages: Dictionary = {}
var total_languages_needed = 0
var total_languages_gathered = 0
var player_in_upgrade_area = false

# Scene references
var repository_scene: PackedScene = preload("res://scenes/misc/Repository.tscn")
var mine_scene: PackedScene = preload("res://scenes/misc/Mine.tscn")

# Node containers
@onready var repositories_container: Node2D = $Spawnpoints/Projects
@onready var mines_container: Node2D = $Spawnpoints/LangMines
@onready var points_label: Label = $Spawnpoints/PointsLabel
@onready var upgrade_area: Area2D = $Spawnpoints/Upgrades/UpgradeArea

func load_data():
	# Load repositories data
	var repos_file = FileAccess.open("res://data/repos.json", FileAccess.READ)
	if repos_file:
		var repos_json = JSON.new()
		repos_json.parse(repos_file.get_as_text())
		repos_data = repos_json.get_data()
		repos_file.close()

		# Collect all languages
		for repo in repos_data:
			if repo.has("languages"):
				for lang in repo.languages:
					if not all_languages.has(lang):
						all_languages[lang] = 0
					all_languages[lang] += repo.languages[lang]

	# Load language colors from globals
	lang_colors = Globals.lang_colors

func generate_repositories():
	var start_x = 0
	var spacing = 550

	for i in range(min(repos_data.size(), 10)): # Limit for testing
		var repo = repos_data[i]
		var repo_node = repository_scene.instantiate()

		repo_node.repo_name = repo.get("name", "Unknown")
		repo_node.repo_data = repo
		repo_node.position = Vector2(start_x + i * spacing, 0)

		repositories_container.add_child(repo_node)

func generate_mines():
	var start_x = 0
	var spacing = 275
	var vertical_spacing = 400

	var lang_index = 0
	for lang in all_languages:
		if lang_index >= 20: # Limit for testing
			break

		var mine_node = mine_scene.instantiate()

		mine_node.language_name = lang
		if lang_colors.has(lang):
			var color = lang_colors[lang]
			mine_node.language_color = Color(color)

		var row = lang_index / 7
		var col = lang_index % 7
		mine_node.position = Vector2(start_x + col * spacing, 0 + row * vertical_spacing)

		mines_container.add_child(mine_node)
		lang_index += 1

func _ready():
	# Load data
	load_data()

	# Generate repositories and mines
	generate_repositories()
	generate_mines()

	# Load repository save data if available
	if Globals.pending_repository_data:
		load_repository_save_data(Globals.pending_repository_data)
		Globals.pending_repository_data = null

	# Connect upgrade button
	$Spawnpoints/Upgrades/FasterKeyboardButton.pressed.connect(_on_faster_keyboard_button_pressed)

	# Connect upgrade area
	if upgrade_area:
		upgrade_area.body_entered.connect(_on_upgrade_area_body_entered)
		upgrade_area.body_exited.connect(_on_upgrade_area_body_exited)

	# Calculate total progress
	_calculate_total_progress()
	_update_upgrade_info()
	_update_points_display()

func _calculate_total_progress():
	total_languages_needed = 0
	total_languages_gathered = 0

	# Count all language requirements across all repos
	for repo in repos_data:
		if repo.has("languages"):
			for lang in repo.languages:
				total_languages_needed += repo.languages[lang]

	# Count all gathered languages in inventory
	for lang in all_languages:
		total_languages_gathered += Inventory.get_item(lang)

	# Update UI
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("update_total_progress"):
		ui.update_total_progress(total_languages_needed, total_languages_gathered)

func get_repository_progress() -> Dictionary:
	var progress = {}
	if not repositories_container:
		return progress
	for repo_node in repositories_container.get_children():
		if repo_node is Area2D and repo_node.has_method("_deposit_completed"):
			# For now, we'll track if repository is completed
			# In a full implementation, you'd want to track completion state
			progress[repo_node.repo_name] = false # Placeholder
	return progress

func get_repository_save_data() -> Array:
	var save_data = []
	if not repositories_container:
		return save_data
	for repo_node in repositories_container.get_children():
		if repo_node.has_method("get_save_data"):
			save_data.append(repo_node.get_save_data())
	return save_data

func load_repository_save_data(data: Array):
	if not repositories_container:
		return
	for repo_data in data:
		var repo_name = repo_data.get("name", "")
		for repo_node in repositories_container.get_children():
			if repo_node.repo_name == repo_name and repo_node.has_method("load_save_data"):
				repo_node.load_save_data(repo_data)
				break

func set_repository_progress(progress: Dictionary):
	# Restore repository progress
	for repo_name in progress:
		for repo_node in repositories_container.get_children():
			if repo_node.repo_name == repo_name:
				# Set completion state if needed
				pass

func _on_faster_keyboard_button_pressed():
	var upgrade_name = "Faster Keyboard"
	var current_level = Globals.upgrades[upgrade_name]
	var cost = _get_upgrade_cost(upgrade_name, current_level)

	if Globals.points >= cost and current_level < 25: # Max level 25
		Globals.points -= cost
		Globals.upgrades[upgrade_name] += 1
		Globals.save_game()
		_update_upgrade_info()
		_update_points_display()
		print("Upgraded Faster Keyboard to level " + str(Globals.upgrades[upgrade_name]) + " for " + str(cost) + " points")
	else:
		print("Not enough points or max level reached")
	pass

func _get_upgrade_cost(upgrade_name: String, current_level: int) -> int:
	return int(pow(2, current_level) * 15)

func _on_upgrade_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_upgrade_area = true

func _on_upgrade_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_upgrade_area = false

func _update_upgrade_info():
	var level = Globals.upgrades["Faster Keyboard"]
	var multiplier = 1.0 + (0.5 * level)
	var cost = _get_upgrade_cost("Faster Keyboard", level)
	var cost_text = "" if level >= 25 else " - Cost: %d" % cost
	$Spawnpoints/Upgrades/UpgradeInfoLabel.text = "Level %d (+%.1fx accumulation)%s" % [level, multiplier, cost_text]
	pass

func _update_points_display():
	if points_label:
		points_label.text = "%d" % Globals.points
	pass

func _process(delta):
	_update_points_display()
	_check_upgrade_interaction()

func _check_upgrade_interaction():
	if player_in_upgrade_area and Input.is_action_just_pressed("interact"):
		$Spawnpoints/Upgrades/FasterKeyboardButton.grab_focus()
		$Spawnpoints/Upgrades/FasterKeyboardButton.emit_signal("pressed")
