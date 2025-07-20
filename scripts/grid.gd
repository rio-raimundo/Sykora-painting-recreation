extends Node2D

# --- INITIALISE VARIABLES
# Manually declared variables
const N_CELLS: int = 12
const WORLD_ROTATION: float = -PI/12
const N_SEMICIRCLE_SEGMENTS: int = 64

const GridSquareScene = preload("res://scenes/grid_square.tscn")

# Event probabilities
# Patterns: Single semicircle against edge, double stacked semcircles, circle, two semicircles facing inwards
const P_PATTERNS_STARTING = [0.5, 0.1, 0.2, 0.2]  # initial probability of generating each pattern (first passthrough)
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


# --- MAIN FUNCTIONS ---
func _ready():
	# Seed the random seed generator with a unique value
	randomize()
	_update_viewport()

	# Initialise grid_squares object
	for row in range(N_DRAWN_CELLS):
		grid_squares.append([])
		for col in range(N_DRAWN_CELLS):
			# Centre position never changes so we can initialise it

			var position = _to_world([Vector2(
				(col-EXTRA_DRAWN/2)*cell_length + cell_length/2,
				(row-EXTRA_DRAWN/2)*cell_length + cell_length/2
			)])
			# Generate points RELATIVE to a centre of (0, 0) to pass in
			var points = gen_square_points(
				Vector2(cell_length, cell_length),
				Vector2(0, 0),  # centre
				WORLD_ROTATION,  # rotate by world rotation
			)

			# Initialise our grid square scene as a child and call the setup function
			var instance = GridSquareScene.instantiate()
			instance.setup(Vector2i(row, col), position[0], points)
			instance.square_clicked.connect(_on_grid_square_clicked)
			add_child(instance)
			grid_squares[row].append(instance)

	# Generate the grid squares and semicircles and queue the first redraw of the scene
	_generate_grid_squares()
	_generate_semicircles()
	queue_redraw()

func _on_grid_square_clicked(
	id: Vector2i
):
	var g = grid_squares[id[0]][id[1]]
	print(g.id)

func _generate_grid_squares(
	gen_color: bool = true,
	gen_initial_patterns: bool = true,
):
	if gen_color:
		for row in range(N_DRAWN_CELLS):
			var is_white = randf() < P_IS_WHITE
			for col in range(N_DRAWN_CELLS):
				grid_squares[row][col].is_white = is_white
				
	if gen_initial_patterns:
		for row in range(N_DRAWN_CELLS):
			for col in range(N_DRAWN_CELLS):
				var grid_orientation = int(randf()*4) * PI/2
				var initial_pattern_idx = weighted_random(P_PATTERNS_STARTING)
				grid_squares[row][col].initial_pattern_idx = initial_pattern_idx
				grid_squares[row][col].orientation = grid_orientation

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
				g.points,  # already in world coordinates
				_to_color(g.is_white)
			)

			# Draw semicircles using current pattern
			if show_circles: 
				_draw_semicircle_pattern(
					g.position,
					g.current_pattern_idx,
					g.orientation + WORLD_ROTATION,
					_to_color(!g.is_white)
				)

# Handle inputs
# TODO SHIFT THROUGH PATTERNS ON LEFT CLICK, ROTATE ON RIGHT CLICK, LOCK ON MIDDLE? 
func _input(event):
	const LEGAL_KEYS = [KEY_S, KEY_P, KEY_R, KEY_H, KEY_C]

	if (event is InputEventKey) and (event.keycode in LEGAL_KEYS):
		# If S, reset the circle generation KEEPING THE SAME INITIAL PATTERN IDXS
		if event.keycode == KEY_S and event.is_pressed() and not event.is_echo():
			_generate_semicircles()

		# If P, reset the circle generation WITH NEW PATTERN IDXs
		if event.keycode == KEY_P and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(false, true)
			_generate_semicircles()

		# If C, reset just the background colors
		if event.keycode == KEY_C and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(true, false)

		# If R, reset everything
		if event.keycode == KEY_R and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(true, true)
			_generate_semicircles()

		# If H, toggle hide/show circles
		if event.keycode == KEY_H and event.is_pressed() and not event.is_echo():
			show_circles = !show_circles
		
		# Redraw no matter what
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
	return centre + (point-centre).rotated(angle)


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
	square_orientation: float, # the orientation of the pattern (should be in [0, PI/2, PI, -PI/2])
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

	for sc_idx in range(len(sc_centres)):
		var sc_points = gen_semicircle_points(sc_centres[sc_idx], cell_length/2, sc_rotations[sc_idx])

		# Rotate around the centre of the SQUARE by the base rotation
		for idx in range(len(sc_points)): sc_points[idx] = rotate_by(sc_points[idx], square_orientation, centre)

		draw_polygon(sc_points, [color])


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
	dimensions: Vector2,
	centre: Vector2 = Vector2(0, 0),
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
