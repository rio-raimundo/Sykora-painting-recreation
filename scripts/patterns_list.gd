# STORES ALL OF THE OPTIONS FOR SHAPE PATTERNS
extends Node2D

class PatternNames:
	const SEMICIRCLES = 0
	const TRIANGLES = 1

class Pattern:
	var N_PATTERNS: int
	var STARTING_PROBABILITIES: Array
	var draw_pattern_callable: Callable

	func _init(N_PATTERNS: int, STARTING_PROBABILITES: Array, draw_pattern: Callable):
		self.N_PATTERNS = N_PATTERNS
		self.STARTING_PROBABILITIES = STARTING_PROBABILITES
		self.draw_pattern_callable = draw_pattern

	# Draw pattern argument should always just take in the drawing node (to draw to the right node) and grid square instance
	func draw_pattern(node, g: GridSquare, world_rotation): self.draw_pattern_callable.call(node, g, world_rotation)

func return_pattern(pattern_name: int):
	# All patterns must return a Pattern object
	if pattern_name == PatternNames.SEMICIRCLES: return _handle_semicircles()



# --- SEMICIRCLE GENERATION ---
func _handle_semicircles():
	# We initialise variables related to the drawing of semicircle patterns here
	const N_PATTERNS = 4
	const STARTING_PROBABILITIES = [0.5, 0.1, 0.2, 0.2]
	const N_SEGMENTS = 32

	# The only argument to our draw function can be the grid square instance g
	# Because we also have a defined number of segments, we will wrap the draw_semicircle_pattern function so the only argument is g
	var _draw_pattern = func(node, g: GridSquare, world_rotation): _draw_semicircle_pattern(node, g, world_rotation, N_SEGMENTS)
	return Pattern.new(N_PATTERNS, STARTING_PROBABILITIES, _draw_pattern)


""" Works by drawing one of the two semicircle patterns. """ 
func _draw_semicircle_pattern(node, g: GridSquare, world_rotation, n_segments_to_draw: int):

	# Assign the rotations
	var sc_centres
	var sc_rotations

	match g.current_pattern_idx:
		0:
			sc_centres = [g.position + Vector2(0, 0.25*g.size)]
			sc_rotations = [PI]  # needs to be PI to be against edge, not entirely sure why
		1:
			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
			sc_rotations = [PI, PI]
		2:
			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
			sc_rotations = [0, PI]
		3:
			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
			sc_rotations = [PI, 0]

	for sc_idx in range(len(sc_centres)):
		var points = _gen_semicircle_points(sc_centres[sc_idx], g.size/2, sc_rotations[sc_idx], n_segments_to_draw)

		# Rotate around the centre of the SQUARE by the base rotation
		for idx in range(len(points)): points[idx] = Helpers.rotate_by(points[idx], g.orientation + world_rotation, g.position)
		node.draw_colored_polygon(points, Helpers.to_color(!g.is_white))

func _gen_semicircle_points(
	centre: Vector2,
	radius: float,
	orientation: float,
	n_segments: int
):
	var circle_centre = centre - Vector2(0, 0.25*radius*2)
	var points = []

	# Divide pi degrees into s segments, draw over half a circle
	for i in range(n_segments + 1):
		var angle = PI * i / n_segments  # 0 to π
		var base_point = circle_centre + Vector2(cos(angle), sin(angle)) * radius

		# Rotate the point by the given orientation
		points.append(Helpers.rotate_by(base_point, orientation, centre))
	
	return points
