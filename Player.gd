extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var input =Input.get_action_strength("ui_up")
	apply_central_force(input * Vector3.Foward * 1200.0 * delta)
