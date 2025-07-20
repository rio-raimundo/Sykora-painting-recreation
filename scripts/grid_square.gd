extends Area2D

# Not sure exactly how this works yet
signal square_clicked(id: Vector2i)


# Initialise variables
var shape: ConvexPolygonShape2D

# Position is a default property of Area2D so no need to redefine it
var id: Vector2i
var points: PackedVector2Array
var is_white: bool
var initial_pattern_idx: int

var orientation: float = 0.0
var current_pattern_idx: int = 0

func setup(
	id: Vector2i,
	position: Vector2,
	points: PackedVector2Array,
	is_white: bool = false,
	initial_pattern_idx: int = 0,
	orientation: float = 0,
):
	self.id = id
	self.position = position
	self.is_white = is_white
	self.initial_pattern_idx = initial_pattern_idx
	self.orientation = orientation

	# Get absolute points for self
	var abs_points = []
	for point in points: abs_points.append(point + position)
	self.points = abs_points

	# Initialise collision bounding box using points
	shape = ConvexPolygonShape2D.new()
	shape.points = points  # shape.points is RELATIVE
	$CollisionShape2D.shape = shape

# This function has been linked with a 'signal' to respond to input events for that object
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		square_clicked.emit(self.id)
