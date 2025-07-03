extends Node2D

# Movement constants
const MAX_SPEED = 300.0  # Maximum speed
const ACCELERATION = 100.0  # Acceleration rate
const BRAKING = 200.0  # Braking rate
const TURN_SPEED = 2.0  # Turning speed
const OFFROAD_DECEL = 200.0  # Deceleration when off road
const OFFROAD_MAX_SPEED = MAX_SPEED / 2  # Max speed when off road

# References
@onready var road_renderer = get_node("../RoadRenderer")
var sprite: Sprite2D

# Player state
var speed = 0.0
var position_x = 0.0  # Position on road (-1 to 1)
var is_offroad = false

func _ready():
	# Create a simple colored rectangle as placeholder car
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create a placeholder car texture
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(1, 0, 0))  # Red car
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	
	# Position at bottom center of screen
	var viewport_size = get_viewport_rect().size
	position = Vector2(viewport_size.x / 2, viewport_size.y - 100)

func _process(delta):
	handle_input(delta)
	update_position()
	
	# Update road renderer
	if road_renderer:
		road_renderer.set_speed(speed)
		road_renderer.set_player_x(position_x)
		road_renderer.update_camera(delta)

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
		# Natural deceleration
		speed -= 50.0 * delta
	
	# Apply off-road deceleration
	if is_offroad:
		speed -= OFFROAD_DECEL * delta
		speed = min(speed, OFFROAD_MAX_SPEED)
	
	# Clamp speed
	speed = clamp(speed, 0, MAX_SPEED)
	
	# Steering
	var steer_input = 0.0
	if Input.is_action_pressed("ui_left"):
		steer_input = -1.0
	elif Input.is_action_pressed("ui_right"):
		steer_input = 1.0
	
	# Apply steering with speed-based sensitivity
	var speed_factor = speed / MAX_SPEED
	position_x += steer_input * TURN_SPEED * speed_factor * delta
	position_x = clamp(position_x, -2.0, 2.0)  # Allow going slightly off-road
	
	# Check if off-road
	is_offroad = abs(position_x) > 1.0

func update_position():
	var viewport_size = get_viewport_rect().size
	var road_center = viewport_size.x / 2
	
	# Calculate screen position based on road position
	var screen_x = road_center + (position_x * viewport_size.x * 0.4)
	position.x = screen_x
	
	# Add slight swaying based on speed and turning
	var sway = sin(Time.get_ticks_msec() / 100.0) * (speed / MAX_SPEED) * 2.0
	position.x += sway
	
	# Tilt sprite when turning
	sprite.rotation = position_x * 0.1

func get_speed_percent():
	return speed / MAX_SPEED
