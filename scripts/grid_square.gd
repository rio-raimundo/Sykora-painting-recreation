class_name GridSquare
extends Area2D

# Not sure exactly how this works yet
signal square_clicked(id: Vector2i, button_index)

@onready var sprite: Sprite2D = $Sprite2D
@onready var rect: ColorRect = $ColorRect
@onready var bb: CollisionShape2D = $CollisionShape2D


# Initialise variables
var shape: ConvexPolygonShape2D

# Position is a default property of Area2D so no need to redefine it
var id: Vector2i
var points: PackedVector2Array
var size: float
var textures: Array

var initial_pattern_idx: int
var current_pattern_idx: int:
	set(val):
		current_pattern_idx = val
		set_pattern(val)
var orientation: float:
	set(val):
		orientation = val
		if sprite: sprite.rotation_degrees = orientation
var is_white: bool = false:
	set(val):
		is_white = val
		if rect: rect.color = Color(is_white, is_white, is_white)
		if sprite: sprite.modulate = Color(!is_white, !is_white, !is_white)

func setup(
	# Identifiers
	id: Vector2i, 						# unique ID for the grid square
	position: Vector2,					# position of the centre of the square (pixels, I think)
	size: float,						# size of one side of the square (pixels, I think?)
	points: PackedVector2Array, 		# IMPORTANT: These points must be relative to (0,0), not the world position.
	
	textures: Array,					# reference to the array of textures used to generate the pattern
):
	self.id = id
	self.position = position
	self.size = size
	self.points = points
	self.textures = textures

	# Initialise the background rectangle
	rect.size = Vector2(self.size, self.size)
	rect.position = -rect.size / 2.0

	# Initialise collision bounding box using points
	self.shape = ConvexPolygonShape2D.new()
	self.shape.points = points  # shape.points is RELATIVE
	bb.shape = shape

func set_pattern(pattern_idx: int):
	if !sprite: return
	self.sprite.texture = self.textures[pattern_idx]

	var texture_size = self.sprite.texture.get_size()
	self.sprite.scale = Vector2(self.size / texture_size.x, self.size / texture_size.y)  # make sure the sprite fits in the grid perfectly


# This function has been linked with a 'signal' to respond to input events for that object
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		square_clicked.emit(self.id, event.button_index)
