extends Node2D
# Attach this script to a Node2D as your main scene root
# This combines everything into one script for easier debugging

# Road rendering constants
const ROAD_WIDTH = 2000
const SEGMENT_LENGTH = 200
const RUMBLE_LENGTH = 3
const LANES = 3
const CAMERA_HEIGHT = 1000
const CAMERA_DEPTH = 0.84
const DRAW_DISTANCE = 300
const ROAD_COLOR = Color(0.4, 0.4, 0.4)
const RUMBLE_COLOR_1 = Color(1, 1, 1)
const RUMBLE_COLOR_2 = Color(1, 0, 0)
const GRASS_COLOR_1 = Color(0, 0.6, 0)
const GRASS_COLOR_2 = Color(0, 0.5, 0)
const LANE_COLOR = Color(1, 1, 1, 0.4)

# Player constants
const MAX_SPEED = 300.0
const ACCELERATION = 100.0
const BRAKING = 200.0
const TURN_SPEED = 2.0
const OFFROAD_DECEL = 200.0
const OFFROAD_MAX_SPEED = MAX_SPEED / 2

# Game state
var camera_z = 0.0
var player_x = 0.0
var speed = 0.0
var is_offroad = false
var segments = []

# UI elements
var speed_label: Label
var debug_label: Label
var player_sprite: Sprite2D

class Segment:
	var index: int
	var p1: Dictionary
	var p2: Dictionary
	var curve: float = 0.0
	var color: Color
	
	func project(camera_x: float, camera_y: float, camera_z: float, camera_depth: float, width: float, height: float) -> Dictionary:
		var p1_screen = _project_point(p1, camera_x, camera_y, camera_z, camera_depth, width, height)
		var p2_screen = _project_point(p2, camera_x, camera_y, camera_z, camera_depth, width, height)
		return {
			"x1": p1_screen.x,
			"y1": p1_screen.y,
			"w1": p1_screen.w,
			"x2": p2_screen.x,
			"y2": p2_screen.y,
			"w2": p2_screen.w
		}
	
	func _project_point(p: Dictionary, cam_x: float, cam_y: float, cam_z: float, cam_depth: float, width: float, height: float) -> Dictionary:
		var scale = cam_depth / (p.z - cam_z)
		var x = (1 + scale * (p.x - cam_x)) * width / 2
		var y = (1 - scale * (p.y - cam_y)) * height / 2
		var w = scale * ROAD_WIDTH * width / 2
		return {"x": x, "y": y, "w": w}

func _ready():
	print("Outrun Racing Game - All-in-One Version")
	
	# Initialize road segments
	for i in range(500):
		var seg = Segment.new()
		seg.index = i
		seg.p1 = {"x": 0, "y": 0, "z": i * SEGMENT_LENGTH}
		seg.p2 = {"x": 0, "y": 0, "z": (i + 1) * SEGMENT_LENGTH}
		seg.color = ROAD_COLOR if (i / RUMBLE_LENGTH) % 2 else ROAD_COLOR.darkened(0.1)
		segments.append(seg)
	
	# Create UI
	create_ui()
	
	# Create player car sprite
	create_player_sprite()

func create_ui():
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	speed_label = Label.new()
	speed_label.position = Vector2(20, 20)
	speed_label.add_theme_font_size_override("font_size", 24)
	speed_label.text = "Speed: 0 km/h"
	canvas_layer.add_child(speed_label)
	
	debug_label = Label.new()
	debug_label.position = Vector2(20, 60)
	debug_label.add_theme_font_size_override("font_size", 16)
	canvas_layer.add_child(debug_label)
	
	var instructions = Label.new()
	instructions.position = Vector2(20, 100)
	instructions.text = "Arrow Keys: Up/Down = Accel/Brake, Left/Right = Steer"
	canvas_layer.add_child(instructions)

func create_player_sprite():
	player_sprite = Sprite2D.new()
	add_child(player_sprite)
	
	# Create red car texture
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(1, 0, 0))
	var texture = ImageTexture.create_from_image(image)
	player_sprite.texture = texture
	
	var viewport_size = get_viewport_rect().size
	player_sprite.position = Vector2(viewport_size.x / 2, viewport_size.y - 100)

func _process(delta):
	handle_input(delta)
	update_camera(delta)
	update_player_position()
	update_ui()
	queue_redraw()  # Force redraw every frame

func handle_input(delta):
	# Acceleration and braking
	if Input.is_action_pressed("ui_up"):
		if is_offroad and speed > OFFROAD_MAX_SPEED:
			speed -= OFFROAD_DECEL * delta
		else:
			speed += ACCELERATION * delta
	elif Input.is_action_pressed("ui_down"):
		speed -= BRAKING * delta
	else:
		speed -= 50.0 * delta
	
	if is_offroad:
		speed -= OFFROAD_DECEL * delta
		speed = min(speed, OFFROAD_MAX_SPEED)
	
	speed = clamp(speed, 0, MAX_SPEED)
	
	# Steering
	var steer_input = 0.0
	if Input.is_action_pressed("ui_left"):
		steer_input = -1.0
	elif Input.is_action_pressed("ui_right"):
		steer_input = 1.0
	
	var speed_factor = speed / MAX_SPEED
	player_x += steer_input * TURN_SPEED * speed_factor * delta
	player_x = clamp(player_x, -2.0, 2.0)
	
	is_offroad = abs(player_x) > 1.0

func update_camera(delta):
	camera_z += speed * delta

func update_player_position():
	var viewport_size = get_viewport_rect().size
	var road_center = viewport_size.x / 2
	var screen_x = road_center + (player_x * viewport_size.x * 0.4)
	player_sprite.position.x = screen_x
	player_sprite.rotation = player_x * 0.1

func update_ui():
	var speed_kmh = int(speed * 1.2)
	speed_label.text = "Speed: %d km/h" % speed_kmh
	debug_label.text = "Pos X: %.2f | Off-road: %s | Camera Z: %.0f" % [player_x, is_offroad, camera_z]

func _draw():
	var viewport_size = get_viewport_rect().size
	var width = viewport_size.x
	var height = viewport_size.y
	
	# Draw sky and ground
	draw_rect(Rect2(0, 0, width, height/2), Color(0.5, 0.7, 1.0))
	draw_rect(Rect2(0, height/2, width, height/2), GRASS_COLOR_1)
	
	# Draw road
	var base_segment = int(camera_z / SEGMENT_LENGTH)
	var base_percent = fmod(camera_z, SEGMENT_LENGTH) / SEGMENT_LENGTH
	var camera_x = player_x * ROAD_WIDTH
	var camera_y = CAMERA_HEIGHT
	
	var max_y = height
	var x = 0.0
	var dx = 0.0
	
	for n in range(DRAW_DISTANCE, 0, -1):
		var seg_index = (base_segment + n) % segments.size()
		var segment = segments[seg_index]
		
		segment.p1.x = x
		segment.p2.x = x + dx
		x += dx
		dx += segment.curve
		
		var p = segment.project(camera_x - x, camera_y, camera_z - base_percent * SEGMENT_LENGTH, 
								CAMERA_DEPTH, width, height)
		
		if p.y2 >= p.y1 or p.y1 >= max_y:
			continue
		
		# Draw grass
		var grass_color = GRASS_COLOR_1 if (seg_index / RUMBLE_LENGTH) % 2 else GRASS_COLOR_2
		draw_rect(Rect2(0, p.y2, width, p.y1 - p.y2), grass_color)
		
		# Draw rumble strips
		if (seg_index / RUMBLE_LENGTH) % 2:
			var rumble_w1 = p.w1 * 1.2
			var rumble_w2 = p.w2 * 1.2
			_draw_polygon(p.x1 - rumble_w1, p.y1, p.x1 - p.w1, p.y1,
						  p.x2 - p.w2, p.y2, p.x2 - rumble_w2, p.y2, RUMBLE_COLOR_1)
			_draw_polygon(p.x1 + p.w1, p.y1, p.x1 + rumble_w1, p.y1,
						  p.x2 + rumble_w2, p.y2, p.x2 + p.w2, p.y2, RUMBLE_COLOR_1)
		
		# Draw road
		_draw_polygon(p.x1 - p.w1, p.y1, p.x1 + p.w1, p.y1,
					  p.x2 + p.w2, p.y2, p.x2 - p.w2, p.y2, segment.color)
		
		# Draw lane markings
		if (seg_index / RUMBLE_LENGTH) % 2:
			var lane_w1 = p.w1 * 0.05
			var lane_w2 = p.w2 * 0.05
			var lane_x1 = p.x1 - p.w1 + p.w1 * 2 / LANES
			var lane_x2 = p.x2 - p.w2 + p.w2 * 2 / LANES
			
			for i in range(1, LANES):
				_draw_polygon(lane_x1 - lane_w1, p.y1, lane_x1 + lane_w1, p.y1,
							  lane_x2 + lane_w2, p.y2, lane_x2 - lane_w2, p.y2, LANE_COLOR)
				lane_x1 += p.w1 * 2 / LANES
				lane_x2 += p.w2 * 2 / LANES
		
		max_y = p.y2

func _draw_polygon(x1: float, y1: float, x2: float, y2: float, 
				   x3: float, y3: float, x4: float, y4: float, color: Color):
	var points = PackedVector2Array([
		Vector2(x1, y1),
		Vector2(x2, y2),
		Vector2(x3, y3),
		Vector2(x4, y4)
	])
	draw_colored_polygon(points, color)
