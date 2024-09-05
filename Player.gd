extends RigidBody3D

enum MovementState { STANDING, CROUCHING, SPRINTING, SLIDING }

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0

@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot
@onready var collision_shape := $CollisionShape3D

var jump_impulse = Vector3(0, 8, 0)
var is_on_ground = false
var air_control_factor = 0.05
var max_air_speed = 7.0
var normal_speed = 1100.0
var crouch_speed = 800.0
var initial_sprint_speed = 2000.0
var reduced_sprint_speed = 1600.0
var sprint_duration = 6.0
var sprint_cooldown = 4.0
var fast_sprint_cooldown = 7.0

var sprint_timer = 0.0
var sprint_cooldown_timer = 0.0
var fast_sprint_timer = 0.0
var can_sprint = true
var can_fast_sprint = true
var sprint_start_time = 0.0

var is_crouching = false
var crouch_height = 1.0
var stand_height = 1.0
var current_height = stand_height
var crouch_speed_transition = 10.0

var slide_duration = 1.0
var slide_timer = 0.0
var is_sliding = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_collision_shape()

func _physics_process(delta):
	handle_ground_detection()
	handle_jumping()
	handle_movement(delta)
	handle_sprint(delta)
	handle_crouching(delta)
	handle_sliding(delta)
	update_crouch_position(delta)

func handle_ground_detection() -> void:
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = global_transform.origin
	ray_params.to = global_transform.origin + Vector3(0, -1, 0) * 2.0
	ray_params.exclude = [self]
	
	var space_state = get_world_3d().direct_space_state
	var ray = space_state.intersect_ray(ray_params)
	is_on_ground = ray.size() > 0

func handle_jumping() -> void:
	if Input.is_action_just_pressed("move_up") and is_on_ground:
		apply_central_impulse(jump_impulse)

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

func get_current_speed() -> float:
	if is_on_ground and Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_sprint") and can_sprint:
		if Time.get_ticks_msec() / 1000.0 - sprint_start_time <= 1.0:
			return initial_sprint_speed
		else:
			return reduced_sprint_speed
	else:
		return normal_speed

func limit_air_speed() -> void:
	var current_velocity = linear_velocity
	if current_velocity.length() > max_air_speed:
		linear_velocity = current_velocity.normalized() * max_air_speed

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
		can_fast_sprint = true

	if fast_sprint_timer > 0.0:
		fast_sprint_timer -= delta

func handle_crouching(delta: float) -> void:
	if Input.is_action_pressed("move_crouch") and is_on_ground:
		crouch(delta)
	else:
		stand(delta)

func handle_sliding(delta: float) -> void:
	if Input.is_action_just_pressed("move_slide") and can_sprint and not is_sliding:
		start_slide()
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			stop_slide()

	if Input.is_action_just_pressed("move_up") and is_sliding:
		stop_slide()

func update_crouch_position(delta: float) -> void:
	if is_crouching:
		var height_diff = stand_height - crouch_height
		global_transform.origin.y -= height_diff * delta
	elif not is_crouching:
		var height_diff = stand_height - crouch_height
		global_transform.origin.y += height_diff * delta

func start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	linear_velocity = twist_pivot.basis * Vector3(0, 0, reduced_sprint_speed)

func stop_slide() -> void:
	is_sliding = false
	slide_timer = 0.0
	linear_velocity *= 0.5

func crouch(delta: float) -> void:
	if not is_crouching:
		is_crouching = true
		current_height = lerp(current_height, crouch_height, delta * crouch_speed_transition)
		if collision_shape:
			collision_shape.scale.y = current_height
		update_crouch_position(delta)

func stand(delta: float) -> void:
	if is_crouching:
		is_crouching = false
		current_height = lerp(current_height, stand_height, delta * crouch_speed_transition)
		if collision_shape:
			collision_shape.scale.y = current_height
		update_crouch_position(delta)

func update_collision_shape() -> void:
	if collision_shape:
		collision_shape.scale.y = current_height

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
