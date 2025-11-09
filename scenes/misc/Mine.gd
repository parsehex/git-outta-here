extends Area2D

@export var language_name: String = ""
@export var language_color: Color = Color.WHITE
@export var gather_rate: float = 1.0 # bytes per second when holding interact

signal mine_interacted(mine_node: Node)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var range_indicator = $RangeIndicator
@onready var label: Label = $Label
@onready var count_label: Label = $CountLabel

var player_in_range = false
var player_node = null
var gather_progress = 0.0
var gather_duration = 2.0 # seconds to gather some bytes

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if progress_bar:
		progress_bar.visible = false
	if range_indicator:
		range_indicator.visible = false
	if label:
		label.text = language_name
	_update_count_label()
	pass

func _process(delta):
	if player_in_range and player_node and Input.is_action_pressed("interact"):
		gather_progress += (delta / gather_duration) * 100
		gather_progress = clamp(gather_progress, 0, 100)

		if progress_bar:
			progress_bar.value = gather_progress
			progress_bar.visible = true

		if gather_progress >= 100:
			_gather_completed()
			gather_progress = 0.0
			if progress_bar:
				progress_bar.value = 0.0
				progress_bar.visible = false
	else:
		gather_progress = 0.0
		if progress_bar:
			progress_bar.value = 0.0
			progress_bar.visible = false

	_update_count_label()

func _gather_completed():
	var bytes_gathered = 100 # Arbitrary amount
	Inventory.add_item(language_name, bytes_gathered)
	print("Gathered " + str(bytes_gathered) + " bytes of " + language_name)
	_update_count_label()

func _on_body_entered(body):
	if body is Player:
		player_in_range = true
		player_node = body
		if range_indicator:
			range_indicator.visible = true
		print("Player entered mine area for language: " + language_name)

func _on_body_exited(body):
	if body is Player:
		player_in_range = false
		player_node = null
		gather_progress = 0.0
		if progress_bar:
			progress_bar.visible = false
		if range_indicator:
			range_indicator.visible = false
		print("Player exited mine area for language: " + language_name)

func _update_count_label():
	if count_label and language_name != "":
		var current_count = Inventory.get_item(language_name)
		count_label.text = str(current_count) + " bytes"

func interact():
	if language_name != "":
		mine_interacted.emit(self)
		print("Interacting with mine for language: " + language_name)
