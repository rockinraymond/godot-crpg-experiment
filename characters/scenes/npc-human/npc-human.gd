extends CharacterBody2D

@export var movement_speed: float = 100
@export var nav_agent: NavigationAgent2D
@export var pause_duration_range := Vector2(1.0, 3.0) # Min/Max pause seconds

var last_direction = Vector2(1, 0)
var is_paused = false
var pause_timer := Timer.new()

var anim_directions = {
	"idle": [
		["side_right_idle", false],
		["45front_right_idle", false],
		["front_idle", false],
		["45front_left_idle", false],
		["side_left_idle", false],
		["45back_left_idle", false],
		["back_idle", false],
		["45back_right_idle", false],
	],
	"walk": [
		["side_right_walk", false],
		["45front_right_walk", false],
		["front_walk", false],
		["45front_left_walk", false],
		["side_left_walk", false],
		["45back_left_walk", false],
		["back_walk", false],
		["45back_right_walk", false],
	],
}

func _ready():
	assert(nav_agent)
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	pause_timer.one_shot = true
	pause_timer.timeout.connect(_on_pause_finished)
	add_child(pause_timer)

	_set_random_target()

func _physics_process(_delta):
	if is_paused:
		update_animation("idle")
		return

	if nav_agent.is_navigation_finished():
		update_animation("idle")
		_start_pause()
		return

	var next_pos = nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next_pos) * movement_speed

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(velocity)
	else:
		_on_velocity_computed(velocity)

	set_velocity(velocity)
	move_and_slide()

	if velocity.length() > 0:
		last_direction = velocity
		update_animation("walk")
	else:
		update_animation("idle")

func update_animation(anim_set):
	var angle = rad_to_deg(last_direction.angle()) + 22.5
	var slice_dir = int(floor(angle / 45.0)) % 8
	var anim_name = anim_directions[anim_set][slice_dir][0]
	var flip_h = anim_directions[anim_set][slice_dir][1]

	$Sprite2D.play(anim_name)
	$Sprite2D.flip_h = flip_h

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func _set_random_target():
	var radius = 300.0
	var offset = Vector2(randf() * radius, randf() * radius) - Vector2(radius / 2, radius / 2)
	nav_agent.set_target_position(global_position + offset)

func _start_pause():
	is_paused = true
	var random_time = randf_range(pause_duration_range.x, pause_duration_range.y)
	if random_time == 0:
		random_time = 1
	pause_timer.start(random_time)

func _on_pause_finished():
	is_paused = false
	_set_random_target()
