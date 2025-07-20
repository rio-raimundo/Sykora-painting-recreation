extends Node2D

# Initialise variables
var is_white: bool
var initial_pattern_idx: int

var orientation: float = 0.0
var current_pattern_idx: int = 0

func setup(
	position: Vector2,
	is_white: bool = false,
	initial_pattern_idx: int = 0,
	orientation: float = 0,
):
	self.position = position
	self.is_white = is_white
	self.initial_pattern_idx = initial_pattern_idx
	self.orientation = orientation
