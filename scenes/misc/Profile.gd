extends Control

var profile_data: Dictionary = {}

func _ready():
	load_profile_data()
	display_profile()

func load_profile_data():
	var profile_file = "res://data/profile.json"
	if FileAccess.file_exists(profile_file):
		var file = FileAccess.open(profile_file, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			profile_data = json.get_data()
		else:
			push_error("Failed to parse profile.json: " + str(error))
	else:
		push_error("Profile file not found: " + profile_file)

func display_profile():
	if profile_data.is_empty():
		return

	# Assuming scene has these nodes
	var avatar_node = $VBoxContainer/HBoxContainer/Avatar
	var username_node = $VBoxContainer/HBoxContainer/Username
	var github_button = $VBoxContainer/HBoxContainer/GitHubButton
	var blog_button = $VBoxContainer/HBoxContainer/BlogButton
	var bio_node = $VBoxContainer/Bio

	# Set avatar texture (assuming avatar.png is in textures/)
	var avatar_texture = load("res://textures/avatar.png")
	if avatar_texture:
		avatar_node.texture = avatar_texture

	# Set username
	if profile_data.has("login"):
		username_node.text = profile_data["login"]

	# Connect GitHub button
	if github_button and profile_data.has("html_url"):
		github_button.pressed.connect(_on_github_button_pressed)

	# Connect and show/hide blog button
	if blog_button:
		if profile_data.has("blog") and profile_data["blog"] != null and profile_data["blog"] != "":
			blog_button.pressed.connect(_on_blog_button_pressed)
			blog_button.visible = true
		else:
			blog_button.visible = false

	# Set bio
	if profile_data.has("bio") and profile_data["bio"] != null:
		bio_node.text = profile_data["bio"]
	else:
		bio_node.text = "No bio available"

func _on_github_button_pressed():
	if profile_data.has("html_url"):
		OS.shell_open(profile_data.html_url)
		print("Opening GitHub profile: " + profile_data.html_url)

func _on_blog_button_pressed():
	if profile_data.has("blog") and profile_data["blog"] != null and profile_data["blog"] != "":
		OS.shell_open(profile_data.blog)
		print("Opening blog: " + profile_data.blog)
