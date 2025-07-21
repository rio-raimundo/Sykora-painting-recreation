# STORES ALL OF THE OPTIONS FOR SHAPE PATTERNS
# https://diplomkyavu.cz/en/2019/martina-salonova new pattern (triangles?)
extends Node2D

const BASE_PATH = "res://assets/shapes/"

# --- INITIALISE CLASSES TO HELP WITH PATTERN GENERATION ---
# Class of legal PatternNames, for reference
class PatternNames:
	const SEMICIRCLES = "semicircles"
	const TRIANGLES1 = "triangles-1"

# Dictionary of pattern classes: call with Patterns[PatternNames.SEMICIRCLES], etc.
var Patterns = {
	PatternNames.SEMICIRCLES: Pattern.new(
		[0.5, 0.1, 0.2, 0.2],
		load_patterns_from_folder(PatternNames.SEMICIRCLES)
	),
	PatternNames.TRIANGLES1: Pattern.new(
		[0.3, 0.4, 0.3],
		load_patterns_from_folder(PatternNames.TRIANGLES1)
	),
}



# --- HELPER METHODS ---
class Pattern:
	var initial_probabilities: Array
	var textures: Array

	func _init(initial_probabilities: Array, textures: Array):
		self.initial_probabilities = initial_probabilities
		self.textures = textures

# Helper function to load all texture files under a folder with given pattern name in BASE_PATH/pattern_name
func load_patterns_from_folder(pattern_name: String):
	var textures = []
	var path = BASE_PATH.path_join(pattern_name)

	var dir = DirAccess.open(path)
	if !dir: print("An error occurred when trying to access the specified directory"); return textures

	dir.list_dir_begin()
	var filename = dir.get_next()
	while filename != "":
		if !dir.current_is_dir() and filename.ends_with(".png"):
			textures.append(load(path.path_join(filename)))
		filename = dir.get_next()

	return textures






# # --- SEMICIRCLE GENERATION ---
# func _handle_semicircles():
# 	# We initialise variables related to the drawing of semicircle patterns here
# 	const N_PATTERNS = 4
# 	const STARTING_PROBABILITIES = [0.5, 0.1, 0.2, 0.2]
# 	const N_SEGMENTS = 32

# 	# The only argument to our draw function can be the grid square instance g
# 	# Because we also have a defined number of segments, we will wrap the draw_semicircle_pattern function so the only argument is g
# 	var _draw_pattern = func(node, g: GridSquare, world_rotation): _draw_semicircle_pattern(node, g, world_rotation, N_SEGMENTS)
# 	return Pattern.new(N_PATTERNS, STARTING_PROBABILITIES, _draw_pattern)


""" Works by drawing one of the two semicircle patterns. """ 
# func _draw_semicircle_pattern(node, g: GridSquare, world_rotation, n_segments_to_draw: int):

# 	# Assign the rotations
# 	var sc_centres
# 	var sc_rotations

# 	match g.current_pattern_idx:
# 		0:
# 			sc_centres = [g.position + Vector2(0, 0.25*g.size)]
# 			sc_rotations = [PI]  # needs to be PI to be against edge, not entirely sure why
# 		1:
# 			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
# 			sc_rotations = [PI, PI]
# 		2:
# 			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
# 			sc_rotations = [0, PI]
# 		3:
# 			sc_centres = [g.position - Vector2(0, 0.25*g.size), g.position + Vector2(0, 0.25*g.size)]
# 			sc_rotations = [PI, 0]

# 	for sc_idx in range(len(sc_centres)):
# 		var points = _gen_semicircle_points(sc_centres[sc_idx], g.size/2, sc_rotations[sc_idx], n_segments_to_draw)

# 		# Rotate around the centre of the SQUARE by the base rotation
# 		for idx in range(len(points)): points[idx] = Helpers.rotate_by(points[idx], g.orientation + world_rotation, g.position)
# 		node.draw_colored_polygon(points, Helpers.to_color(!g.is_white))

# func _gen_semicircle_points(
# 	centre: Vector2,
# 	radius: float,
# 	orientation: float,
# 	n_segments: int
# ):
# 	var circle_centre = centre - Vector2(0, 0.25*radius*2)
# 	var points = []

# 	# Divide pi degrees into s segments, draw over half a circle
# 	for i in range(n_segments + 1):
# 		var angle = PI * i / n_segments  # 0 to π
# 		var base_point = circle_centre + Vector2(cos(angle), sin(angle)) * radius

# 		# Rotate the point by the given orientation
# 		points.append(Helpers.rotate_by(base_point, orientation, centre))
	
# 	return points
