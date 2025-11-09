extends StaticBody2D

@onready var detection_area = $DetectionArea
@onready var shadow_area = $ShadowArea
@onready var chop_progress_bar = $ChopProgressBar
@onready var range_indicator = $RangeIndicator

var player_in_range = false
var player_in_range_shadow = false
var player_node = null
var chop_progress = 0.0
var chop_duration = 2.0 # seconds

func _ready():
	shadow_area.body_entered.connect(_on_ShadowArea_body_entered)
	shadow_area.body_exited.connect(_on_ShadowArea_body_exited)
	detection_area.body_entered.connect(_on_DetectionArea_body_entered)
	detection_area.body_exited.connect(_on_DetectionArea_body_exited)
	self.y_sort_enabled = true

func _process(delta):
	if player_node:
		if player_node.global_position.y < global_position.y + 75:
			z_index = 1 # Player above, tree in front
		else:
			z_index = -1 # Player below, tree behind

	if player_in_range_shadow:
		modulate.a = 0.75
	else:
		modulate.a = 1.0

	if player_in_range and player_node:
		if Input.is_action_pressed("interact"):
			chop_progress += (delta / chop_duration) * 100
			chop_progress = clamp(chop_progress, 0, 100)
			chop_progress_bar.value = chop_progress
			chop_progress_bar.visible = true

			if chop_progress >= 100:
				_chop_completed()
				chop_progress = 0.0
				chop_progress_bar.value = 0.0
				chop_progress_bar.visible = false
		else:
			chop_progress = 0.0
			chop_progress_bar.value = 0.0
			chop_progress_bar.visible = false
	else:
		chop_progress = 0.0
		chop_progress_bar.value = 0.0
		chop_progress_bar.visible = false

func _on_ShadowArea_body_entered(body):
	if body.is_in_group("player"):
		player_in_range_shadow = true
		z_index = 1

func _on_ShadowArea_body_exited(body):
	if body.is_in_group("player"):
		player_in_range_shadow = false

func _on_DetectionArea_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_node = body
		range_indicator.visible = true
		# range_indicator.modulate = Color(1, 1, 1, 0.5) # Semi-transparent white

func _on_DetectionArea_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		player_node = null
		chop_progress_bar.visible = false
		range_indicator.visible = false

func _chop_completed():
	Inventory.add_item('wood', 1)
	queue_free()
