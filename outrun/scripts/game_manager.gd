extends Node

# UI References (to be added later)
var speed_label: Label
var debug_label: Label

# Game state
var game_time = 0.0
var distance_traveled = 0.0

func _ready():
	# Set up basic UI
	create_ui()
	
	# Configure project settings for pixel-perfect rendering
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	
	print("Outrun-style Racing Game Started!")
	print("Controls: Arrow Keys - Up/Down for accel/brake, Left/Right to steer")

func _process(delta):
	game_time += delta
	
	# Update UI
	if speed_label:
		var player = get_node_or_null("PlayerCar")
		if player:
			var speed_kmh = int(player.speed * 1.2)  # Convert to km/h for display
			speed_label.text = "Speed: %d km/h" % speed_kmh
			
			# Update debug info
			if debug_label:
				debug_label.text = "Pos X: %.2f | Off-road: %s" % [player.position_x, player.is_offroad]

func create_ui():
	# Create Canvas Layer for UI
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Speed display
	speed_label = Label.new()
	speed_label.position = Vector2(20, 20)
	speed_label.add_theme_font_size_override("font_size", 24)
	speed_label.text = "Speed: 0 km/h"
	canvas_layer.add_child(speed_label)
	
	# Debug info
	debug_label = Label.new()
	debug_label.position = Vector2(20, 60)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.text = "Debug info"
	canvas_layer.add_child(debug_label)
	
	# Instructions
	var instructions = Label.new()
	instructions.position = Vector2(20, 100)
	instructions.text = "Arrow Keys: Up/Down = Accel/Brake, Left/Right = Steer"
	canvas_layer.add_child(instructions)
