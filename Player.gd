extends RigidBody3D

enum MovementState { STANDING, CROUCHING, SPRINTING, SLIDING }

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot
@onready var collision_shape := $CollisionShape3D

var jump_impulse = Vector3(0, 8, 0)  # Impulse applied when jumping
var is_on_ground = false
var air_control_factor = 0.2  # Increased air control for better maneuverability
var max_air_speed = 10.0  # Maximum speed allowed in the air
var normal_speed = 600.0  # Normal movement speed
var crouch_speed = 300.0  # Speed when crouching
var sprint_speed = 1200.0  # Sprint speed
var sprint_duration = 5.0  # Duration of sprint
var sprint_cooldown = 3.0  # Cooldown before sprinting again

var sprint_timer = 0.0
var sprint_cooldown_timer = 0.0
var can_sprint = true

var is_crouching = false
var crouch_height = 0.5  # Height when crouching
var stand_height = 1.8  # Height when standing
var current_height = stand_height  # Initialize to standing height
var crouch_speed_transition = 8.0  # Speed of transitioning between crouch and stand

var slide_duration = 1.0  # Duration of the slide
var slide_timer = 0.0
var is_sliding = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_collision_shape()

func _physics_process(delta: float) -> void:
	handle_ground_detection()
	handle_jumping()
	handle_movement(delta)
	handle_sprint(delta)
	handle_crouching(delta)
	handle_sliding(delta)

# Handles ground detection using a raycast
func handle_ground_detection() -> void:
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = global_transform.origin
	ray_params.to = global_transform.origin + Vector3(0, -1, 0) * 2.0
	ray_params.exclude = [self]
	
	var space_state = get_world_3d().direct_space_state
	var ray = space_state.intersect_ray(ray_params)
	is_on_ground = ray.size() > 0

# Applies a jump impulse if the jump action is pressed and the character is on the ground
func handle_jumping() -> void:
	if Input.is_action_just_pressed("move_up") and is_on_ground:
		apply_central_impulse(jump_impulse)

# Handles character movement and speed adjustments based on sprinting status
func handle_movement(delta: float) -> void:
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")

	var current_speed = get_current_speed()
	if is_on_ground:
		apply_central_force(twist_pivot.basis * input * current_speed * delta)
	else:
		apply_central_force(twist_pivot.basis * input * (current_speed * air_control_factor) * delta)
	
	limit_air_speed()

# Determines the current speed based on sprinting status and time
func get_current_speed() -> float:
	if is_on_ground and Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_sprint") and can_sprint:
		return sprint_speed
	else:
		if is_crouching:
			return crouch_speed
		else:
			return normal_speed

# Limits the velocity in the air to a maximum speed
func limit_air_speed() -> void:
	var current_velocity = linear_velocity
	if current_velocity.length() > max_air_speed:
		linear_velocity = current_velocity.normalized() * max_air_speed

# Handles sprinting timer and cooldown
func handle_sprint(delta: float) -> void:
	if sprint_timer > 0.0:
		sprint_timer -= delta
	else:
		if sprint_cooldown_timer <= 0.0:
			can_sprint = true
		else:
			sprint_cooldown_timer -= delta

	if sprint_timer <= 0.0:
		can_sprint = false
		sprint_cooldown_timer = sprint_cooldown

# Handles crouching logic and transitions
func handle_crouching(delta: float) -> void:
	if Input.is_action_pressed("move_crouch") and is_on_ground:
		start_crouching(delta)
	else:
		stop_crouching(delta)

# Initiates the crouching transition if not already crouching
func start_crouching(delta: float) -> void:
	if not is_crouching:
		is_crouching = true
		transition_height(crouch_height, delta)
		update_collision_shape()

# Ends the crouching transition if currently crouching
func stop_crouching(delta: float) -> void:
	if is_crouching:
		is_crouching = false
		transition_height(stand_height, delta)
		update_collision_shape()

# Smoothly transitions the height of the character
func transition_height(target_height: float, delta: float) -> void:
	var height_diff = target_height - current_height
	if abs(height_diff) > 0.01:
		current_height += height_diff * delta * crouch_speed_transition
		if abs(height_diff) < abs(height_diff * delta * crouch_speed_transition):
			current_height = target_height
		update_character_position(target_height)

# Adjusts the character's position to match the height change
func update_character_position(target_height: float) -> void:
	var height_change = target_height - stand_height
	global_transform.origin.y -= height_change * (target_height - current_height) / (stand_height - crouch_height)

# Updates the collision shape to match the current height
func update_collision_shape() -> void:
	if collision_shape:
		collision_shape.scale.y = current_height

# Handles sliding logic
func handle_sliding(delta: float) -> void:
	if Input.is_action_just_pressed("move_slide") and get_current_speed() == sprint_speed and not is_sliding:
		start_slide()
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			stop_slide()

	if Input.is_action_just_pressed("move_up") and is_sliding:
		stop_slide()

# Initiates sliding by applying a forward velocity
func start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	linear_velocity = twist_pivot.basis * Vector3(0, 0, sprint_speed)

# Ends sliding by reducing velocity
func stop_slide() -> void:
	is_sliding = false
	slide_timer = 0.0
	linear_velocity *= 0.5

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Handle mouse movement input for camera rotation
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, deg_to_rad(-70), deg_to_rad(70))
	
	twist_input = 0.0
	pitch_input = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = -event.relative.x * mouse_sensitivity
			pitch_input = -event.relative.y * mouse_sensitivity
