# STORES ALL OF THE OPTIONS FOR SHAPE PATTERNS
# Added as singleton
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