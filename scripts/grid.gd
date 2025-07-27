extends Node2D

# --- INITIALISE OBJECT AND SCRIPT REFERENCES ---
@onready var viewport: Viewport = get_viewport()
const GridSquareScene = preload("res://scenes/grid_square.tscn")
var h = Helpers

# Load in the pattern map to draw (logic in PatternsList file)
# Options at time of writing = [TRIANGLES1, SEMICIRCLES]
var pattern_map = PatternsList.Patterns[PatternsList.PatternNames.SEMICIRCLES]


# --- INITIALISE VARIABLES ---
const P_IS_WHITE = 0.5			# Starting probability that a given row's background color is white
var show_shapes = true			# Whether shapes should be draw. starts as true, can be changed via UI

var n_cells: Vector2			# Number of cells to draw on screen. Determined dynamically by cell and viewport size
var grid_dim: Vector2			# Dimensions of the cell grid
var grid_origin: Vector2		# Top left corner of the cell grid. Calculated so grid centre is at (0,0)

var grid_squares_pool = []		# 2D Array of all GridSquareScene objects that could be drawn
var active_grid_squares = []	# 2D Array of GridSquareScene object references to be drawn to the viewport


# --- INITIALISE GETTERS AND SETTERS ---
# Length (height and width) of a cell (px)
var cell_size: float:
	set(val):
		cell_size = val

# Minimum cell size that it is possible to set using the slider.
# Used to calculate total number of grid square objects to initialise
# This setter will typically only be called once when the project initialises.
var min_cell_size: float:
	set(val):
		min_cell_size = val
		_initialise_grid()

# Size of the nearest viewport or subviewport
var viewport_size: Vector2:
	set(val):
		# When viewport size is changed, we re-render everything. Does not affect window resizes.
		viewport_size = val

		# We want to calculate number of cells as (rows, cols), so first we swap viewport coords (which are x,y)
		var viewport_rc = Vector2(viewport_size[1], viewport_size[0])
		# To convert, we want to know how many squares would fill the DIAGONAL of our viewport, since this will allow any rotation without gaps
		n_cells = ceil(sqrt(2) * viewport_rc / cell_size)

		# Origin is the centrepoint of the viewport minus the centre_point of the grid
		grid_dim = Vector2(n_cells[1], n_cells[0]) * cell_size
		_initialise_grid()


# --- GENERATION FUNCTIONS ---
# This function relies on having both the size of the viewport AND the minimum cell size, so it will not run if either has not been initialised.
# It is designed to run once at the end of the ready phase for all necessary objects.
func _initialise_grid():
	# Slight botch, return if no cell size or the viewport size is not bigger than the default of 2px
	if min_cell_size <= 0 or viewport_size.x <= 2 or viewport_size.y <= 2: return

	# # Figure out what the maximum number of squares that we might need is and save them in the pool
	# # We want to calculate number of cells as (rows, cols), so first we swap viewport coords (which are x,y)
	# var viewport_rc = Vector2(viewport_size[1], viewport_size[0])
	# var max_n_cells = ceil(sqrt(2) * viewport_rc / min_cell_size)

	# # With min cell size of 10, this is 128r * 136c  = 17000. Try it and see? Might have to adjust minimum cell size
	# # Initialise the cell pool
	# grid_squares_pool = []  # reset the pool
	# for row in max_n_cells[0]:
	# 	grid_squares_pool.append([])
		
	# 	for col in max_n_cells[1]:
	# 		var instance = GridSquareScene.instantiate()
	# 		add_child(instance)
	# 		instance.setup(
	# 			Vector2i(row, col),   # ID for the square
	# 			pattern_map.textures  # references to texture options to draw
	# 		)
	# 		instance.square_clicked.connect(_on_grid_square_clicked)
	# 		grid_squares_pool[row].append(instance)

	_generate_all()



func _ready():
	# Seed the random seed generator with a unique value
	randomize()

	# Establish a signal to keep local variable updated with current viewport size, then call it with initial vport size
	var update_viewport_size = func(): self.viewport_size = get_viewport().size
	viewport.size_changed.connect(update_viewport_size)
	update_viewport_size.call()


func _generate_all():
	_generate_grid_squares()
	_generate_grid_square_attributes()
	_generate_shapes()
	queue_redraw()

func _generate_grid_squares():
	# Points are relative to (0, 0) so they are the same for all squares
	active_grid_squares = []
	var points = gen_rectangle_points(Vector2(cell_size, cell_size))

	# Initialise active_grid_squares object
	for row in range(n_cells[0]):  # rows, so y
		active_grid_squares.append([])
		for col in range(n_cells[1]):  # cols, so x
			# Calculate the position for this square
			var position = (Vector2(col+0.5, row+0.5))  * cell_size - (grid_dim/2)
			
			# Initialise our grid square scene as a child and call the setup function
			var instance = GridSquareScene.instantiate()
			add_child(instance)
			instance.setup(
				Vector2i(row, col),
				pattern_map.textures,
				
				position,
 				cell_size,
				points,
			)
			instance.square_clicked.connect(_on_grid_square_clicked)
			active_grid_squares[row].append(instance)


func _generate_grid_square_attributes(
	gen_color: bool = true,
	gen_initial_patterns: bool = true,
	shapes_visible: bool = true,
):
	for row in range(n_cells[0]):
		for col in range(n_cells[1]):
			active_grid_squares[row][col].shape_visible = shapes_visible

	if gen_color:
		for row in range(n_cells[0]):
			var is_white = randf() < P_IS_WHITE
			for col in range(n_cells[1]):
				active_grid_squares[row][col].is_white = is_white
				
	if gen_initial_patterns:
		for row in range(n_cells[0]):
			for col in range(n_cells[1]):
				var grid_orientation = (int(randf()*4) * 90)
				var initial_pattern_idx = h.weighted_random(pattern_map.initial_probabilities)
				active_grid_squares[row][col].initial_pattern_idx = initial_pattern_idx
				active_grid_squares[row][col].orientation = grid_orientation

func _generate_shapes():
	# Draw patterns using a weighted random of the surrounding initial patterns
	for row in range(n_cells[0]):
		# Initialise counts array to keep track of pattern_map idxs in adjacent squares
		var counts = []
		counts.resize(len(pattern_map.textures))
		counts.fill(0)

		# Start with the first pattern_map in the row
		counts[active_grid_squares[row][0].initial_pattern_idx] += 1
		for col in range(n_cells[1]):
			var g = active_grid_squares[row][col]

			# --- GENERATE NEW PATTERN IDK ---
			# The new pattern_name idx is determined by the three adjacent patterns in the row (x-1, x, x+1)
			# Increment the counts by the next pattern_idx if not at end of row, and decrement by outdated one if not at start
			if (col < n_cells[1] - 1): counts[active_grid_squares[row][col+1].initial_pattern_idx] += 1
			if (col > 1): counts[active_grid_squares[row][col-2].initial_pattern_idx] -= 1

			# Update the current pattern_name idx of the grid square
			g.set_pattern(h.weighted_random(counts))


# --- SIGNAL FUNCTIONS ---
# Handles clicks to grid squares, passing through the unique ID of the square and the index of the button press
func _on_grid_square_clicked(
	id: Vector2i,
	button_index
):
	var g = active_grid_squares[id[0]][id[1]]

	# Left clicks cycle through patterns
	if button_index == MOUSE_BUTTON_LEFT:
		g.current_pattern_idx = (g.current_pattern_idx + 1) % len(pattern_map.textures)

	# Right clicks cycle through the color of a line
	# So we have to get all the squares in that line
	elif button_index == MOUSE_BUTTON_RIGHT:
		for square in active_grid_squares[id[0]]:
			square.is_white = !square.is_white

	# Scrolling handles the rotation
	elif button_index == MOUSE_BUTTON_WHEEL_UP:
		g.orientation = fmod(g.orientation + 90, 360)
	elif button_index == MOUSE_BUTTON_WHEEL_DOWN:
		g.orientation = fmod(g.orientation - 90, 360)

	queue_redraw()

# Handles key press inputs and their effects on the game world
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


# --- HELPER FUNCTIONS ---
# Generate the points of a rectangle with given dimensions and centre at (0,0)
# TODO maybe move this to helpers?
func gen_rectangle_points(dimensions: Vector2):
	return [
		Vector2(-dimensions.x/2, -dimensions.y/2),
		Vector2(+dimensions.x/2, -dimensions.y/2),
		Vector2(+dimensions.x/2, +dimensions.y/2),
		Vector2(-dimensions.x/2, +dimensions.y/2),
	]
