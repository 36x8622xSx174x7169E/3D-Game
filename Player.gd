extends RigidBody3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot
@onready var collision_shape := $CollisionShape3D

var jump_impulse = Vector3(0, 8, 0)  # Adjust Y value for jump strength
var is_on_ground = false
var air_control_factor = 0.1
var max_air_speed = 7.0 
var normal_speed = 1100.0  # Normal movement speed
var crouch_speed = 800.0
var initial_sprint_speed = 2000.0  # Initial sprint speed for the first second
var reduced_sprint_speed = 1600.0  # Reduced sprint speed after one second
var sprint_duration = 6.0  # Time in seconds the player can sprint
var sprint_cooldown = 4.0  # Time in seconds to wait before initial sprinting again
var fast_sprint_cooldown = 7.0  # Time in seconds before allowing another fast sprint

var sprint_timer = 0.0
var sprint_cooldown_timer = 0.0
var fast_sprint_timer = 0.0
var can_sprint = true
var can_fast_sprint = true
var sprint_start_time = 0.0  # Time when sprinting starts

var is_crouching = false
var crouch_height = 0.5  # Height when crouching
var stand_height = 0.975   # Height when standing
var current_height = stand_height  # Initialize to standing height
var crouch_speed_transition = 10.0  # Speed of transitioning between crouch and stand

var slide_duration = 1.0  # Duration of the slide
var slide_timer = 0.0
var is_sliding = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if collision_shape:
		# Adjust the collision shape based on initial character height
		collision_shape.scale.y = current_height  # Set initial height to standing height

# Called every physics frame
func _physics_process(delta):
	# Ground detection logic
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = global_transform.origin
	ray_params.to = global_transform.origin + Vector3(0, -1, 0) * 2.0  # Increased length for reliability
	ray_params.exclude = [self]
	
	var space_state = get_world_3d().direct_space_state
	var ray = space_state.intersect_ray(ray_params)
	is_on_ground = ray.size() > 0

	# Check for jump input
	if Input.is_action_just_pressed("move_up") and is_on_ground:
		print("Jumping!")  # Debugging: Check if jump input is registered
		apply_central_impulse(jump_impulse)

	# Movement logic: Only apply forces if on the ground
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	var is_sprinting = Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_sprint")
	
	# Determine sprint speed
	var current_speed = normal_speed
	if is_sprinting and can_sprint:
		if sprint_timer <= 0.0:
			if sprint_cooldown_timer <= 0.0:
				# Start fast sprint if possible
				if can_fast_sprint:
					sprint_timer = sprint_duration
					sprint_start_time = Time.get_ticks_msec() / 1000.0  # Record the start time of the sprint
					can_fast_sprint = false
					fast_sprint_timer = fast_sprint_cooldown
				else:
					# Normal sprinting
					sprint_timer = sprint_duration
					sprint_start_time = Time.get_ticks_msec() / 1000.0
			else:
				# Cannot sprint due to cooldown
				sprint_timer = 0.0
		else:
			sprint_timer -= delta

		# Determine speed based on the time elapsed since sprinting started
		if Time.get_ticks_msec() / 1000.0 - sprint_start_time <= 1.0:
			current_speed = initial_sprint_speed
		else:
			current_speed = reduced_sprint_speed
	else:
		current_speed = normal_speed

	if is_on_ground:
		apply_central_force(twist_pivot.basis * input * current_speed * delta)
	else:
		apply_central_force(twist_pivot.basis * input * current_speed * delta * air_control_factor)
		
	var current_velocity = linear_velocity
	var speed = current_velocity.length()
	if speed > max_air_speed:
		linear_velocity = current_velocity.normalized() * max_air_speed
	
	# Handle sprint cooldown
	if sprint_cooldown_timer > 0.0:
		sprint_cooldown_timer -= delta
		if sprint_cooldown_timer <= 0.0:
			can_sprint = true

	# Update sprint ability
	if sprint_timer <= 0.0:
		can_sprint = false
		sprint_cooldown_timer = sprint_cooldown  # Start cooldown for initial sprint speed
		sprint_timer = 0.0
		can_fast_sprint = true

	# Handle fast sprint timer
	if fast_sprint_timer > 0.0:
		fast_sprint_timer -= delta

	# Handle crouching
	if Input.is_action_pressed("move_crouch") and is_on_ground:
		crouch(delta)
	else:
		stand(delta)
	
	# Handle sliding
	if Input.is_action_just_pressed("move_slide") and is_sprinting and !is_sliding:
		start_slide()
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			stop_slide()
	# Check if the space bar is pressed to cancel sliding
	if Input.is_action_just_pressed("move_up") and is_sliding:
		stop_slide()

# Function to start sliding
func start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	# Apply a sliding force or velocity to simulate sliding
	linear_velocity = twist_pivot.basis * Vector3(0, 0, reduced_sprint_speed)  # Adjust direction as needed

# Function to stop sliding
func stop_slide() -> void:
	is_sliding = false
	slide_timer = 0.0
	# Optionally, reset velocity or apply friction to end the slide
	linear_velocity = linear_velocity * 0.5  # Reduce velocity to simulate friction or stop sliding

# Function to handle crouching
func crouch(delta: float) -> void:
	if not is_crouching:
		is_crouching = true
		# Smoothly transition to crouch height
		current_height = lerp(current_height, crouch_height, delta * crouch_speed_transition)
		if collision_shape:
			collision_shape.scale.y = current_height  # Adjust the collision shape for crouching
		# Adjust the character's position to prevent floating/sinking
		var height_diff = stand_height - crouch_height
		global_transform.origin.y -= height_diff * delta  # Lower the position as we crouch

# Function to handle standing
func stand(delta: float) -> void:
	if is_crouching:
		is_crouching = false
		# Smoothly transition to standing height
		current_height = lerp(current_height, stand_height, delta * crouch_speed_transition)
		if collision_shape:
			collision_shape.scale.y = current_height  # Reset the collision shape to standing height
		# Adjust the character's position to prevent floating/sinking
		var height_diff = stand_height - crouch_height
		global_transform.origin.y += height_diff * delta  # Raise the position as we stand

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Handle mouse movement input for camera rotation
	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x,
		deg_to_rad(-70),
		deg_to_rad(70)
	)
	
	twist_input = 0.0
	pitch_input = 0.0

# Handle unhandled input for mouse look
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = -event.relative.x * mouse_sensitivity
			pitch_input = -event.relative.y * mouse_sensitivity


