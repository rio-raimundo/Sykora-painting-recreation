extends Node2D

# --- INITIALISE VARIABLES ---
# Manually declared variables
const N_CELLS: int = 12
const WORLD_ROTATION: float = -15
const N_SEMICIRCLE_SEGMENTS: int = 64
const P_IS_WHITE = 0.5  # probability that a given row's background color is white

const GridSquareScene = preload("res://scenes/grid_square.tscn")
var h = Helpers

# Load in class for specified pattern
# Each class contains an array of starting probabilities and an array of textures, which are passed through to the GridSquares instances
# Current available patterns can be found by querying PatternsList.PatternNames
var pattern = PatternsList.Patterns[PatternsList.PatternNames.TRIANGLES1]

# Calculated variables
const EXTRA_DRAWN = max(1, N_CELLS/6) * 2		# How many 'offscreen' cells to draw because of the tilt angle. Defaults to 1/3, minimum of 2. Must be even.
const N_DRAWN_CELLS: int = N_CELLS + EXTRA_DRAWN  # Total n drawn cells including offscreen cells
var show_shapes: bool = true

# Initialise variables
var win_dim: Vector2		# dimensions of the window
var grid_length: float		# length (height and width) of the square grid
var cell_size: float		# length (height and width) of a single cell
var centre_point: Vector2	# centre-point of the entire grid
var grid_squares = []  # array over all squares

# --- MAIN FUNCTIONS ---
func _ready():
	# Seed the random seed generator with a unique value
	self.rotation_degrees = WORLD_ROTATION
	randomize()
	_update_viewport()

	# var previous_centres = Vector2()

	# Initialise grid_squares object
	for row in range(N_DRAWN_CELLS):
		grid_squares.append([])
		for col in range(N_DRAWN_CELLS):
			# Centre position never changes so we can initialise it
			# We use this to calculate the size of the square
			var position = Vector2(
				(col-EXTRA_DRAWN/2)*cell_size + cell_size/2,
				(row-EXTRA_DRAWN/2)*cell_size + cell_size/2
			)

			# if col >= 1:
			# 	if position[0] - previous_centres[0] - cell_size



			# Generate points RELATIVE to a centre of (0, 0) to pass in
			var points = gen_square_points(Vector2(cell_size, cell_size))

			# Initialise our grid square scene as a child and call the setup function
			var instance = GridSquareScene.instantiate()
			add_child(instance)
			instance.setup(
				Vector2i(row, col),
				position,
 				cell_size,
				points,
				pattern.textures
			)
			instance.square_clicked.connect(_on_grid_square_clicked)
			grid_squares[row].append(instance)

	# Generate the grid squares and semicircles and queue the first redraw of the scene
	_generate_grid_squares()
	_generate_shapes()
	queue_redraw()

func _on_grid_square_clicked(
	id: Vector2i,
	button_index
):
	var g = grid_squares[id[0]][id[1]]

	# Left clicks cycle through patterns
	if button_index == MOUSE_BUTTON_LEFT:
		g.current_pattern_idx = (g.current_pattern_idx + 1) % len(pattern.textures)

	# Right clicks cycle through the color of a line
	# So we have to get all the squares in that line
	elif button_index == MOUSE_BUTTON_RIGHT:
		for square in grid_squares[id[0]]:
			square.is_white = !square.is_white

	# Scrolling handles the rotation
	elif button_index == MOUSE_BUTTON_WHEEL_UP:
		g.orientation = fmod(g.orientation + 90, 360)
	elif button_index == MOUSE_BUTTON_WHEEL_DOWN:
		g.orientation = fmod(g.orientation - 90, 360)

	queue_redraw()

func _generate_grid_squares(
	gen_color: bool = true,
	gen_initial_patterns: bool = true,
	shapes_visible: bool = true,
):
	for row in range(N_DRAWN_CELLS):
		for col in range(N_DRAWN_CELLS):
			grid_squares[row][col].shape_visible = shapes_visible

	if gen_color:
		for row in range(N_DRAWN_CELLS):
			var is_white = randf() < P_IS_WHITE
			for col in range(N_DRAWN_CELLS):
				grid_squares[row][col].is_white = is_white
				
	if gen_initial_patterns:
		for row in range(N_DRAWN_CELLS):
			for col in range(N_DRAWN_CELLS):
				var grid_orientation = (int(randf()*4) * 90)
				var initial_pattern_idx = h.weighted_random(pattern.initial_probabilities)
				grid_squares[row][col].initial_pattern_idx = initial_pattern_idx
				grid_squares[row][col].orientation = grid_orientation

func _generate_shapes():
	# Draw all grid squares and patterns to the screen
	for row in range(N_DRAWN_CELLS):
		# Initialise counts array to keep track of pattern idxs in adjacent squares
		var counts = []
		counts.resize(len(pattern.textures))
		counts.fill(0)

		for col in range(N_DRAWN_CELLS):
			var g = grid_squares[row][col]

			# --- GENERATE NEW PATTERN IDK ---
			# The new pattern_name idx is determined by the three adjacent patterns in the row (x-1, x, x+1)
			# Increment the counts by the next pattern_idx if not at end of row, and decrement by outdated one if not at start
			if (col < N_DRAWN_CELLS - 1): counts[grid_squares[row][col+1].initial_pattern_idx] += 1
			if (col > 1): counts[grid_squares[row][col-2].initial_pattern_idx] -= 1

			# Update the current pattern_name idx of the grid square
			g.set_pattern(h.weighted_random(counts))

func _update_viewport():
	# Update the viewport if it has changed on every redraw
	var tmp_dim = get_viewport().get_visible_rect().size
	if win_dim != tmp_dim:
		win_dim = tmp_dim
		grid_length = min(win_dim.x, win_dim.y)
		cell_size = grid_length / N_CELLS

		# Update the buffer and centre
		centre_point = Vector2(grid_length/2, grid_length/2)

func _draw():
	_update_viewport()

# Handle inputs
# TODO SHIFT THROUGH PATTERNS ON LEFT CLICK, ROTATE ON RIGHT CLICK, LOCK ON MIDDLE? 
func _input(event):
	const LEGAL_KEYS = [KEY_S, KEY_P, KEY_R, KEY_H, KEY_C]

	if (event is InputEventKey) and (event.keycode in LEGAL_KEYS):
		# If S, reset the circle generation KEEPING THE SAME INITIAL PATTERN IDXS
		if event.keycode == KEY_S and event.is_pressed() and not event.is_echo():
			_generate_shapes()

		# If P, reset the circle generation WITH NEW PATTERN IDXs
		if event.keycode == KEY_P and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(false, true)
			_generate_shapes()

		# If C, reset just the background colors
		if event.keycode == KEY_C and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(true, false)

		# If R, reset everything
		if event.keycode == KEY_R and event.is_pressed() and not event.is_echo():
			_generate_grid_squares(true, true)
			_generate_shapes()

		# If H, toggle hide/show circles
		if event.keycode == KEY_H and event.is_pressed() and not event.is_echo():
			show_shapes = !show_shapes
			_generate_grid_squares(false, false, show_shapes)
		
		# Redraw no matter what
		queue_redraw()


# Shape drawing functions
func gen_square_points(
	dimensions: Vector2,
	centre: Vector2 = Vector2(0, 0),
):
	var points = [
		centre + Vector2(-dimensions.x/2, -dimensions.y/2),
		centre + Vector2(+dimensions.x/2, -dimensions.y/2),
		centre + Vector2(+dimensions.x/2, +dimensions.y/2),
		centre + Vector2(-dimensions.x/2, +dimensions.y/2),
	]

	# Rotate the points and return
	return points
