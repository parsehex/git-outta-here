extends Node

# Repository and Mine Data
var repos_data: Array = []
var lang_colors: Dictionary = {}
var all_languages: Dictionary = {}
var total_languages_needed = 0
var total_languages_gathered = 0

# Scene references
var repository_scene: PackedScene = preload("res://scenes/misc/Repository.tscn")
var mine_scene: PackedScene = preload("res://scenes/misc/Mine.tscn")

# Node containers
@onready var repositories_container: Node2D = Node2D.new()
@onready var mines_container: Node2D = Node2D.new()

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

	# Load language colors
	var colors_file = FileAccess.open("res://data/lang-colors.json", FileAccess.READ)
	if colors_file:
		var colors_json = JSON.new()
		colors_json.parse(colors_file.get_as_text())
		lang_colors = colors_json.get_data()
		colors_file.close()

func generate_repositories():
	var start_x = -500
	var spacing = 350

	for i in range(min(repos_data.size(), 10)): # Limit for testing
		var repo = repos_data[i]
		var repo_node = repository_scene.instantiate()

		repo_node.repo_name = repo.get("name", "Unknown")
		repo_node.repo_data = repo
		repo_node.position = Vector2(start_x + i * spacing, 500)

		repositories_container.add_child(repo_node)

func generate_mines():
	var start_x = -500
	var spacing = 275

	var lang_index = 0
	for lang in all_languages:
		if lang_index >= 20: # Limit for testing
			break

		var mine_node = mine_scene.instantiate()

		mine_node.language_name = lang
		if lang_colors.has(lang):
			var color_str = lang_colors[lang].get("color", "#FFFFFF")
			mine_node.language_color = Color(color_str)

		mine_node.position = Vector2(start_x + lang_index * spacing, 1500)

		mines_container.add_child(mine_node)
		lang_index += 1

func _ready():
	# Load data
	load_data()

	# Create containers
	add_child(repositories_container)
	repositories_container.name = "Repositories"
	add_child(mines_container)
	mines_container.name = "Mines"

	# Generate repositories and mines
	generate_repositories()
	generate_mines()

	# Calculate total progress
	_calculate_total_progress()

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

func set_repository_progress(progress: Dictionary):
	# Restore repository progress
	for repo_name in progress:
		for repo_node in repositories_container.get_children():
			if repo_node.repo_name == repo_name:
				# Set completion state if needed
				pass
