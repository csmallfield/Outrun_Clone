extends Node2D

# Road rendering constants
const ROAD_WIDTH = 2000  # Road width at camera position
const SEGMENT_LENGTH = 200  # Length of each road segment
const RUMBLE_LENGTH = 3  # Length of rumble strips
const LANES = 3  # Number of lanes
const FIELD_OF_VIEW = 100  # Camera field of view
const CAMERA_HEIGHT = 1000  # Camera height above road
const CAMERA_DEPTH = 0.84  # Camera depth scaling factor
const DRAW_DISTANCE = 300  # How many segments to draw
const ROAD_COLOR = Color(0.4, 0.4, 0.4)
const RUMBLE_COLOR_1 = Color(1, 1, 1)
const RUMBLE_COLOR_2 = Color(1, 0, 0)
const GRASS_COLOR_1 = Color(0, 0.6, 0)
const GRASS_COLOR_2 = Color(0, 0.5, 0)
const LANE_COLOR = Color(1, 1, 1, 0.4)

# Road state
var camera_z = 0.0  # Camera Z position (distance traveled)
var player_x = 0.0  # Player X position on road (-1 to 1)
var speed = 0.0  # Current speed

# Road segments data structure
var segments = []

class Segment:
	var index: int
	var p1: Dictionary  # World position start {x, y, z}
	var p2: Dictionary  # World position end {x, y, z}
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
	# Initialize road segments
	for i in range(500):  # Create 500 segments
		var seg = Segment.new()
		seg.index = i
		seg.p1 = {"x": 0, "y": 0, "z": i * SEGMENT_LENGTH}
		seg.p2 = {"x": 0, "y": 0, "z": (i + 1) * SEGMENT_LENGTH}
		
		# Alternate segment colors for depth perception
		seg.color = ROAD_COLOR if (i / RUMBLE_LENGTH) % 2 else ROAD_COLOR.darkened(0.1)
		
		segments.append(seg)

func _draw():
	var viewport_size = get_viewport_rect().size
	var width = viewport_size.x
	var height = viewport_size.y
	
	# Clear background with sky gradient
	draw_rect(Rect2(0, 0, width, height/2), Color(0.5, 0.7, 1.0))
	draw_rect(Rect2(0, height/2, width, height/2), GRASS_COLOR_1)
	
	# Calculate camera position
	var base_segment = int(camera_z / SEGMENT_LENGTH)
	var base_percent = fmod(camera_z, SEGMENT_LENGTH) / SEGMENT_LENGTH
	var camera_x = player_x * ROAD_WIDTH
	var camera_y = CAMERA_HEIGHT
	
	# Draw road segments from far to near
	var max_y = height
	var x = 0.0
	var dx = 0.0
	
	for n in range(DRAW_DISTANCE, 0, -1):
		var seg_index = (base_segment + n) % segments.size()
		var segment = segments[seg_index]
		
		# Calculate curve offset
		segment.p1.x = x
		segment.p2.x = x + dx
		x += dx
		dx += segment.curve
		
		# Project segment to screen
		var p = segment.project(camera_x - x, camera_y, camera_z - base_percent * SEGMENT_LENGTH, 
								CAMERA_DEPTH, width, height)
		
		# Skip if segment is behind camera
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

func update_camera(delta: float):
	camera_z += speed * delta
	queue_redraw()

func set_player_x(x: float):
	player_x = clamp(x, -1.0, 1.0)

func set_speed(s: float):
	speed = s
