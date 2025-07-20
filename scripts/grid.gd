extends Node2D

# Declare variables
const N_CELLS: int = 12
const WORLD_ROTATION: float = -PI/12
const N_SEMICIRCLE_SEGMENTS: int = 64

# Probabilities
const P_IS_WHITE = 0.5
const P_IS_VERTICAL = 0.5
# Single edge, double stacked, circle, two facing inwards
const P_PATTERNS_STARTING = [0.4, 0.2, 0.2, 0.2]

# Calculated variables
const EXTRA_DRAWN = max(1, N_CELLS/6) * 2  # should always be even
const N_DRAWN_CELLS: int = N_CELLS + EXTRA_DRAWN

# Initialise variables
var win_dim
var grid_length: float
var cell_length: float
var centre_point: Vector2

var grid_squares = []
var pattern_idxs = []


# --- CLASS DEFINTIIONS ---
class GridSquareAttributes:
	var is_vertical: bool  # whether pattern_idxs within are vertically or horizontally aligned 
	var is_white: bool
	var pattern_idx: int

	func _init(is_vertical: bool, is_white: bool, pattern_idx):
		self.is_vertical = is_vertical
		self.is_white = is_white
		self.pattern_idx = pattern_idx


# --- MAIN FUNCTIONS ---
func _ready():
	# Seed the random seed generator with a unique value
	randomize()

	# Randomly generate our grid square colors
	for row in range(N_DRAWN_CELLS):
		grid_squares.append([])

		# All squares in the same row have the same color
		var is_white = randf() < P_IS_WHITE

		for col in range(N_DRAWN_CELLS):
			var is_vertical = randf() < P_IS_VERTICAL  # 0 is horizontal, 1 is vertical
			grid_squares[row].append(GridSquareAttributes.new(
				is_vertical,
				is_white,
				weighted_random(P_PATTERNS_STARTING)
			))

	queue_redraw()

func _draw():
	var tmp_dim = get_viewport().get_visible_rect().size
	if win_dim != tmp_dim:
		win_dim = tmp_dim
		grid_length = min(win_dim.x, win_dim.y)
		cell_length = grid_length / N_CELLS

		# Update the buffer and centre
		centre_point = Vector2(grid_length/2, grid_length/2)

	# Draw all grid squares first
	for row in range(N_DRAWN_CELLS):
		for col in range(N_DRAWN_CELLS):
			var g = grid_squares[row][col]

			# Define x and y of top left corner
			var origin = Vector2((col-EXTRA_DRAWN/2)*cell_length, (row-EXTRA_DRAWN/2)*cell_length)

			# Define grid square attributes and draw it
			var grid_color = to_color(g.is_white)
			draw_polygon(
				to_world(gen_square_points(origin, Vector2(cell_length, cell_length))),
				[grid_color]
			)

			# --- GENERATE NEW PATTERN IDK ---
			# We use a weighted sum of the squares on that row to generate the pidx
			if (row in range(1, N_DRAWN_CELLS-1)) and (col in range(1, N_DRAWN_CELLS-1)):
				var counts = [0, 0, 0, 0]
				var squares = _gen_three_surrounding(row, col)
				for square in squares: counts[grid_squares[square.x][square.y].pattern_idx] += 1

				draw_semicircle_pattern(
					origin + Vector2(cell_length/2, cell_length/2),
					weighted_random(counts),
					to_color(!g.is_white)
				)

# Helper functions
static func sum(array):
	var x = 0.0
	for element in array: x += element
	return x

func weighted_random(probabilities: Array):
	# Treat the sum of the probabilities as an upper bound and check where we got 
	var rnd_guess = randf() * sum(probabilities)

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
	elif pattern_idx == 2:
		sc_centres = [centre - Vector2(0, 0.25*cell_length), centre + Vector2(0, 0.25*cell_length)]
		sc_rotations = [0, PI]
	elif pattern_idx == 3:
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



# Unused structs
func _gen_nine_surrounding(row, col):
	# Generate cardinals and diagonals
	return [
		Vector2i(row-1, col-1), Vector2i(row-1, col), Vector2i(row-1, col+1),
		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
		Vector2i(row+1, col-1), Vector2i(row+1, col), Vector2i(row+1, col+1),
	]

func _gen_five_surrounding(row, col):
	# Only generate on the cardinals
	return [
								Vector2i(row-1, col),
		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
								Vector2i(row+1, col),
	]

func _gen_three_surrounding(row, col):
	# Only generate on the same row
	return [
		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
	]
