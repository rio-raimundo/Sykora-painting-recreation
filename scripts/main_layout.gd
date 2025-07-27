extends HBoxContainer

# Get a reference to the UI element we need to listen to.
@onready var rotation_slider: HSlider = $UIHolder/VBoxContainer/RotationSlider
@onready var cell_size_slider: HSlider = $UIHolder/VBoxContainer/CellSizeSlider

# Get a reference to the game object we need to control.
@onready var grid_handler: Node2D = $FrameHolder/SubViewportContainer/SubViewport/GridHandler


# We will add the connecting logic in the next step.
func _ready():
	_on_cell_size_slider_value_changed(cell_size_slider.value)  # pass initial value
	grid_handler.min_cell_size = cell_size_slider.min_value


func _on_rotation_slider_value_changed(value:float) -> void:
	grid_handler.rotation = deg_to_rad(value)

func _on_cell_size_slider_value_changed(value:float) -> void:
	grid_handler.cell_size = value
