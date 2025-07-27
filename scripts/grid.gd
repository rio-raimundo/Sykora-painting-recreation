extends Node2D

# KIND OF A GUIDE ABOUT THIS FILE
# Because there are a lot of settings that can be changed, this code is pretty spaghetti rn
# This is my attempt to lay out the order of operations of how it works
# First, all of the assets in all of the files ready, and this file is passed references to the viewport size, minimum cell size, and starting cell size
# The viewport size and minimum cell size determine the maximum number of cells that will ever need to be on screen at once. 
# We initialise these cells in initialise_grid(), ONLY once. At this point they have no position or size.
# Then we take the cell size variable and calculate how many cells should be on screen right now. We sample that many cells from the MIDDLE of the pool using the vis_grid_starting_idxs getter, give those cells the correct position and size, and draw their attributes
# At this point, the first screen is shown. Here, the user can interact with it in a variety of ways, but there are two main levels:
#	1. Everything except cell size changes - pattern changes, rotations, colour changes do NOT need to redraw the square objects themselves
#	2. Changing the cell size DOES need to redraw everythign from scratch, but it still keeps the pool of squares that we use / does not affect patterns
# This means if you make the cell size very big and then back to the original size, the patterns will remain the same


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

var n_cells: Vector2i			# Number of cells to draw on screen. Determined dynamically by cell and viewport size
var max_n_cells: Vector2i		# The maximum number of cells stored in the pool
var grid_dim: Vector2			# Dimensions of the visible cell grid
var grid_origin: Vector2		# Top left corner of the visible cell grid. Calculated so grid centre is at (0,0)

var grid_pool = []		# 2D Array of all GridSquareScene objects that could be drawn
var visible_grid = []	# 2D Array of GridSquareScene object references to be drawn to the viewport


# --- INITIALISE GETTERS AND SETTERS ---
# Length (height and width) of a cell (px)
var cell_size: float:
	set(val):
		cell_size = val
		_update_grid()

# Minimum cell size that it is possible to set using the slider.
# Used to calculate total number of grid square objects to initialise
# This setter will typically only be called once when the project initialises.
var min_cell_size: float:
	set(val):
		min_cell_size = val
		_update_grid()

# Size of the nearest viewport or subviewport
var viewport_size: Vector2:
	set(val):
		viewport_size = val
		_update_grid()

# Starting index (row, col) of the visible cell grid, within the global grid (i.e. the pool)
var vis_grid_starting_idxs: Vector2i:
	get(): return (max_n_cells - n_cells) / 2

# --- GENERATION FUNCTIONS ---
# Initialise the pool of grid squares if not already initialised, and redraw the visible grid if cell size changes 
# Returns unless (viewport, minimum cell size & cell size) are initialised (not at default values)
# TODO neaten this function, it's pretty messy / badly documented
func _update_grid():
	# Return if all have not been initialised
	if (min_cell_size <= 0) or (viewport_size.x <= 2 or viewport_size.y <= 2) or (cell_size <= 0): return

	# We want to calculate number of cells as (rows, cols), so first we swap viewport coords (which are x,y)
	var viewport_rc = Vector2(viewport_size[1], viewport_size[0])
	# To convert, we want to know how many squares would fill the DIAGONAL of our viewport, since this will allow any rotation without gaps

	# We want n_cells and max_n_cells to be even to keep the centre in the same point (could also both be odd)
	n_cells = _make_even_ceil(sqrt(2) * viewport_rc / cell_size)
	grid_dim = Vector2(n_cells[1], n_cells[0]) * cell_size

	# Initialise the grid pool if it hasn't been yet
	# Currently this can only happen once, meaning the viewport and min_cell_size can't change after initialisation!
	if grid_pool.is_empty(): _initialise_grid_pool()

	# Redraw the visible grid but don't update the shapes?
	_update_visible_grid()
	_update_grid_squares(true, true, false)  # update only squares which have NOT had shapes initialised

func _initialise_grid_pool():
	# Figure out what the maximum number of squares that we might need is and save them in the pool
	# We want to calculate number of cells as (rows, cols), so first we swap viewport coords (which are x,y)
	var viewport_rc = Vector2(viewport_size[1], viewport_size[0])
	max_n_cells = _make_even_ceil(sqrt(2) * viewport_rc / min_cell_size)

	# With min cell size of 10, this is 128r * 136c  = 17000. Try it and see? Might have to adjust minimum cell size
	# Initialise the cell pool
	grid_pool = []  # reset the pool
	for row in max_n_cells[0]:
		grid_pool.append([])
		
		for col in max_n_cells[1]:
			var instance = GridSquareScene.instantiate()
			add_child(instance)
			instance.setup(
				Vector2i(row, col),   # ID for the square
				pattern_map.textures  # references to texture options to draw
			)
			instance.square_clicked.connect(_on_grid_square_clicked)
			grid_pool[row].append(instance)



func _ready():
	# Seed the random seed generator with a unique value
	randomize()

	# Establish a signal to keep local variable updated with current viewport size, then call it with initial vport size
	var update_viewport_size = func(): self.viewport_size = get_viewport().size
	viewport.size_changed.connect(update_viewport_size)
	update_viewport_size.call()


# Should be called whenever the cell_size changes! 
func _update_visible_grid():
	# Initialise the positions and sizes of the visible grid
	visible_grid = []

	# Points are relative to (0, 0) so they are the same for all squares
	var points = gen_rectangle_points(Vector2(cell_size, cell_size))

	# Loop through the pool from the vis starting idx
	for row in range(n_cells[0]):
		visible_grid.append([])
		var x0 = vis_grid_starting_idxs[0]
		for col in range(n_cells[1]):
			var y0 = vis_grid_starting_idxs[1]

			# Chuck reference to grid square into our visible_grid array
			visible_grid[row].append(grid_pool[x0+row][y0+col])

			# Calculate the position for this square
			var position = (Vector2(col+0.5, row+0.5))  * cell_size - (grid_dim/2)

			# Assign position, points and size to our GridSquare
			visible_grid[row][col].resize(points, position, cell_size)


# Function to update the grid squares, with a lot of options. Currently a bit multipurpose and awkward
func _update_grid_squares(
	gen_color: bool = false,
	gen_initial_patterns: bool = false,
	re_initialise: bool = true,
):
	for row in range(n_cells[0]):
		for col in range(n_cells[1]):
			var g = visible_grid[row][col]
			if !re_initialise and g.pattern_initialised: continue
			g.pattern_initialised = true  # initialise upon first call to this function

			# Handle initial pattern generation
			if gen_initial_patterns:
				g.initial_pattern_idx = h.weighted_random(pattern_map.initial_probabilities)
				g.orientation = (int(randf()*4) * 90)
				g.set_pattern(g.initial_pattern_idx)

		# Colors are determiend per row
		if gen_color:
			var is_white = randf() < P_IS_WHITE
			for col in range(max_n_cells[1]): grid_pool[vis_grid_starting_idxs[0]+row][col].is_white = is_white

func _toggle_shape_visibility(shapes_visible: bool):
	for row in vis_grid_starting_idxs[0]:
		for col in vis_grid_starting_idxs[1]:
			grid_pool[row][col].shape_visible = shapes_visible


# --- SIGNAL FUNCTIONS ---
# Handles clicks to grid squares, passing through the unique ID of the square and the index of the button press
func _on_grid_square_clicked(
	id: Vector2i,
	button_index
):
	var g = grid_pool[id[0]][id[1]]  # id is unique to all grids in the entire pool

	# Left clicks cycle through patterns
	if button_index == MOUSE_BUTTON_LEFT:
		g.current_pattern_idx = (g.current_pattern_idx + 1) % len(pattern_map.textures)

	# Right clicks cycle through the color of a line
	# So we have to get all the squares in that line
	elif button_index == MOUSE_BUTTON_RIGHT:
		for square in visible_grid[id[0] - vis_grid_starting_idxs[0]]:
			square.is_white = !square.is_white

	# Scrolling handles the rotation
	elif button_index == MOUSE_BUTTON_WHEEL_UP:
		g.orientation = fmod(g.orientation + 90, 360)
	elif button_index == MOUSE_BUTTON_WHEEL_DOWN:
		g.orientation = fmod(g.orientation - 90, 360)

	queue_redraw()

# Handles key press inputs and their effects on the game world
func _input(event):
	const LEGAL_KEYS = [KEY_P, KEY_R, KEY_H, KEY_C]

	if (event is InputEventKey) and (event.keycode in LEGAL_KEYS):
		# If P, reset the circle generation WITH NEW PATTERN IDXs
		if event.keycode == KEY_P and event.is_pressed() and not event.is_echo():
			_update_grid_squares(false, true)

		# If C, reset just the background colors
		if event.keycode == KEY_C and event.is_pressed() and not event.is_echo():
			_update_grid_squares(true)

		# If R, reset everything
		if event.keycode == KEY_R and event.is_pressed() and not event.is_echo():
			_update_grid_squares(true, true)

		# If H, toggle hide/show circles
		if event.keycode == KEY_H and event.is_pressed() and not event.is_echo():
			show_shapes = !show_shapes
			_toggle_shape_visibility(show_shapes)
		
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

# Convert a float into the nearest larger even integer
func _make_even_ceil(x: Vector2): return Vector2i(ceil(x/2) * 2)
