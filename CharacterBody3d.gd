extends CharacterBody3D

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var collision_shape = $CollisionShape3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.001
const BOB_FREQ = 2.8
const BOB_AMP = 0.08
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

var t_bob = 0.0
var speed
var crouching = false
var crouch_transition_speed = 3.0  # The speed of transition for crouching/standing

# Store the original height of the collision shape and camera position
var original_collider_height = 2.0
var crouched_collider_height = 1.5
var original_camera_y = 0.0
var crouched_camera_y = -0.5

# Variable to store the current target state
var target_collider_height = 2.0
var target_camera_y = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	original_collider_height = (collision_shape.shape as CapsuleShape3D).height

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Toggle crouch when pressing the crouch button
	if Input.is_action_just_pressed("ui_crouch"):
		if is_on_floor():  # Only allow crouching if the character is on the floor
			crouching = !crouching
			_update_crouch()

	# Smoothly transition between crouch and stand
	_smooth_crouch_transition(delta)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump and cancel crouch when jumping.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		# Cancel crouch when jumping
		if crouching:
			crouching = false
			_update_crouch()
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_pressed("ui_sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
		
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _update_crouch():
	# Prevent crouching if the character is not on the floor
	if not is_on_floor() and crouching:
		crouching = false
		return
	
	# Update target height and camera position based on crouch state
	if crouching:
		target_collider_height = crouched_collider_height
		target_camera_y = crouched_camera_y
	else:
		target_collider_height = original_collider_height
		target_camera_y = original_camera_y

func _smooth_crouch_transition(delta):
	# Smoothly transition the collision shape height
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = lerp(shape.height, target_collider_height, delta * crouch_transition_speed)
	
	# Smoothly transition the camera position
	camera.transform.origin.y = lerp(camera.transform.origin.y, target_camera_y, delta * crouch_transition_speed)
