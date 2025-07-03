extends Node2D
# Working pseudo-3D road renderer for Outrun-style racing

# Road constants
const ROAD_WIDTH = 1500000
const SEGMENT_LENGTH = 200
const RUMBLE_LENGTH = 3
const LANES = 3
const CAMERA_HEIGHT = 1000
const CAMERA_DEPTH = 0.84
const DRAW_DISTANCE = 200

# Player constants  
const MAX_SPEED = 6000.0
const ACCELERATION = 2000.0
const BRAKING = 4000.0
const TURN_SPEED = 0.0025
const OFFROAD_DECEL = 0  # No deceleration when off-road
const OFFROAD_MAX_SPEED = MAX_SPEED / 2

# Colors
const ROAD_COLOR_LIGHT = Color(0.4, 0.4, 0.4)
const ROAD_COLOR_DARK = Color(0.35, 0.35, 0.35)
const RUMBLE_COLOR_WHITE = Color(1, 1, 1)
const RUMBLE_COLOR_RED = Color(0.8, 0, 0)
const GRASS_COLOR_LIGHT = Color(0.1, 0.7, 0.1)
const GRASS_COLOR_DARK = Color(0.0, 0.6, 0.0)
const LANE_COLOR = Color(1, 1, 1, 0.4)
const SKY_COLOR = Color(0.5, 0.7, 1.0)

# Game state
var camera_z = 0.0
var player_x = 0.0  # Player position on road
var speed = 0.0
var is_offroad = false
var segments = []
var current_curve = 0.0

# UI
var speed_label: Label
var debug_label: Label
var player_sprite: Sprite2D

class Segment:
	var index: int
	var world_z: float
	var curve: float = 0.0
	
	func project(camera_x: float, camera_y: float, camera_z: float, screen_width: float, screen_height: float) -> Dictionary:
		var scale = CAMERA_DEPTH / max(1, self.world_z - camera_z)
		var screen_x = screen_width / 2 + scale * camera_x * screen_width / 2
		var screen_y = screen_height / 2 + scale * camera_y * screen_height / 2
		var screen_w = scale * ROAD_WIDTH * screen_width / 4000
		
		return {
			"x": screen_x,
			"y": screen_y,
			"w": screen_w,
			"scale": scale
		}

func _ready():
	print("Working Road Renderer Started")
	
	# Initialize segments - ensure first segments are straight
	for i in range(500):
		var seg = Segment.new()
		seg.index = i
		seg.world_z = i * SEGMENT_LENGTH
		seg.curve = 0  # Default to straight
		
		# Add gentler curves
		if i > 200 and i < 250:
			seg.curve = 0.3  # Reduced from 0.5
		elif i > 300 and i < 350:
			seg.curve = -0.3  # Reduced from -0.5
		elif i > 400 and i < 450:
			seg.curve = 0.5  # Moderate curve
			
		segments.append(seg)
	
	# Start at z=0 to ensure we begin on straight road
	camera_z = 0.0
	player_x = 0.0
	
	create_ui()
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
	
	# Red car placeholder
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0, 0))
	# Add windshield
	for x in range(20, 44):
		for y in range(10, 25):
			image.set_pixel(x, y, Color(0.2, 0.2, 0.3))
	
	var texture = ImageTexture.create_from_image(image)
	player_sprite.texture = texture
	player_sprite.z_index = 100

func _process(delta):
	handle_input(delta)
	camera_z += speed * delta
	update_player_position()
	update_ui()
	queue_redraw()

func handle_input(delta):
	# Get current segment to check for curves
	var current_segment_index = int(camera_z / SEGMENT_LENGTH) % segments.size()
	if current_segment_index >= 0 and current_segment_index < segments.size():
		current_curve = segments[current_segment_index].curve
	
	# Acceleration/Braking
	if Input.is_action_pressed("ui_up"):
		speed += ACCELERATION * delta
	elif Input.is_action_pressed("ui_down"):
		speed -= BRAKING * delta
	else:
		speed -= 50.0 * delta
	
	speed = clamp(speed, 0, MAX_SPEED)
	
	# Steering - let's fix this properly
	var steer_input = 0.0
	if Input.is_action_pressed("ui_left"):
		steer_input = -1.0  # Left should decrease player_x
	elif Input.is_action_pressed("ui_right"):
		steer_input = 1.0   # Right should increase player_x
	
	# Apply steering
	var speed_factor = speed / MAX_SPEED
	player_x += steer_input * TURN_SPEED * speed_factor * delta
	
	# Apply centrifugal force in curves
	var centrifugal_force = current_curve * speed_factor * 0.004
	player_x -= centrifugal_force * delta
	
	player_x = clamp(player_x, -2.0, 2.0)
	
	# Simple off-road detection
	is_offroad = abs(player_x) > 0.001

func update_player_position():
	var viewport_size = get_viewport_rect().size
	var road_center = viewport_size.x / 2
	var screen_x = road_center + (player_x * viewport_size.x * 0.4)
	
	# Add shake when off-road
	if is_offroad:
		screen_x += sin(Time.get_ticks_msec() * 0.1) * 5.0
		player_sprite.position.y = viewport_size.y - 100 + sin(Time.get_ticks_msec() * 0.15) * 3.0
	else:
		player_sprite.position.y = viewport_size.y - 100
	
	player_sprite.position.x = screen_x
	player_sprite.rotation = player_x * 0.1
	
	# Scale based on speed
	var scale = 1.0 + (speed / MAX_SPEED) * 0.1
	player_sprite.scale = Vector2(scale, scale)
	
	# Change car color when off-road
	if is_offroad:
		player_sprite.modulate = Color(1, 0.7, 0.7)
	else:
		player_sprite.modulate = Color.WHITE

func update_ui():
	var speed_kmh = int(speed / 25)
	speed_label.text = "Speed: %d km/h" % speed_kmh
	
	# Show curve info
	var curve_dir = ""
	if abs(current_curve) > 0.1:
		curve_dir = " | CURVE " + ("RIGHT" if current_curve > 0 else "LEFT")
	
	# Debug text
	if is_offroad:
		debug_label.modulate = Color(1, 0.5, 0.5)
		debug_label.text = "Pos X: %.3f | OFF-ROAD!%s" % [player_x, curve_dir]
	else:
		debug_label.modulate = Color.WHITE
		debug_label.text = "Pos X: %.3f | On Road%s" % [player_x, curve_dir]

func _draw():
	var viewport_size = get_viewport_rect().size
	var width = viewport_size.x
	var height = viewport_size.y
	
	# Draw sky and base ground
	draw_rect(Rect2(0, 0, width, height/2), SKY_COLOR)
	draw_rect(Rect2(0, height/2, width, height/2), GRASS_COLOR_LIGHT)
	
	# Find base segment
	var base_segment = int(camera_z / SEGMENT_LENGTH)
	var camera_x = player_x * ROAD_WIDTH * 0.5
	
	# Draw segments from far to near
	var previous_y = height / 2
	var x = 0.0
	var dx = 0.0
	
	# Reset curve accumulation for each frame
	for n in range(DRAW_DISTANCE, 0, -1):
		var seg_index = (base_segment + n) % segments.size()
		if seg_index < 0:
			seg_index += segments.size()
		
		var segment = segments[seg_index]
		
		# Update the segment's world position for infinite road
		var segment_base = int((camera_z + n * SEGMENT_LENGTH) / (segments.size() * SEGMENT_LENGTH))
		segment.world_z = (seg_index * SEGMENT_LENGTH) + (segment_base * segments.size() * SEGMENT_LENGTH)
		
		# Apply curve - accumulate from the farthest segment
		dx += segment.curve * 0.00002  # MUCH smaller curve intensity
		x += dx
		
		# Project segment position - simple centered projection
		var near = segment.project(-camera_x, CAMERA_HEIGHT, camera_z, width, height)
		
		# Apply curve offset to X position after projection
		near.x += x * 2000  # Reduced from 200 to compensate for smaller curve values
		
		# Skip if behind camera or above previous segment
		if near.scale <= 0 or near.y <= previous_y:
			continue
			
		var far_y = previous_y
		var near_y = near.y
		
		# Additional validation
		if abs(far_y - near_y) < 0.1:
			continue
		
		# Clamp coordinates to screen bounds
		near_y = clamp(near_y, 0, height)
		far_y = clamp(far_y, 0, height)
		
		# Determine colors based on segment position
		var grass_color = GRASS_COLOR_LIGHT if (seg_index / RUMBLE_LENGTH) % 2 else GRASS_COLOR_DARK
		var rumble_color = RUMBLE_COLOR_WHITE if (seg_index / RUMBLE_LENGTH) % 2 else RUMBLE_COLOR_RED
		var road_color = ROAD_COLOR_LIGHT if (seg_index / RUMBLE_LENGTH) % 2 else ROAD_COLOR_DARK
		
		# Draw grass
		if far_y > near_y:
			draw_rect(Rect2(0, near_y, width, far_y - near_y), grass_color)
		
		# Calculate road edges
		var near_road_width = near.w
		var far_road_width = near_road_width * 0.8
		
		# Ensure minimum road width
		if near_road_width < 1.0:
			previous_y = near_y
			continue
		
		# Ensure X coordinates are valid
		var road_left = near.x - near_road_width
		var road_right = near.x + near_road_width
		
		# Draw rumble strips
		var rumble_width = near_road_width * 0.15
		if rumble_width > 0:
			# Left rumble
			_draw_quad(
				road_left - rumble_width, far_y,
				road_left, far_y,
				road_left, near_y,
				road_left - rumble_width, near_y,
				rumble_color
			)
			
			# Right rumble
			_draw_quad(
				road_right, far_y,
				road_right + rumble_width, far_y,
				road_right + rumble_width, near_y,
				road_right, near_y,
				rumble_color
			)
		
		# Draw road
		_draw_quad(
			road_left, far_y,
			road_right, far_y,
			road_right, near_y,
			road_left, near_y,
			road_color
		)
		
		# Draw lane lines
		if (seg_index / RUMBLE_LENGTH) % 2:
			var lane_width = max(1.0, near_road_width * 0.02)
			for lane in range(1, LANES):
				var lane_x = near.x - near_road_width + (near_road_width * 2 * lane / LANES)
				_draw_quad(
					lane_x - lane_width, far_y,
					lane_x + lane_width, far_y,
					lane_x + lane_width, near_y,
					lane_x - lane_width, near_y,
					LANE_COLOR
				)
		
		previous_y = near_y

func _draw_quad(x1: float, y1: float, x2: float, y2: float, 
				x3: float, y3: float, x4: float, y4: float, color: Color):
	# Validate coordinates
	if is_nan(x1) or is_nan(y1) or is_nan(x2) or is_nan(y2) or \
	   is_nan(x3) or is_nan(y3) or is_nan(x4) or is_nan(y4):
		return
	
	# Check for degenerate quad
	var min_size = 0.1
	if abs(x1 - x2) < min_size and abs(x3 - x4) < min_size and \
	   abs(x1 - x3) < min_size and abs(x2 - x4) < min_size:
		return
	
	if abs(y1 - y4) < min_size and abs(y2 - y3) < min_size and \
	   abs(y1 - y2) < min_size and abs(y3 - y4) < min_size:
		return
	
	# Ensure points are in correct order
	var points = PackedVector2Array([
		Vector2(x1, y1),
		Vector2(x2, y2),
		Vector2(x3, y3),
		Vector2(x4, y4)
	])
	
	if points.size() == 4:
		draw_colored_polygon(points, color)
