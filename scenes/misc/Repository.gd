extends Area2D

@export var repo_name: String = ""
@export var repo_data: Dictionary = {}

signal repo_interacted(repo_node: Node)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var range_indicator = $RangeIndicator
@onready var name_label: Label = $NameLabel
@onready var language_list: VBoxContainer = $LanguageList

var player_in_range = false
var player_node = null
var deposit_progress = 0.0
var deposit_duration = 3.0 # seconds to deposit

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Inventory.item_changed.connect(_on_inventory_changed)

	if progress_bar:
		progress_bar.visible = false
	if range_indicator:
		range_indicator.visible = false
	if name_label:
		name_label.text = repo_name
	_update_language_list()
	pass

func _on_inventory_changed(action, type, amount):
	_update_language_list()


func _get_language_color(lang_name: String) -> Color:
	if Globals.lang_colors.has(lang_name):
		return Globals.lang_colors[lang_name]
	return Color(0, 0, 0, 1) # Black fallback

func _update_language_list():
	if not language_list:
		return

	# Clear existing labels
	for child in language_list.get_children():
		child.queue_free()

	if not repo_data.has("languages"):
		return

	# Sort languages by size (required bytes), descending
	var sorted_languages = repo_data.languages.keys()
	sorted_languages.sort_custom(func(a, b): return repo_data.languages[b] > repo_data.languages[a])

	var labels = []
	for lang in sorted_languages:
		var required = repo_data.languages[lang]
		var current = Inventory.get_item(lang)

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
		rest_label.text = ": " + str(current) + "/" + str(required) + " bytes"
		rest_label.modulate = Color(0, 0, 0, 1)
		hbox.add_child(rest_label)

		labels.append(hbox)

	for label in labels:
		language_list.add_child(label)

func _process(delta):
	if player_in_range and player_node and Input.is_action_pressed("interact"):
		# Check if player has required languages
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
		var current = Inventory.get_item(lang)
		if current < required:
			return false
	return true

func _deposit_completed():
	if not repo_data.has("languages"):
		return

	for lang in repo_data.languages:
		var required = repo_data.languages[lang]
		Inventory.remove_item(lang, required)
		print("Deposited " + str(required) + " bytes of " + lang + " to " + repo_name)

	# Update the language list after deposit
	_update_language_list()

	# Mark this repository as completed (you might want to track this in a separate system)
	print("Repository " + repo_name + " completed!")

func _on_body_entered(body):
	if body is Player:
		player_in_range = true
		player_node = body
		if range_indicator:
			range_indicator.visible = true
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
		print("Player exited repository area: " + repo_name)

func interact():
	if repo_name != "":
		repo_interacted.emit(self)
		print("Interacting with repository: " + repo_name)
