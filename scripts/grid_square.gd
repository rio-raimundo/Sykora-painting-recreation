class_name GridSquare
extends Area2D

# Not sure exactly how this works yet
signal square_clicked(id: Vector2i, button_index)

@onready var sprite: Sprite2D = $Sprite2D
@onready var rect: ColorRect = $ColorRect
@onready var bb: CollisionShape2D = $CollisionShape2D


# Initialise variables
# Position is a default property of Area2D so no need to redefine it
var id: Vector2i
var textures: Array

var points: PackedVector2Array:
	set(val):
		bb.shape.points = val  # update collision bounding box
		points = val  # maybe don't even need this? helps for accessing i guess

var pattern_initialised  # whether the pattern for this square has ever been rendered
var size: float
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
var shape_visible: bool = true:
	set(val):
		shape_visible = val
		if sprite: sprite.visible = val

func setup(
	# Identifiers
	id: Vector2i, 						# unique ID for the grid square
	textures: Array,					# reference to the array of textures used to generate the pattern
):
	self.id = id
	self.textures = textures

	# Initialise collision bounding box using points
	bb.shape = ConvexPolygonShape2D.new()

# Should be called to resize the square.
# NOTE: this is currently the only way to resize it - adjusting variables manually WILL NOT WORK because it will not resize rect or sprite.
# TODO maybe change this by integrating with setters more closely in the future.
# UPDATE: Patterns can now be resized by calling set pattern function directly.
func resize(points: PackedVector2Array, position: Vector2, size: int):
	self.points = points
	self.position = position
	self.size = size

	# Update rect and pattern sizes
	_resize_rect()
	_resize_pattern()

# Update the background rectangle size
func _resize_rect():
	rect.size = Vector2(self.size, self.size)
	rect.position = (-rect.size / 2.0).round()

func set_pattern(pattern_idx: int):
	if !sprite: return
	self.sprite.texture = self.textures[pattern_idx]
	_resize_pattern()

func _resize_pattern():
	if !sprite or !sprite.texture: return

	# Update the sprite parameters
	# This stops the infuriating anti-aliasing effect by basically putting the sprite RIGHT in the middle of the color rect
	# TODO look at this at some point cods I bet you can neaten it, but for now I'm going to bed
	var texture_size = sprite.texture.get_size()
	var target_rect = rect.get_rect()
	sprite.scale = Vector2(
		target_rect.size.x / texture_size.x,
		target_rect.size.y / texture_size.y
	)
	self.sprite.position = (target_rect.position + target_rect.size / 2.0)
	self.sprite.scale = Vector2(self.size / texture_size.x, self.size / texture_size.y)  # make sure the sprite fits in the grid perfectly


# This function has been linked with a 'signal' to respond to input events for that object
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		square_clicked.emit(self.id, event.button_index)
