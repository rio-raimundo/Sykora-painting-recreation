extends Node2D

class Point:
	var x: float
	var y: float

	func _init(x: float, y: float):
		self.x = x
		self.y = y

class GridSquareAttributes:
	var is_vertical: bool  # whether semicircles within are vertically or horizontally aligned 
	var is_white: bool

	func _init(is_vertical: bool, is_white: bool):
		self.is_vertical = is_vertical
		self.is_white = is_white

class SemicircleAttributes:
	var is_flipped: bool  # whether the semicircle is rotated 180 degrees
	var is_white: bool

	func _init(is_flipped: bool, is_white: bool):
		self.is_flipped = is_flipped

# Declare variables
const N_CELLS: int = 12
const N_SEMICIRCLE_SEGMENTS: int = 64
const WORLD_ROTATION: float = -PI/12

# Calculated variables
const EXTRA_DRAWN = max(1, N_CELLS/6) * 2  # should always be even
const N_DRAWN_CELLS: int = N_CELLS + EXTRA_DRAWN
const TOTAL_CELLS: int = N_CELLS**2

# Probabilities
const PROB_WHITE_SQUARE = 0.5
const PROB_WHITE_SEMICIRCLE = 0.5
const PROB_SEMICIRCLE = 0.5
const PROB_SEMICIRCLE_FLIPPED = 0.5
const PROB_VERTICAL = 0.5

# Initialise variables
var win_dim
var grid_length: float
var cell_length: float

var grid_squares = []
var semicircles = []
var buffer: Vector2 = Vector2(0,0)
var centre_point: Vector2

func _ready():
	# Seed the random seed generator with a unique value
	randomize()

	# Randomly generate our grid square colors
	for x in range(N_DRAWN_CELLS):
		grid_squares.append([])
		for y in range(N_DRAWN_CELLS):
			var is_vertical = randf() < PROB_VERTICAL  # 0 is horizontal, 1 is vertical
			var is_white = randf() < PROB_WHITE_SQUARE
			grid_squares[x].append(GridSquareAttributes.new(is_vertical, is_white))

	# Define our semicircles as a nested grid - each row and column can have up to two semicircles
	# Probability of there being a semicircle depends on the PROB_SEMICIRCLE variable
	# 0 for black, 1 for white, null for none
	for x in range(N_DRAWN_CELLS):
		semicircles.append([])
		for y in range(N_DRAWN_CELLS):
			semicircles[x].append([])

			for z in range(2):
				var is_semicircle = randf() < PROB_SEMICIRCLE
				if !is_semicircle: semicircles[x][y].append(null)

				var orientation = randf() < PROB_SEMICIRCLE_FLIPPED
				var color = randf() < PROB_WHITE_SEMICIRCLE
				semicircles[x][y].append(SemicircleAttributes.new(orientation, color))

	queue_redraw()

func _draw():
	var tmp_dim = get_viewport().get_visible_rect().size
	if win_dim != tmp_dim:
		win_dim = tmp_dim
		grid_length = min(win_dim.x, win_dim.y)
		cell_length = grid_length / N_CELLS

		# Update the buffer and centre
		centre_point = buffer + Vector2(grid_length/2, grid_length/2)

	# Draw all grid squares first
	for x in range(N_DRAWN_CELLS):
		for y in range(N_DRAWN_CELLS):
			var g = grid_squares[x][y]

			# Define x and y of top left corner
			var origin = Vector2((x-EXTRA_DRAWN/2)*cell_length, (y-EXTRA_DRAWN/2)*cell_length)

			# Define grid square attributes and draw it
			var grid_color = to_color(g.is_white)
			draw_rotated_rect(origin, Vector2(cell_length, cell_length), grid_color, WORLD_ROTATION, centre_point)

	# Draw all semicircles over the top
	for x in range(N_DRAWN_CELLS):
		for y in range(N_DRAWN_CELLS):
			var g = grid_squares[x][y]
			var origin = Vector2((x-EXTRA_DRAWN/2)*cell_length, (y-EXTRA_DRAWN/2)*cell_length)

			# Define semicircle attributes and draw them
			var base_rotation = to_grid_orientation(g.is_vertical)
			for z in range(2):
				var sc = semicircles[x][y][z]
				if sc == null: continue

				# If vertical, assign the offset
				var active_offset = 0.25 + (0.5*z)
				var centre_offset
				if g.is_vertical == false: centre_offset = Vector2(0.5*cell_length, active_offset*cell_length)  # horizontal offset
				else: centre_offset = Vector2(active_offset*cell_length, 0.5*cell_length)  # vertical offset

				var centre = origin + centre_offset
				var sc_color = to_color(!g.is_white)
				var sc_orientation = base_rotation + to_sc_orientation(sc.is_flipped)

				var sc_points = semicircle_points(centre, cell_length/2, sc_orientation)
				sc_points = to_world(sc_points)
				print(sc_points)
				draw_polygon(sc_points, [sc_color])
				


# Helper functions
func grid_idx(x: int, y: int):
	var out = y*N_CELLS + x
	return out

func to_color(x: bool):
	if x == true: return Color(1,1,1)
	if x == false: return Color(0,0,0)
	return null

func to_grid_orientation(x: bool):
	if x == true: return PI/2  # should be vertical
	if x == false: return 0  # should be horizontal

func to_sc_orientation(x: bool): 
	if x == true: return 0  # should be vertical
	if x == false: return PI  # should be horizontal

func rotate_by(point: Vector2, angle: float, centre: Vector2 = Vector2(0,0)):
	return centre + (centre-point).rotated(angle)

func to_world(points: PackedVector2Array):
	for i in range(len(points)):
		points[i] = rotate_by(points[i], WORLD_ROTATION, centre_point)
	return points


"""
draws a semicircle with specified center, radius, color, and orientation

@param centre: Vector2, center position of the semicircle (treating it as a rectangle)
@param radius: float, radius of the enclosing circle
@param color: Color, fill color
@param orientation: float (radians, default 0), rotation of the semicircle around its center
"""
func semicircle_points(
	centre: Vector2,
	radius: float,
	orientation: float = 0
):
	const s = N_SEMICIRCLE_SEGMENTS
	var circle_centre = centre - Vector2(0, 0.25*cell_length)
	var points = []

	# Divide pi degrees into s segments, draw over half a circle
	for i in range(s + 1):
		var angle = PI * i / s  # 0 to π
		var base_point = circle_centre + Vector2(cos(angle), sin(angle)) * radius

		# Rotate the point by the given orientation
		points.append(rotate_by(base_point, orientation, centre))
	
	return points

func draw_rotated_rect(origin: Vector2, size: Vector2, color: Color, angle: float, centre: Vector2):
	var corners = [
		origin,
		origin + Vector2(size.x, 0),
		origin + size,
		origin + Vector2(0, size.y)
	]
	for i in range(corners.size()):
		corners[i] = rotate_by(corners[i], angle, centre)
	draw_polygon(corners, [color])
