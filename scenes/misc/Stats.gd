extends PanelContainer

var enabled = false

func _ready():
	# not sure why this was here, causes problems with repo
	#   state being overwritten
	# Globals.save_game()
	get_tree().set_auto_accept_quit(false)
	hide()

func _input(event):
	if event.is_action_pressed("pause"):
		enabled = !enabled
		visible = enabled
		get_tree().paused = enabled
		if enabled:
			grab_focus()
			_update_quest_listing()
			_update_item_listing()
			_update_language_listing()
			_update_upgrades_listing()

func _update_quest_listing():
	var text = ""
	# text += "Started:\n"
	# for quest in Quest.list(Quest.STATUS.STARTED):
	# 	text += "  %s\n" % quest
	# text += "Failed:\n"
	# for quest in Quest.list(Quest.STATUS.FAILED):
	# 	text += "  %s\n" % quest

	$VBoxContainer/HBoxContainer/Quests/Details.text = text
	pass

func _update_inventory_details(languages_text: String):
	var text = ""
	var inventory = Inventory.list()
	var non_languages = []
	for item in inventory:
		if not _is_language(item):
			non_languages.append(item)
	if not non_languages.is_empty():
		for item in non_languages:
			text += "  %s x %s\n" % [item, inventory[item]]
	text += "\n" + languages_text
	$VBoxContainer/HBoxContainer/Inventory/Details.text = text

func _update_item_listing():
	var text = "Languages:\n"
	var inventory = Inventory.list()
	var languages = []
	for item in inventory:
		if _is_language(item):
			languages.append(item)
	if languages.is_empty():
		text += "[None]"
	else:
		languages.sort()
		for lang in languages:
			text += "%s: %s\n" % [lang, Globals.format_bytes(inventory[lang])]
	_update_inventory_details(text)
	pass

func _update_language_listing():
	pass # This function is no longer needed as languages are shown in inventory

func _is_language(language_name: String) -> bool:
	# Check if this is one of our tracked languages
	# For now, assume all items that aren't standard inventory are languages
	var standard_items = ["wood", "money"] # Add more as needed
	return not standard_items.has(language_name)
func _update_upgrades_listing():
	var text = ""
	for upgrade in Globals.upgrades:
		var level = Globals.upgrades[upgrade]
		text += "%s: Level %d" % [upgrade, level]
		if upgrade == "Faster Keyboard":
			var multiplier = 1.0 + (0.5 * level)
			text += " (+%.1fx accumulation)" % multiplier
		text += "\n"
	if text == "":
		text = "[None]"
	$VBoxContainer/HBoxContainer/Upgrades/Details.text = text
	pass

func _on_faster_keyboard_button_pressed():
	if Globals.upgrades["Faster Keyboard"] < 5: # Max level 5
		Globals.upgrades["Faster Keyboard"] += 1
		_update_upgrades_listing()
		Globals.save_game()
	pass


func _on_Exit_pressed():
	quit_game()
	pass # Replace with function body.

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game():
	Globals.save_game()
	get_tree().quit()
