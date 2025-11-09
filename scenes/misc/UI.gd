extends CanvasLayer

@onready var progress_label = $ProgressLabel
@onready var language_list = $LanguageList

var total_languages_needed = 0
var total_languages_gathered = 0

func _ready():
	Inventory.item_changed.connect(_on_inventory_changed)
	_update_progress_display()

func _update_progress_display():
	if progress_label:
		var percentage = 0.0
		if total_languages_needed > 0:
			percentage = (total_languages_gathered / float(total_languages_needed)) * 100.0
		progress_label.text = "Progress: %.1f%%" % percentage

func _on_inventory_changed(action, type, amount):
	# Update language tracking if it's a language item
	if _is_language(type):
		_update_progress_display()

func _is_language(language_name: String) -> bool:
	# Check if this is one of our tracked languages
	# For now, assume all items that aren't standard inventory are languages
	var standard_items = ["wood", "money"] # Add more as needed
	return not standard_items.has(language_name)

func update_total_progress(needed: int, gathered: int):
	total_languages_needed = needed
	total_languages_gathered = gathered
	_update_progress_display()
