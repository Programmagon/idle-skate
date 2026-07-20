extends RigidBody2D

@export var push_force = 1500.0
@export var max_speed: float = 700.0

# --- Balance & Stabilization ---
@export var balance_force = 1000.0  # How strongly the skateboarder stabilizes the board
@export var balance_damping = 150.0  # Prevents the board from wobbling wildly

# Jump Forces
@export var ollie_force_front = 200.0
@export var ollie_force_back = 220.0
@export var ollie_delay = 0.05 

@onready var ray_front: RayCast2D = $RayCast2D_Vorne
@onready var ray_back: RayCast2D = $RayCast2D_Hinten
@onready var player: Sprite2D = $Sprite2D2

var is_jumping = false
var position_left: Vector2
var position_right: Vector2
var cheats_enabled = false

func _ready():
	if ray_front.position.x > ray_back.position.x:
		position_right = ray_front.position
		position_left = ray_back.position
	else:
		position_right = ray_back.position
		position_left = ray_front.position

func _physics_process(_delta):
	if Input.is_action_just_pressed("jump") and not is_jumping:
		if is_grounded():
			start_ollie()
			
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
		
	if Input.is_action_just_pressed("activate_cheats") or (Input.is_action_just_pressed("steer_left") and Input.is_action_just_pressed("steer_right")):
		cheats_enabled = !cheats_enabled
		
	player.visible = cheats_enabled
		

func _integrate_forces(state):
	# Determine driving direction
	var is_moving_left = linear_velocity.x < -10
	var is_moving_right = linear_velocity.x > 10
	
	if is_moving_left:
		ray_front.position = position_left
		ray_back.position = position_right
	elif is_moving_right:
		ray_front.position = position_right
		ray_back.position = position_left
	
	# --- Balance System ---
	if is_grounded() and not is_jumping:
		# Get the normal vector of the ground (where the ground points)
		var ground_normal = Vector2.UP
		if ray_front.is_colliding():
			ground_normal = ray_front.get_collision_normal()
		
		# Calculate target angle parallel to the ground
		var target_angle = ground_normal.angle() + PI / 2.0
		
		# How far is the board currently from the target angle?
		var angle_difference = wrapf(target_angle - rotation, -PI, PI)
		
		# Calculate torque: force based on tilt minus current rotation speed (damping)
		var stabilizing_torque = (angle_difference * balance_force) - (angular_velocity * balance_damping)
		
		# Apply torque to the physics object
		state.apply_torque(stabilizing_torque)
		
		# Normal forward movement
		var direction = Input.get_axis("steer_left", "steer_right")
		var forward_vector = Vector2.RIGHT.rotated(rotation)
		var current_speed = linear_velocity.dot(forward_vector)
		
		if abs(current_speed) < max_speed:
			apply_central_force(forward_vector * direction * push_force)

func start_ollie():
	is_jumping = true
	var upward_vector = Vector2.UP.rotated(rotation)
	apply_impulse(upward_vector * ollie_force_front, ray_front.position)
	
	await get_tree().create_timer(ollie_delay).timeout
	apply_impulse(upward_vector * ollie_force_back, ray_back.position)
	
	await get_tree().create_timer(0.2).timeout
	is_jumping = false

func is_grounded():
	if cheats_enabled:
		return true
	else:
		return ray_front.is_colliding() or ray_back.is_colliding()
