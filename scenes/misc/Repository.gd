extends Area2D

@export var repo_name: String = ""
@export var repo_data: Dictionary = {}

signal repo_interacted(repo_node: Node)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var range_indicator = $RangeIndicator
@onready var name_label: Label = $NameLabel

var player_in_range = false
var player_node = null
var deposit_progress = 0.0
var deposit_duration = 3.0 # seconds to deposit

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if progress_bar:
		progress_bar.visible = false
	if range_indicator:
		range_indicator.visible = false
	if name_label:
		name_label.text = repo_name
	pass

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
