extends HBoxContainer

# Get a reference to the UI element we need to listen to.
@onready var rotation_slider: HSlider = $UIHolder/VBoxContainer/RotationSlider

# Get a reference to the game object we need to control.
@onready var grid_handler: Node2D = $FrameHolder/SubViewportContainer/SubViewport/GridHandler


# We will add the connecting logic in the next step.
func _ready():
	pass

func _on_rotation_slider_value_changed(value:float) -> void:
	grid_handler.rotation = deg_to_rad(value)
