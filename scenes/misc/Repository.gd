extends Area2D

# Repository, aka Project

@export var repo_name: String = ""
@export var repo_data: Dictionary = {}
var completed: bool = false

signal repo_interacted(repo_node: Node)
signal repo_completed(repo_node: Node)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var range_indicator = $RangeIndicator
@onready var label_container: VBoxContainer = $LabelContainer
@onready var name_label: Label = $LabelContainer/NameLabel
@onready var description_label: Label = $LabelContainer/DescriptionLabel
@onready var language_list: VBoxContainer = $LanguageList
@onready var github_button: Button = $GitHubButton
@onready var link_button: Button = $LinkButton
@onready var tooltip: Label = $Tooltip
@onready var points_label: Label = $PointsLabel
@onready var year_label: Label = $YearLabel

var player_in_range = false
var player_node = null
var deposited = {}
var deposit_progress = 0.0
var deposit_duration = 0.75 # seconds to deposit
var last_points_time = 0.0
var points_rate = 1.5 # points per second based on filled percentage

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Inventory.item_changed.connect(_on_inventory_changed)

	if progress_bar:
		progress_bar.visible = false
	if range_indicator:
		range_indicator.visible = false
	if tooltip:
		tooltip.visible = false
	if name_label:
		name_label.text = repo_name
	if github_button:
		github_button.pressed.connect(_on_github_button_pressed)
	if link_button and repo_data.has("homepage"):
		link_button.pressed.connect(_on_link_button_pressed)
	else:
		link_button.visible = false

	# Initialize deposited amounts
	for lang in repo_data.languages:
		deposited[lang] = 0

	_update_language_list()
	_update_labels()
	set_completed(completed) # Apply completed state after setup
	pass

func _update_labels():
	if name_label:
		name_label.text = repo_name

	# Set description if available
	if description_label and repo_data.has("description") and repo_data.description != null:
		description_label.text = repo_data.description
		description_label.visible = true
	else:
		description_label.visible = false

	if year_label and repo_data.has("created_at"):
		var created_at = repo_data.created_at
		var year = created_at.substr(0, 4)
		year_label.text = year
		year_label.visible = true
	else:
		year_label.visible = false

	# Position points label below the label container
	call_deferred("_update_points_position")

func _on_inventory_changed(action, type, amount, skip_ui):
	_update_language_list()


func _get_language_color(lang_name: String) -> Color:
	if Globals.lang_colors.has(lang_name):
		return Globals.lang_colors[lang_name]
	return Color(0, 0, 0, 1) # Black fallback

func _update_language_list():
	if not language_list:
		return

	if completed:
		language_list.visible = false

	# Clear existing labels
	for child in language_list.get_children():
		child.queue_free()

	if not repo_data.has("languages"):
		return

	# Sort languages by size (required bytes), descending
	var sorted_languages = repo_data.languages.keys()
	sorted_languages.sort_custom(func(a, b): return repo_data.languages[b] < repo_data.languages[a])

	var labels = []
	for lang in sorted_languages:
		var required = repo_data.languages[lang]
		var current = deposited.get(lang, 0)

		# Create HBoxContainer for this language entry
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

		# Colored language name label
		var lang_label = Label.new()
		lang_label.text = lang
		var lang_color = _get_language_color(lang)
		lang_label.modulate = lang_color
		hbox.add_child(lang_label)

		# Black rest of the text label
		var rest_label = Label.new()
		rest_label.text = ": " + Globals.format_bytes(current) + "/" + Globals.format_bytes(required)
		rest_label.modulate = Color(0, 0, 0, 1)
		hbox.add_child(rest_label)

		labels.append(hbox)

	for label in labels:
		language_list.add_child(label)

	# Update points position after language list is updated
	call_deferred("_update_points_position")

func _update_points_position():
	pass

func _process(delta):
	# Generate points based on completion percentage
	_generate_points(delta)

	if player_in_range and player_node and Input.is_action_pressed("interact"):
		# Check if player has any languages to deposit
		if _has_required_languages():
			deposit_progress += (delta / deposit_duration) * 100
			deposit_progress = clamp(deposit_progress, 0, 100)

			if progress_bar:
				progress_bar.value = deposit_progress
				progress_bar.visible = true

			if deposit_progress >= 100:
				_deposit_completed()
				deposit_progress = 0.0
				if progress_bar:
					progress_bar.value = 0.0
					progress_bar.visible = false
		else:
			# Show some indication that requirements aren't met
			if progress_bar:
				progress_bar.visible = false
	else:
		deposit_progress = 0.0
		if progress_bar:
			progress_bar.value = 0.0
			progress_bar.visible = false

func _has_required_languages() -> bool:
	if not repo_data.has("languages"):
		return false

	for lang in repo_data.languages:
		var required = repo_data.languages[lang]
		if required == deposited[lang]:
			continue
		var available = Inventory.get_item(lang)
		if available > 0:
			return true
	return false

func _generate_points(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	if last_points_time == 0.0:
		last_points_time = current_time
		return

	var time_passed = current_time - last_points_time
	last_points_time = current_time

	# Calculate completion percentage
	var total_required = 0
	var total_deposited = 0
	for lang in repo_data.languages:
		total_required += repo_data.languages[lang]
		total_deposited += deposited[lang]

	if total_required > 0:
		var completion_ratio = float(total_deposited) / float(total_required)
		# Scale points rate based on repository size (total bytes required)
		# Larger repos generate more points: base_rate * sqrt(total_bytes / 1000) * completion_ratio
		var size_multiplier = sqrt(total_required / 1000.0)
		var adjusted_rate = points_rate * size_multiplier
		var points_earned = adjusted_rate * completion_ratio * time_passed
		Globals.points += points_earned

		# Update points generation display
		if points_label:
			var points_per_second = adjusted_rate * completion_ratio
			if points_per_second > 0.001: # Only show if generating meaningful points
				points_label.text = "+%.2f/s" % points_per_second
				points_label.visible = true
			else:
				points_label.visible = false

func _deposit_completed():
	if not repo_data.has("languages"):
		return

	for lang in repo_data.languages:
		var required = repo_data.languages[lang]
		var available = Inventory.get_item(lang)
		var to_deposit = min(required - deposited[lang], available)
		if to_deposit > 0:
			deposited[lang] += to_deposit
			Inventory.remove_item(lang, to_deposit)
			print("Deposited " + str(to_deposit) + " bytes of " + lang + " to " + repo_name)

	# Update the language list after deposit
	_update_language_list()

	# Check if repository is completed
	var completed = true
	for lang in repo_data.languages:
		if deposited[lang] < repo_data.languages[lang]:
			completed = false
			break

	if completed:
		repo_completed.emit(self)
		# Award points based on total bytes required for this repository
		var total_bytes = 0
		for lang in repo_data.languages:
			total_bytes += repo_data.languages[lang]
		var points_earned = int(total_bytes / 1000) + 1 # 1 point per 1000 bytes, minimum 1 point
		Globals.points += points_earned
		print("Repository " + repo_name + " completed! Earned " + str(points_earned) + " points.")

	if range_indicator:
		range_indicator.visible = false
	if tooltip:
		tooltip.visible = false

func _on_body_entered(body):
	if body is Player:
		player_in_range = true
		player_node = body
		if range_indicator:
			# Check if repository is already completed
			var completed = true
			for lang in repo_data.languages:
				if deposited[lang] < repo_data.languages[lang]:
					completed = false
					break
			if not completed and _has_required_languages():
				range_indicator.visible = true
				if tooltip:
					tooltip.visible = true
		print("Player entered repository area: " + repo_name)

func _on_body_exited(body):
	if body is Player:
		player_in_range = false
		player_node = null
		deposit_progress = 0.0
		if progress_bar:
			progress_bar.visible = false
		if range_indicator:
			range_indicator.visible = false
		if tooltip:
			tooltip.visible = false
		print("Player exited repository area: " + repo_name)

func interact():
	if repo_name != "":
		repo_interacted.emit(self)
		print("Interacting with repository: " + repo_name)

func get_save_data() -> Dictionary:
	return {
		"name": repo_name,
		"deposited": deposited.duplicate(),
		"completed": completed
	}

func load_save_data(data: Dictionary):
	deposited = data.get("deposited", {})
	completed = data.get("completed", false)
	_update_language_list()
	set_completed(completed)

func set_completed(is_completed: bool):
	completed = is_completed
	if completed:
		# Hide progress bar, range indicator, tooltip when completed
		if progress_bar:
			progress_bar.visible = false
		if range_indicator:
			range_indicator.visible = false
		if tooltip:
			tooltip.visible = false
	else:
		if language_list:
			language_list.visible = true

func _on_github_button_pressed():
	if repo_data.has("html_url"):
		OS.shell_open(repo_data.html_url)
		print("Opening GitHub URL: " + repo_data.html_url)

func _on_link_button_pressed():
	if repo_data.has("homepage") and repo_data.homepage != null and repo_data.homepage != "":
		OS.shell_open(repo_data.homepage)
		print("Opening homepage URL: " + repo_data.homepage)
	else:
		print("No homepage URL available for this repository")
