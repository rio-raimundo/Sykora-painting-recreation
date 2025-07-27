extends Node2D

# --- INITIALISE VARIABLES ---
# Manually declared variables
# length (height and width) of a cell (px)
var cell_size: float:
	set(new_value):
		cell_size = new_value
		_generate_all()
	get:
		return cell_size

const WORLD_ROTATION: float = 0
const N_SEMICIRCLE_SEGMENTS: int = 64
const P_IS_WHITE = 0.5  # probability that a given row's background color is white

const GridSquareScene = preload("res://scenes/grid_square.tscn")
var h = Helpers

# Load in class for specified pattern
# Each class contains an array of starting probabilities and an array of textures, which are passed through to the GridSquares instances
# Current available patterns can be found by querying PatternsList.PatternNames
var pattern = PatternsList.Patterns[PatternsList.PatternNames.SEMICIRCLES]

# Initialise variables
var viewport_size
var show_shapes = true
var cell_dim: Vector2 = Vector2(cell_size, cell_size)
var n_cells: Vector2
var grid_dimensions: Vector2
var origin: Vector2
var grid_squares = []
var min_cell_size  # initialised in main_layout by the minimum value of the cell_size slider

# Handle varaible initialisations that require ready
@onready var viewport: Viewport = get_viewport()

# --- MAIN FUNCTIONS ---
func _ready():
	# Seed the random seed generator with a unique value
	randomize()

	# We establish a signal to execute when the viewport size is changed.
	viewport.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()  # Handle drawing everything

	print('minimum cell size = ', min_cell_size)


func _on_viewport_size_changed():
	# Here we update variables
	viewport_size = get_viewport().size

	# We want to calculate number of cells as (rows, cols), so first we swap viewport coords (which are x,y)
	var viewport_rc = Vector2(viewport_size[1], viewport_size[0])
	# To convert, we want to know how many squares would fill the DIAGONAL of our viewport, since this will allow any rotation without gaps
	n_cells = ceil(sqrt(2) * viewport_rc / cell_size)

	# Origin is the centrepoint of the viewport minus the centre_point of the grid
	grid_dimensions = Vector2(n_cells[1], n_cells[0]) * cell_size
	_generate_all()

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

func _generate_all():
	_generate_grid_squares()
	_generate_grid_square_attributes()
	_generate_shapes()
	queue_redraw()

func _generate_grid_squares():
	# Points are relative to (0, 0) so they are the same for all squares
	grid_squares = []
	var points = gen_square_points(cell_dim)

	# Initialise grid_squares object
	for row in range(n_cells[0]):  # rows, so y
		grid_squares.append([])
		for col in range(n_cells[1]):  # cols, so x
			# Calculate the position for this square
			var position = (Vector2(col+0.5, row+0.5))  * cell_size - (grid_dimensions/2)
			
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


func _generate_grid_square_attributes(
	gen_color: bool = true,
	gen_initial_patterns: bool = true,
	shapes_visible: bool = true,
):
	for row in range(n_cells[0]):
		for col in range(n_cells[1]):
			grid_squares[row][col].shape_visible = shapes_visible

	if gen_color:
		for row in range(n_cells[0]):
			var is_white = randf() < P_IS_WHITE
			for col in range(n_cells[1]):
				grid_squares[row][col].is_white = is_white
				
	if gen_initial_patterns:
		for row in range(n_cells[0]):
			for col in range(n_cells[1]):
				var grid_orientation = (int(randf()*4) * 90)
				var initial_pattern_idx = h.weighted_random(pattern.initial_probabilities)
				grid_squares[row][col].initial_pattern_idx = initial_pattern_idx
				grid_squares[row][col].orientation = grid_orientation

func _generate_shapes():
	# Draw patterns using a weighted random of the surrounding initial patterns
	for row in range(n_cells[0]):
		# Initialise counts array to keep track of pattern idxs in adjacent squares
		var counts = []
		counts.resize(len(pattern.textures))
		counts.fill(0)

		# Start with the first pattern in the row
		counts[grid_squares[row][0].initial_pattern_idx] += 1
		for col in range(n_cells[1]):
			var g = grid_squares[row][col]

			# --- GENERATE NEW PATTERN IDK ---
			# The new pattern_name idx is determined by the three adjacent patterns in the row (x-1, x, x+1)
			# Increment the counts by the next pattern_idx if not at end of row, and decrement by outdated one if not at start
			if (col < n_cells[1] - 1): counts[grid_squares[row][col+1].initial_pattern_idx] += 1
			if (col > 1): counts[grid_squares[row][col-2].initial_pattern_idx] -= 1

			# Update the current pattern_name idx of the grid square
			g.set_pattern(h.weighted_random(counts))

func _draw():
	pass

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
			_generate_grid_square_attributes(false, true)
			_generate_shapes()

		# If C, reset just the background colors
		if event.keycode == KEY_C and event.is_pressed() and not event.is_echo():
			_generate_grid_square_attributes(true, false)

		# If R, reset everything
		if event.keycode == KEY_R and event.is_pressed() and not event.is_echo():
			_generate_grid_square_attributes(true, true)
			_generate_shapes()

		# If H, toggle hide/show circles
		if event.keycode == KEY_H and event.is_pressed() and not event.is_echo():
			show_shapes = !show_shapes
			_generate_grid_square_attributes(false, false, show_shapes)
		
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
