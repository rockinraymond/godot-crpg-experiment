extends CharacterBody2D

## How fast the player moves
@export var movement_speed: float = 150

## The input map action associated with moving and interacting
@export var pathfind_action: String = "left_click"
## Amount of time between pathfinding attempts while button is held
@export var pathfind_hold_delay: float = 0.5

## A navigation agent
@export var nav_agent: NavigationAgent2D
## An area2d representing how close the player must be to interact. Should be 
## masked to only see interactable objects
@export var interaction_area: Area2D
## A shapecast used to find objects under the mouse cursor. Should be masked
## to only see interactable objects
@export var shapecast: ShapeCast2D


var _delay_timer = Timer.new()
var _queued_interact = false
var menuOpen = false
var last_direction = Vector2(1, 0)

var anim_directions = {
	"idle": [ # list of [animation name, horizontal flip]
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

func update_animation(anim_set):
	var angle = rad_to_deg(last_direction.angle()) + 22.5
	var slice_dir = floor(angle / 45)
	var anim_name = anim_directions[anim_set][slice_dir][0]
	var flip_h = anim_directions[anim_set][slice_dir][1]

	# Animate BaseSprite itself
	$BaseSprite.play(anim_name)
	$BaseSprite.flip_h = flip_h

	# Animate all visible child sprites of BaseSprite
	for child in $BaseSprite.get_children():
		if child is AnimatedSprite2D and child.visible:
			child.play(anim_name)
			child.flip_h = flip_h



func _ready():
	assert(nav_agent)
	assert(interaction_area)
	assert(shapecast)
	nav_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	_delay_timer.wait_time=pathfind_hold_delay
	add_child(_delay_timer)
	_delay_timer.timeout.connect(_on_timeout)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pathfind_action):
		_try_click()
		_delay_timer.start()
	if event.is_action_released(pathfind_action):
		_delay_timer.stop()
	if event.is_action_pressed("menu"):
		if menuOpen == false:
				menuOpen = true
				$InGameMenu.show()
		else:
				menuOpen = false
				$InGameMenu.hide()

## Called when the player clicks the pathfinding action, attempts to find a new path,
## or interact with an object if hovering over one
func _try_click():
	_queued_interact = false
	shapecast.global_position=get_global_mouse_position()
	shapecast.force_shapecast_update()
	if shapecast.is_colliding():
		var collider = shapecast.get_collider(0)
		if collider is InteractableComponent:
			if interaction_area.overlaps_area(collider):
				collider.interact()
				return
			else:
				_queued_interact = collider
	nav_agent.set_target_position(get_global_mouse_position())

func _on_timeout():
	_try_click()

func _physics_process(_delta):
	# Skip logic if the map hasn't initialized
	if NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
		return
	if nav_agent.is_navigation_finished():
		update_animation("idle")  # Stop animation when navigation is done
		return

	# Calculate the movement vector based on navigation target
	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	var new_velocity: Vector2 = global_position.direction_to(next_path_position) * movement_speed

	# Apply velocity to nav_agent or manually handle movement
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

	# Optional: if you're also using move_and_slide for physics body
	set_velocity(new_velocity)
	move_and_slide()

	# Update animation based on movement direction
	if new_velocity.length() > 0:
		last_direction = new_velocity
		update_animation("walk")
	else:
		update_animation("idle")

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func _on_interaction_area_area_entered(area: Area2D) -> void:
	if _queued_interact and _queued_interact==area:
		nav_agent.set_target_position(position)
		_queued_interact.interact()
		_queued_interact=false
