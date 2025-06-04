extends VehicleBody3D

# NOTE TO USER: Remember to define "boost" and "debug_fill_boost" actions in Project > Project Settings > Input Map.
# "boost" could be Left Shift. "debug_fill_boost" could be a key like F.
# ALSO: In main_track.tscn, on the Player node (instance of player_vehicle.tscn),
# you MUST link the "Follow Camera Node Path" export variable to its own FollowCamera child node.

# --- Forces ---
@export var max_engine_force: float = 100.0
@export var max_brake_force: float = 50.0

# --- Steering ---
@export var initial_steer_angle: float = 0.5
@export var steer_angle_at_high_speed: float = 0.1
@export var speed_for_full_steer: float = 10.0
@export var speed_for_reduced_steer: float = 30.0
@export var steer_speed: float = 2.5

# --- Boost ---
@export var max_boost_amount: float = 100.0
var current_boost_amount: float # Initialized in _ready
@export var boost_force_multiplier: float = 2.0
@export var boost_consumption_rate: float = 30.0
@export var boost_passive_recharge_rate: float = 8.0

# --- Visual Effects ---
@export var follow_camera_node_path: NodePath # MUST be linked in the editor (main_track.tscn -> Player node)
var camera: Camera3D = null # Will hold the actual camera node

@export var normal_fov: float = 75.0
@export var boost_fov: float = 90.0
@export var fov_change_speed: float = 5.0

# Assuming BoostParticles will be a direct child of PlayerVehicle in player_vehicle.tscn
@onready var boost_particles: GPUParticles3D = $BoostParticles

var is_boosting: bool = false
var acceleration_input: float = 0.0
var final_engine_force: float = 0.0

func _ready():
    current_boost_amount = max_boost_amount # Start with full boost

    # Get the camera node using the exported NodePath
    if follow_camera_node_path and not follow_camera_node_path.is_empty():
        var cam_node = get_node_or_null(follow_camera_node_path)
        if cam_node is Camera3D:
            camera = cam_node
            camera.fov = normal_fov # Set initial FOV
        else:
            print_error("PlayerVehicle: Follow Camera NodePath ('%s') is not a Camera3D or node not found." % follow_camera_node_path)
    else:
        print_error("PlayerVehicle: Follow Camera NodePath not set in the Inspector for the Player node in main_track.tscn.")

    # Ensure BoostParticles node exists and initialize it
    if boost_particles:
        boost_particles.emitting = false # Start with particles off
    else:
        # This error will appear if $BoostParticles is not found.
        # The @onready variable will be null if the node isn't there at ready time.
        print_error("PlayerVehicle: BoostParticles node not found. Ensure it's a child of PlayerVehicle (in player_vehicle.tscn) and named 'BoostParticles'.")


func _physics_process(delta: float) -> void:
    # --- Steering Logic ---
    var current_speed: float = linear_velocity.length()
    var current_max_steer_angle: float = initial_steer_angle
    if current_speed > speed_for_full_steer:
        var speed_ratio: float = inverse_lerp(speed_for_full_steer, speed_for_reduced_steer, current_speed)
        current_max_steer_angle = lerp(initial_steer_angle, steer_angle_at_high_speed, speed_ratio)

    var steer_target: float = 0.0
    if Input.is_action_pressed("ui_left"):
        steer_target = current_max_steer_angle
    elif Input.is_action_pressed("ui_right"):
        steer_target = -current_max_steer_angle
    steering = move_toward(steering, steer_target, steer_speed * delta)

    # --- Acceleration/Braking Input ---
    acceleration_input = 0.0
    if Input.is_action_pressed("ui_up"):
        acceleration_input = 1.0
    elif Input.is_action_pressed("ui_down"):
        acceleration_input = -1.0

    # --- Base Engine Force Calculation ---
    var base_engine_force_request: float = 0.0
    if acceleration_input > 0.0:
        base_engine_force_request = acceleration_input * max_engine_force
        brake = 0.0
    elif acceleration_input < 0.0:
        base_engine_force_request = acceleration_input * max_brake_force
    else:
        base_engine_force_request = 0.0

    # --- Boost Logic ---
    var boost_input_active: bool = Input.is_action_pressed("boost")

    if boost_input_active and current_boost_amount > 0 and acceleration_input > 0:
        is_boosting = true
    else:
        is_boosting = false

    if is_boosting:
        final_engine_force = max_engine_force * boost_force_multiplier
        current_boost_amount -= boost_consumption_rate * delta
        if current_boost_amount <= 0:
            current_boost_amount = 0.0
            is_boosting = false

        # Visual effects for boost
        if camera:
            camera.fov = lerp(camera.fov, boost_fov, fov_change_speed * delta)
        if boost_particles:
            boost_particles.emitting = true
    else:
        final_engine_force = base_engine_force_request
        if current_boost_amount < max_boost_amount:
            current_boost_amount += boost_passive_recharge_rate * delta
            current_boost_amount = min(current_boost_amount, max_boost_amount)

        # Visual effects when not boosting
        if camera:
            camera.fov = lerp(camera.fov, normal_fov, fov_change_speed * delta)
        if boost_particles:
            boost_particles.emitting = false

    engine_force = final_engine_force

    # --- Debug Boost Refill ---
    if Input.is_action_just_pressed("debug_fill_boost"):
        current_boost_amount = max_boost_amount
