extends CharacterBody2D

enum PlayerState {
	IDLE,
	MOVING,
	INTERACTING,
	MENU_OPEN,
	CONTEXT_MENU
}

@export var movement_speed: float = 150
@export var pathfind_action: String = "left_click"
@export var context_action: String = "right_click"
@export var pathfind_hold_delay: float = 0.5
@export var nav_agent: NavigationAgent2D
@export var interaction_area: Area2D
@export var shapecast: ShapeCast2D

var _delay_timer = Timer.new()
var _queued_interact = false
var last_direction = Vector2(1, 0)
var state: PlayerState = PlayerState.IDLE

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

func update_animation(anim_set):
	var angle = rad_to_deg(last_direction.angle()) + 22.5
	var slice_dir = floor(angle / 45)
	var anim_name = anim_directions[anim_set][slice_dir][0]
	var flip_h = anim_directions[anim_set][slice_dir][1]

	$BaseSprite.play(anim_name)
	$BaseSprite.flip_h = flip_h
	for child in $BaseSprite.get_children():
		if child is AnimatedSprite2D and child.visible:
			child.play(anim_name)
			child.flip_h = flip_h

func _ready():
	assert(nav_agent)
	assert(interaction_area)
	assert(shapecast)
	nav_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	_delay_timer.wait_time = pathfind_hold_delay
	add_child(_delay_timer)
	_delay_timer.timeout.connect(_on_timeout)
	$ContextMenu.connect("id_pressed", Callable(self, "_on_context_menu_id_pressed"))
	$ContextMenu.connect("popup_hide", Callable(self, "_on_context_menu_closed"))
	$ContextMenu.hide()
	
	# Setup context menu
	$ContextMenu.clear()
	$ContextMenu.add_item("Move to", 0)
	$ContextMenu.add_item("Examine", 1)
	$ContextMenu.add_item("Interact/Attack", 2)
	$ContextMenu.connect("id_pressed", Callable(self, "_on_context_menu_id_pressed"))
	$ContextMenu.hide()

func _unhandled_input(event: InputEvent) -> void:
	if state == PlayerState.MENU_OPEN:
		if event.is_action_pressed("menu"):
			_change_state(PlayerState.IDLE)
			$InGameMenu.hide()
		return

	if event.is_action_pressed(context_action):
		_show_context_menu(get_viewport().get_mouse_position())
		return

	if state == PlayerState.CONTEXT_MENU:
		return
	if event.is_action_pressed(pathfind_action):
		_try_click()
		_delay_timer.start()
	if event.is_action_released(pathfind_action):
		_delay_timer.stop()
	if event.is_action_pressed("menu"):
		_change_state(PlayerState.MENU_OPEN)
		$InGameMenu.show()

func _show_context_menu(pos: Vector2):
	state = PlayerState.CONTEXT_MENU
	$ContextMenu.set_position(pos)
	$ContextMenu.show()
	$ContextMenu.grab_focus()

func _on_context_menu_id_pressed(id):
	$ContextMenu.hide()
	if id == 0:
		# Move to clicked location
		nav_agent.set_target_position(get_global_mouse_position())
		_change_state(PlayerState.MOVING)
	elif id == 1:
		# Examine clicked object (if any)
		shapecast.global_position = get_global_mouse_position()
		shapecast.force_shapecast_update()
		if shapecast.is_colliding():
			var collider = shapecast.get_collider(0)
			if "examine" in collider:
				collider.examine()
		_change_state(PlayerState.IDLE)
	elif id == 2:
		# Interact/Attack clicked object (if any)
		shapecast.global_position = get_global_mouse_position()
		shapecast.force_shapecast_update()
		if shapecast.is_colliding():
			var collider = shapecast.get_collider(0)
			if "interact" in collider:
				collider.interact()
		_change_state(PlayerState.IDLE)
	else:
		_change_state(PlayerState.IDLE)

func _try_click():
	_queued_interact = false
	shapecast.global_position = get_global_mouse_position()
	shapecast.force_shapecast_update()
	if shapecast.is_colliding():
		var collider = shapecast.get_collider(0)
		if collider is InteractableComponent:
			if interaction_area.overlaps_area(collider):
				_change_state(PlayerState.INTERACTING)
				collider.interact()
				return
			else:
				_queued_interact = collider
	nav_agent.set_target_position(get_global_mouse_position())
	_change_state(PlayerState.MOVING)

func _on_timeout():
	_try_click()

func _physics_process(_delta):
	if NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
		return

	match state:
		PlayerState.IDLE:
			update_animation("idle")
		PlayerState.MOVING:
			if nav_agent.is_navigation_finished():
				_change_state(PlayerState.IDLE)
				return
			var next_path_position: Vector2 = nav_agent.get_next_path_position()
			var new_velocity: Vector2 = global_position.direction_to(next_path_position) * movement_speed
			if nav_agent.avoidance_enabled:
				nav_agent.set_velocity(new_velocity)
			else:
				_on_velocity_computed(new_velocity)
			set_velocity(new_velocity)
			move_and_slide()
			if new_velocity.length() > 0:
				last_direction = new_velocity
				update_animation("walk")
			else:
				update_animation("idle")
		PlayerState.INTERACTING:
			update_animation("idle")
			_change_state(PlayerState.IDLE)
		PlayerState.MENU_OPEN, PlayerState.CONTEXT_MENU:
			set_velocity(Vector2.ZERO)
			move_and_slide()
			update_animation("idle")

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func _on_interaction_area_area_entered(area: Area2D) -> void:
	if _queued_interact and _queued_interact == area:
		nav_agent.set_target_position(position)
		_queued_interact.interact()
		_queued_interact = false

func _change_state(new_state: PlayerState):
	if state == new_state:
		return
	state = new_state


func _on_context_menu_popup_hide() -> void:
	_change_state(PlayerState.IDLE)
