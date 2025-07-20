extends Node2D

# --- INITIALISE VARIABLES
# Manually declared variables
const N_CELLS: int = 12
const WORLD_ROTATION: float = -PI/12
const N_SEMICIRCLE_SEGMENTS: int = 64

# Event probabilities
# Patterns: Single semicircle against edge, double stacked semcircles, circle, two semicircles facing inwards
const P_PATTERNS_STARTING = [0.5, 0.2, 0.2, 0.2]  # initial probability of generating each pattern (first passthrough)
const P_IS_WHITE = 0.5  # probability that a given row's background color is white

# Calculated variables
const EXTRA_DRAWN = max(1, N_CELLS/6) * 2		# How many 'offscreen' cells to draw because of the tilt angle. Defaults to 1/3, minimum of 2. Must be even.
const N_DRAWN_CELLS: int = N_CELLS + EXTRA_DRAWN  # Total n drawn cells including offscreen cells

# World states
var show_circles: bool = true

# Initialise variables
var win_dim: Vector2		# dimensions of the window
var grid_length: float		# length (height and width) of the square grid
var cell_length: float		# length (height and width) of a single cell
var centre_point: Vector2	# centre-point of the entire grid

var grid_squares = []


# --- CLASS DEFINTIIONS ---
## Contains attributes for each square of the grid.
class GridSquare:
	var centre: Vector2
	var is_white: bool
	var initial_pattern_idx: int
	var current_pattern_idx: int = 0

	func _init(
		centre: Vector2,
		is_white: bool = false,
		initial_pattern_idx: int = 0
	):
		self.centre = centre
		self.is_white = is_white
		self.initial_pattern_idx = initial_pattern_idx


# --- MAIN FUNCTIONS ---
func _ready():
	# Seed the random seed generator with a unique value
	randomize()
	_update_viewport()

	# Initialise grid_squares object
	for row in range(N_DRAWN_CELLS):
		grid_squares.append([])
		for col in range(N_DRAWN_CELLS):
			# Centre never changes so we can initialise it
			var centre = Vector2(
				(col-EXTRA_DRAWN/2)*cell_length + cell_length/2,
				(row-EXTRA_DRAWN/2)*cell_length + cell_length/2
			)
			grid_squares[row].append(GridSquare.new(centre))

	# Generate the grid squares and semicircles and queue the first redraw of the scene
	_generate_grid_squares()
	_generate_semicircles()
	queue_redraw()

func _generate_grid_squares():
	# Randomly generate our grid square colors
	for row in range(N_DRAWN_CELLS):
		# All squares in the same row have the same color
		var is_white = randf() < P_IS_WHITE

		# Loop through columns, generate random starting pattern idx and create GridSquare class
		for col in range(N_DRAWN_CELLS):
			# Populate the grid_square
			grid_squares[row][col] = GridSquare.new(
				grid_squares[row][col].centre,  # centre never changes
				is_white,
				weighted_random(P_PATTERNS_STARTING)
			)

func _generate_semicircles():
	# Draw all grid squares and patterns to the screen
	for row in range(N_DRAWN_CELLS):
		# Keep a running count of pattern_idxs in that row
		var counts = [0, 0, 0, 0]

		for col in range(N_DRAWN_CELLS):
			var g = grid_squares[row][col]

			# --- GENERATE NEW PATTERN IDK ---
			# The new pattern idx is determined by the three adjacent patterns in the row (x-1, x, x+1)
			# Increment the counts by the next pattern_idx if not at end of row, and decrement by outdated one if not at start
			if (col < N_DRAWN_CELLS - 1): counts[grid_squares[row][col+1].initial_pattern_idx] += 1
			if (col > 1): counts[grid_squares[row][col-2].initial_pattern_idx] -= 1

			# Update the current pattern idx of the grid square
			g.current_pattern_idx = weighted_random(counts)

func _update_viewport():
	# Update the viewport if it has changed on every redraw
	var tmp_dim = get_viewport().get_visible_rect().size
	if win_dim != tmp_dim:
		win_dim = tmp_dim
		grid_length = min(win_dim.x, win_dim.y)
		cell_length = grid_length / N_CELLS

		# Update the buffer and centre
		centre_point = Vector2(grid_length/2, grid_length/2)

func _draw():
	_update_viewport()

	# Draw all grid squares and patterns to the screen
	for row in range(N_DRAWN_CELLS):
		for col in range(N_DRAWN_CELLS):
			var g = grid_squares[row][col]

			# Define grid square attributes and draw it
			draw_colored_polygon(
				_to_world(gen_square_points(g.centre, Vector2(cell_length, cell_length))),
				_to_color(g.is_white)
			)

			# Draw semicircles using current pattern
			if show_circles: 
				_draw_semicircle_pattern(
					g.centre,
					g.current_pattern_idx,
					_to_color(!g.is_white)
				)

# Redraw on R key presses
func _input(event):
	print('got here')
	if event is InputEventKey:
		# If R, reset the circle generation
		if event.keycode == KEY_R and event.is_pressed() and not event.is_echo():
			queue_redraw()

		# If H, toggle hide/show circles
		if event.keycode == KEY_H and event.is_pressed() and not event.is_echo():
			show_circles = !show_circles
			queue_redraw()


# --- HELPER FUNCTIONS ---
# General helpers 
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

func rotate_by(point: Vector2, angle: float, centre: Vector2 = Vector2(0,0)):
	return centre + (centre-point).rotated(angle)


# Private helpers
func _to_color(x: bool):
	if x == true: return Color(1,1,1)
	if x == false: return Color(0,0,0)
	return null

func _to_world(points: PackedVector2Array):
	for i in range(len(points)):
		points[i] = rotate_by(points[i], WORLD_ROTATION, centre_point)
	return points

""" Works by drawing one of the two semicircle patterns. """ 
func _draw_semicircle_pattern(
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

		draw_polygon(_to_world(sc_points), [color])


# Shape drawing functions
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
	centre: Vector2,
	dimensions: Vector2,
	angle: float = 0
):
	var points = [
		centre + Vector2(-dimensions.x/2, -dimensions.y/2),
		centre + Vector2(+dimensions.x/2, -dimensions.y/2),
		centre + Vector2(+dimensions.x/2, +dimensions.y/2),
		centre + Vector2(-dimensions.x/2, +dimensions.y/2),
	]

	# Rotate the points and return
	for idx in range(4): points[idx] = rotate_by(points[idx], angle, centre)
	return points



# Unused structs
# func _gen_nine_surrounding(row, col):
# 	# Generate cardinals and diagonals
# 	return [
# 		Vector2i(row-1, col-1), Vector2i(row-1, col), Vector2i(row-1, col+1),
# 		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
# 		Vector2i(row+1, col-1), Vector2i(row+1, col), Vector2i(row+1, col+1),
# 	]

# func _gen_five_surrounding(row, col):
# 	# Only generate on the cardinals
# 	return [
# 								Vector2i(row-1, col),
# 		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
# 								Vector2i(row+1, col),
# 	]

# func _gen_three_surrounding(row, col):
# 	# Only generate on the same row
# 	return [
# 		Vector2i(row,   col-1), Vector2i(row,   col), Vector2i(row,   col+1),
# 	]
