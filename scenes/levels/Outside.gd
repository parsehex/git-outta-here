extends Node

# Repository and Mine Data
var repos_data: Array = []
var lang_colors: Dictionary = {}
var all_languages: Dictionary = {}
var total_languages_needed = 0
var total_languages_gathered = 0
var player_in_fk_upgrade_area = false
var player_in_lf_upgrade_area = false
var _loaded_repo_save_data: Array = [] # Stores loaded repository save data to apply after generation

# Scene references
var repository_scene: PackedScene = preload("res://scenes/misc/Repository.tscn")
var mine_scene: PackedScene = preload("res://scenes/misc/Mine.tscn")

# Node containers
@onready var repositories_container: Node2D = $Spawnpoints/Projects
@onready var complete_repositories_container: Node2D = $Spawnpoints/CompleteProjects
@onready var mines_container: Node2D = $Spawnpoints/LangMines
@onready var points_label: Label = $Spawnpoints/PointsLabel
@onready var fk_upgrade_area: Area2D = $Spawnpoints/Upgrades/FKUpgradeArea
@onready var lf_upgrade_area: Area2D = $Spawnpoints/Upgrades/LFUpgradeArea

func load_data():
	# Load repositories data
	var repos_file = FileAccess.open("res://data/repos.json", FileAccess.READ)
	if repos_file:
		var repos_json = JSON.new()
		repos_json.parse(repos_file.get_as_text())
		repos_data = repos_json.get_data()
		repos_file.close()

		# Sort repositories by 'created_at' in ascending order
		repos_data.sort_custom(func(a, b):
			var date_a = Time.get_datetime_dict_from_datetime_string(a.get("created_at", "1970-01-01T00:00:00Z"), false)
			var date_b = Time.get_datetime_dict_from_datetime_string(b.get("created_at", "1970-01-01T00:00:00Z"), false)
			var timestamp_a = Time.get_unix_time_from_datetime_dict(date_a)
			var timestamp_b = Time.get_unix_time_from_datetime_dict(date_b)
			return timestamp_a < timestamp_b
		)

		# Initialize unlocked_projects if empty, unlock the first 5 projects
		if Globals.unlocked_projects.is_empty() and not repos_data.is_empty():
			for i in range(min(repos_data.size(), 5)):
				Globals.unlocked_projects.append(repos_data[i].get("name", "Unknown"))
			Globals.save_game()

		# Collect all languages from unlocked and completed projects
		all_languages.clear() # Clear previous languages
		for repo in repos_data:
			var repo_name = repo.get("name", "Unknown")
			if repo_name in Globals.unlocked_projects or repo_name in Globals.completed_projects:
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
	var active_count = 0

	# Clear existing repositories
	for child in repositories_container.get_children():
		child.queue_free()
	for child in complete_repositories_container.get_children():
		child.queue_free()

	for repo_dict in repos_data:
		var repo_name = repo_dict.get("name", "Unknown")

		if repo_name in Globals.completed_projects:
			var repo_node = repository_scene.instantiate()
			repo_node.repo_name = repo_name
			repo_node.repo_data = repo_dict
			repo_node.position = Vector2(start_x + Globals.completed_projects.find(repo_name) * spacing, 0)
			repo_node.set_completed(true) # Mark as completed
			complete_repositories_container.add_child(repo_node)
			repo_node.repo_completed.connect(_on_repo_completed)
			# Apply save data if available
			for save_data in _loaded_repo_save_data:
				if save_data.get("name", "") == repo_name and repo_node.has_method("load_save_data"):
					repo_node.load_save_data(save_data)
					break
		elif repo_name in Globals.unlocked_projects and active_count < 5: # Display up to 5 active projects
			var repo_node = repository_scene.instantiate()
			repo_node.repo_name = repo_name
			repo_node.repo_data = repo_dict
			repo_node.position = Vector2(start_x + active_count * spacing, 0)
			repositories_container.add_child(repo_node)
			repo_node.repo_completed.connect(_on_repo_completed)
			# Apply save data if available
			for save_data in _loaded_repo_save_data:
				if save_data.get("name", "") == repo_name and repo_node.has_method("load_save_data"):
					repo_node.load_save_data(save_data)
					break
			active_count += 1

func generate_mines():
	var start_x = 0
	var spacing = 275
	var vertical_spacing = 400

	# Clear existing mines
	for child in mines_container.get_children():
		child.queue_free()

	var lang_index = 0
	for lang in all_languages:
		# No longer limiting for testing, display all relevant languages
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

	# Generate repositories
	generate_repositories()

	# Load repository save data if available
	if Globals.pending_repository_data:
		load_repository_save_data(Globals.pending_repository_data)
		Globals.pending_repository_data = null
		# After loading save data, regenerate repositories and mines to reflect the loaded state
		load_data() # Reload data to update all_languages based on loaded projects
		generate_repositories()
		generate_mines()
	else:
		# If no pending data, generate mines initially
		generate_mines()

	# Connect upgrade buttons
	$Spawnpoints/Upgrades/FasterKeyboardButton.pressed.connect(_on_faster_keyboard_button_pressed)
	$Spawnpoints/Upgrades/LuckyFingersButton.pressed.connect(_on_lucky_fingers_button_pressed)

	# Connect upgrade areas
	if fk_upgrade_area:
		fk_upgrade_area.body_entered.connect(_on_fk_upgrade_area_body_entered)
		fk_upgrade_area.body_exited.connect(_on_fk_upgrade_area_body_exited)
	if lf_upgrade_area:
		lf_upgrade_area.body_entered.connect(_on_lf_upgrade_area_body_entered)
		lf_upgrade_area.body_exited.connect(_on_lf_upgrade_area_body_exited)

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
	_loaded_repo_save_data = data.duplicate() # Store the save data for later application

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

func _on_lucky_fingers_button_pressed():
	var upgrade_name = "Lucky Fingers"
	var current_level = Globals.upgrades[upgrade_name]
	var cost = _get_upgrade_cost(upgrade_name, current_level)

	if Globals.points >= cost and current_level < 25: # Max level 25
		Globals.points -= cost
		Globals.upgrades[upgrade_name] += 1
		Globals.save_game()
		_update_upgrade_info()
		_update_points_display()
		print("Upgraded Lucky Fingers to level " + str(Globals.upgrades[upgrade_name]) + " for " + str(cost) + " points")
	else:
		print("Not enough points or max level reached")
	pass

func _get_upgrade_cost(upgrade_name: String, current_level: int) -> int:
	return int(pow(2, current_level) * 15)

func _on_fk_upgrade_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_fk_upgrade_area = true

func _on_fk_upgrade_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_fk_upgrade_area = false

func _on_lf_upgrade_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_lf_upgrade_area = true

func _on_lf_upgrade_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_lf_upgrade_area = false

func _update_upgrade_info():
	var level = Globals.upgrades["Faster Keyboard"]
	var multiplier = 1.0 + (0.5 * level)
	var cost = _get_upgrade_cost("Faster Keyboard", level)
	var cost_text = "" if level >= 25 else " - Cost: %d" % cost
	$Spawnpoints/Upgrades/FasterKeyboardInfoLabel.text = "Level %d (+%.1fx accumulation)%s" % [level, multiplier, cost_text]

	# Update Lucky Fingers info
	var lucky_level = Globals.upgrades["Lucky Fingers"]
	var lucky_chance = lucky_level * 0.1
	var total_chance = lucky_level * 0.1 + 0.28
	var lucky_cost = _get_upgrade_cost("Lucky Fingers", lucky_level)
	var lucky_cost_text = "" if lucky_level >= 25 else " - Cost: %d" % lucky_cost
	$Spawnpoints/Upgrades/LuckyFingersInfoLabel.text = "Level %d (+%.1f - %.1f%% total chance)%s" % [lucky_level, lucky_chance * 100, total_chance * 100, lucky_cost_text]
	pass

func _update_points_display():
	if points_label:
		points_label.text = "%d" % Globals.points
	pass

func _process(delta):
	_update_points_display()
	_check_upgrade_interaction()

func _on_repo_completed(repo_node: Node):
	print("Repository completed: " + repo_node.repo_name)
	if repo_node.repo_name in Globals.unlocked_projects:
		Globals.unlocked_projects.erase(repo_node.repo_name)
	if not repo_node.repo_name in Globals.completed_projects:
		Globals.completed_projects.append(repo_node.repo_name)

	# Unlock the next project if we have less than 5 active projects
	if Globals.unlocked_projects.size() < 5:
		# Find the next chronological project that's not completed
		for i in range(repos_data.size()):
			var repo_name = repos_data[i].get("name")
			if not repo_name in Globals.unlocked_projects and not repo_name in Globals.completed_projects:
				Globals.unlocked_projects.append(repo_name)
				print("Unlocked next project: " + repo_name)
				break

	Globals.save_game()
	generate_repositories() # Regenerate to update active/completed lists

func _check_upgrade_interaction():
	if player_in_fk_upgrade_area and Input.is_action_just_pressed("interact"):
		$Spawnpoints/Upgrades/FasterKeyboardButton.grab_focus()
		$Spawnpoints/Upgrades/FasterKeyboardButton.emit_signal("pressed")
	if player_in_lf_upgrade_area and Input.is_action_just_pressed("interact"):
		$Spawnpoints/Upgrades/LuckyFingersButton.grab_focus()
		$Spawnpoints/Upgrades/LuckyFingersButton.emit_signal("pressed")
