extends Area2D

@export var language_name: String = ""
@export var language_color: Color = Color.WHITE
@export var mine_amount = 500 # TODO: dev value
@export var accumulation_rate_increase_per_gather: float = 0.06 # How much the rate increases per gather
@export var accumulation_rate_chance: float = 0.28 # Chance for accumulation rate to increase (0.0 to 1.0)

signal mine_interacted(mine_node: Node)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var count_label: Label = $CountLabel
@onready var accumulation_rate_label: Label = $AccumulationRateLabel

var player_in_range = false
var player_node = null
var gather_progress = 0.0
var gather_duration = 0.75 # seconds to gather some bytes, TODO: dev value
var current_accumulation_rate: float = 0.0
var accumulated_bytes: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if progress_bar:
		progress_bar.visible = false
	if label:
		label.text = language_name
	$Body.color = language_color

	# Initialize accumulation rate from Globals or set to base
	if Globals.mine_accumulation_rates.has(language_name):
		current_accumulation_rate = Globals.mine_accumulation_rates[language_name]
	else:
		current_accumulation_rate = 0.0
		Globals.mine_accumulation_rates[language_name] = current_accumulation_rate

	_update_labels()
	pass

func _process(delta):
	# Passive accumulation
	if current_accumulation_rate > 0:
		accumulated_bytes += current_accumulation_rate * delta
		if accumulated_bytes >= 1.0: # Add to inventory once a full byte is accumulated
			var whole_bytes = floor(accumulated_bytes)
			Inventory.add_item(language_name, whole_bytes, true)
			accumulated_bytes -= whole_bytes
			_update_labels()

	if player_in_range and player_node:
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

	_update_labels()

func _gather_completed():
	var bytes_gathered = mine_amount
	Inventory.add_item(language_name, bytes_gathered)
	print("Gathered " + str(bytes_gathered) + " bytes of " + language_name)

	# Increase accumulation rate with a random chance
	var effective_chance = accumulation_rate_chance
	if Globals.upgrades.has("Lucky Fingers"):
		effective_chance += Globals.upgrades["Lucky Fingers"] * 0.07 # +7% chance per level
	effective_chance = min(effective_chance, 0.85) # Cap at 85%

	if randf() < effective_chance:
		var increase = accumulation_rate_increase_per_gather
		if Globals.upgrades.has("Faster Keyboard"):
			increase *= (1.0 + (0.5 * Globals.upgrades["Faster Keyboard"]))
		current_accumulation_rate += increase
		Globals.mine_accumulation_rates[language_name] = current_accumulation_rate
		print("Accumulation rate for " + language_name + " increased to: " + str(current_accumulation_rate))

	_update_labels()

func _on_body_entered(body):
	if body is Player:
		player_in_range = true
		player_node = body
		print("Player entered mine area for language: " + language_name)

func _on_body_exited(body):
	if body is Player:
		player_in_range = false
		player_node = null
		if progress_bar:
			progress_bar.visible = false
		print("Player exited mine area for language: " + language_name)

func _update_labels():
	if count_label and language_name != "":
		var current_count = Inventory.get_item(language_name)
		count_label.text = Globals.format_bytes(current_count)

	if accumulation_rate_label and language_name != "" and current_accumulation_rate > 0:
		accumulation_rate_label.text = "Rate: " + "%.2f" % current_accumulation_rate + " b/s"

func interact():
	if language_name != "":
		mine_interacted.emit(self)
		print("Interacting with mine for language: " + language_name)
