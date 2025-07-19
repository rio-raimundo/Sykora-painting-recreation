# TODO HAVE THE PATTERN IDX BE WEIGHTED BY NEARBY TILES - 'sticky'

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
const PROB_SEMICIRCLE = 0.5
const PROB_VERTICAL = 0.5
# Single edge, double stacked, circle, two facing inwards
const SEMICIRCLE_PATTERN_PROBABILITIES = [0.1, 0.3, 0.3, 0.3]

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
			draw_polygon(
				to_world(gen_square_points(origin, Vector2(cell_length, cell_length))),
				[grid_color]
			)

			# For each grid, we pick one of the semicircle patterns to draw over the top

			# TODO Figure out this generation
			var pattern_idx = weighted_random(SEMICIRCLE_PATTERN_PROBABILITIES)
			draw_semicircle_pattern(origin + Vector2(cell_length/2, cell_length/2), pattern_idx, to_color(!g.is_white))


# Helper functions
static func sum(array):
	var x = 0.0
	for element in array: x += element
	return x

func weighted_random(probabilities: Array):
	# Treat the sum of the probabilities as an upper bound and check where we got 
	var rnd_guess = int(randf() * sum(probabilities))
	print(rnd_guess)

	for i in range(len(probabilities)):
		if rnd_guess < probabilities[i]: return i
		rnd_guess -= probabilities[i]


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

""" Works by drawing one of the two semicircle patterns. """ 
func draw_semicircle_pattern(
	centre: Vector2, 	# centre of the square
	pattern_idx: int,   # which of the four legal patterns to draw
	color: Color
):
	# Assign the rotations
	var sc_centres
	var sc_rotations
	if pattern_idx == 0:
		sc_centres = [centre + Vector2(0, 0.25*cell_length)]
		sc_rotations = [0]
	elif pattern_idx == 1:
		sc_centres = [centre - Vector2(0, 0.25*cell_length), centre + Vector2(0, 0.25*cell_length)]
		sc_rotations = [0, 0]
	elif pattern_idx == 1:
		sc_centres = [centre - Vector2(0, 0.25*cell_length), centre + Vector2(0, 0.25*cell_length)]
		sc_rotations = [0, PI]
	elif pattern_idx == 1:
		sc_centres = [centre - Vector2(0, 0.25*cell_length), centre + Vector2(0, 0.25*cell_length)]
		sc_rotations = [PI, 0]

	# Choose the global rotation to apply - each of the four options has 25% chance for now
	var base_rotation = int(randf()*4) * PI/2

	for sc_idx in range(len(sc_centres)):
		var sc_points = gen_semicircle_points(sc_centres[sc_idx], cell_length/2, sc_rotations[sc_idx])

		# Rotate around the centre of the SQUARE by the base rotation
		for idx in range(len(sc_points)): sc_points[idx] = rotate_by(sc_points[idx], base_rotation, centre)

		draw_polygon(to_world(sc_points), [color])


"""
draws a semicircle with specified center, radius, color, and orientation

@param centre: Vector2, center position of the semicircle (treating it as a rectangle)
@param radius: float, radius of the enclosing circle
@param color: Color, fill color
@param orientation: float (radians, default 0), rotation of the semicircle around its center
"""
func gen_semicircle_points(
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

func gen_square_points(
	origin: Vector2,
	dimensions: Vector2,
	angle: float = 0
):
	var points = [
		origin,
		origin + Vector2(dimensions.x, 0),
		origin + dimensions,
		origin + Vector2(0, dimensions.y)
	]

	# Rotate the points
	for idx in range(4): points[idx] = rotate_by(points[idx], angle, origin + dimensions/2)

	return points
