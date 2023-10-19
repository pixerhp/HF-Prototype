extends CharacterBody3D

#Plan:
#Ability to grab static objects
#Diggable terrain
#Fix hand rotating objects

#Render Arms?

#I'm seriously considering multiplayer

enum GRAB_MODE{ONLY_DROP, ONLY_GRAB, GRAB_OR_DROP}

@export var hand_prefab: PackedScene = preload("res://prefabs/hand.tscn")

var mirror_mode: bool = false
var hand_swap_y_z: bool = false
var left_handed: bool = false
var handling_chat: bool = false

var spawn_point: Vector3 = Vector3(0, 50, 0)
@onready var arms: Array = [$Camera3D/LeftArm, $Camera3D/RightArm]
var hands: Array = []

var flying: bool = false
var was_on_floor: bool = false
var previous_velocity: Vector3 = Vector3.ZERO

@onready var chatbox: LineEdit = get_tree().current_scene.get_node("ChatUI/ChatBox")
@onready var chat_history: RichTextLabel = get_tree().current_scene.get_node("ChatUI/Chat")
@onready var chat_timer: Timer = get_tree().current_scene.get_node("ChatUI/Timer")

func is_authority() -> bool:
	if multiplayer.get_multiplayer_peer().get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return false
	return $NetworkData.get_multiplayer_authority() == get_tree().get_multiplayer().get_unique_id()

func _enter_tree():
	$NetworkData.set_multiplayer_authority(str(name).to_int())
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	if is_authority():
		$NetworkData.username = get_tree().current_scene.get_node("MenuCanvas/NetworkMenu/VBoxContainer/Username").text
	#set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	var hand_index: int = 0
	for arm in arms:
		make_hand.call_deferred(arm, hand_index)
		arm.get_node("ReturnTimer").connect("timeout", _on_return_timer_timeout.bind(arm))
		arm.set_meta("hand_index", hand_index)
		hand_index += 1
	
	if not is_authority():
		$MeshInstance3D.visible = true
		$Camera3D/Head.visible = true
		await $MultiplayerSynchronizer.synchronized
		$Nametag.text = $NetworkData.username
		return
	$Nametag.text = $NetworkData.username
	rpc("chat_said", $NetworkData.username + " joined.", false)
	
	$Camera3D.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	arms[0].set_meta("MirrorInMirrorMode", not left_handed)
	arms[1].set_meta("MirrorInMirrorMode", left_handed)
	chatbox.text_submitted.connect(chat_submit)
	chat_timer.timeout.connect(hide_chat)

func make_hand(arm, hand_index):
	if not multiplayer.get_unique_id() == 1:
		return
	var hand = hand_prefab.instantiate()
	hand.name = str($NetworkData.get_multiplayer_authority()) + "Hand" + str(hand_index)
	get_parent().add_child(hand)
#	if is_authority():
#		$NetworkData.puppet_hand_positions.append(hand.global_position)
#		$NetworkData.puppet_hand_rotations.append(hand.global_rotation)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

const SPRINT_MULTIPLIER = 3

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_authority():
		velocity = $NetworkData.puppet_velocity
		position = $NetworkData.puppet_position
		rotation = $NetworkData.puppet_rotation
		move_and_slide()
		return
	
	if Input.is_action_just_pressed("chat") and not chatbox.visible and not handling_chat:
		chatbox.visible = true
		chat_history.visible = true
		chat_timer.stop()
		chatbox.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if chatbox.visible else Input.MOUSE_MODE_CAPTURED
	
	handling_chat = false
	
	if not WorldManager.is_spawn_chunk_generated():
		return
	
	# Add the gravity.
	if not is_on_floor() and not flying:
		velocity.y -= gravity * delta
	
	if not chatbox.visible:
		# Handle Jump.
		if Input.is_action_pressed("jump") and is_on_floor() and not flying:
			velocity.y = JUMP_VELOCITY
		
		if flying:
			velocity.y = SPEED * Input.get_axis("lower", "jump")

		# Get the input direction and handle the movement/deceleration.
		var input_dir := Input.get_vector("left", "right", "forward", "backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1)
			velocity.z = direction.z * SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1))
			velocity.z = move_toward(velocity.z, 0, SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1))
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1))
		velocity.z = move_toward(velocity.z, 0, SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1))
	
	update_hands()
	move_and_slide()
	
	if not was_on_floor and is_on_floor() and previous_velocity.y <= -15:
		rpc("chat_said", $NetworkData.username + " fractured their hip.", false)
	was_on_floor = is_on_floor()
	previous_velocity = velocity
	
	$NetworkData.puppet_velocity = velocity
	$NetworkData.puppet_position = position
	$NetworkData.puppet_rotation = rotation
	WorldManager.load_world_around_player(global_position)
	
	if Input.is_action_just_pressed("spawn_shovel"):
		NetworkHandler.req_spawn_shovel(global_position + Vector3(0, 2, 0))
	
	if Input.is_action_just_pressed("reload"):
#		for arm in arms:
#			hands[arm.get_meta("hand_index")].get_node("MeshInstance3D").material_override.albedo_color = Color.WHITE
		global_position = spawn_point
		velocity = Vector3.ZERO
		rotation = Vector3.ZERO
	
	if Input.is_action_just_pressed("toggle_ui"):
		$"../../MenuCanvas".visible = not $"../../MenuCanvas".visible
		$"../../GameUI".visible = not $"../../GameUI".visible
	
	#$"../../StatsCanvas/Coordinates".text = str(Vector3i(global_position))
	#$"../../StatsCanvas/Speedometer".text = str(int(velocity.length())) + " speed"
	

func update_hands() -> void:
	for arm in arms:
		if hands.size() <= arm.get_meta("hand_index"):
			var get_hand: Node = get_node_or_null("../" + str($NetworkData.get_multiplayer_authority()) + "Hand" + str(arm.get_meta("hand_index")))
			if get_hand:
				hands.push_back(get_hand)
			continue
		var hand: Node3D = hands[arm.get_meta("hand_index")]
		var destination: Vector3 = arm.get_node("HandDestination").global_position
		hand.velocity = hand.global_position.direction_to(destination) * hand.global_position.distance_to(destination) * 60
		#if not is_empty_hand(hand):
			#var held_object_location: Vector3 = get_node(hand.get_node("Generic6DOFJoint3D").node_b).position + hand.get_meta("grab_offset")
			#hand.velocity += hand.global_position.direction_to(held_object_location) * hand.global_position.distance_to(held_object_location) * 60
		if hand.global_position != arm.global_position and abs(hand.global_position.direction_to(arm.global_position).y) != 1:
			hand.look_at(arm.global_position)
		hand.move_and_slide()
		
		velocity -= hand.global_position.direction_to(destination) * hand.global_position.distance_to(destination) * 0.5
		
		var timer: Timer = arm.get_node("ReturnTimer")
		if Input.is_action_pressed(arm.get_meta("MainAction")) or not is_empty_hand(hands[arm.get_meta("hand_index")]) or (mirror_mode and using_any_hands()):
			timer.stop()
			arm.set_meta("ReturningHome", false)
		elif timer.is_stopped():
			timer.start()
		
		if arm.get_meta("ReturningHome"):
			arm.get_node("HandDestination").position.z = lerp(arm.get_node("HandDestination").position.z, -1.5, 0.05)
			arm.rotation = lerp(arm.rotation, Vector3.ZERO, 0.05)
	
	if Input.is_action_just_pressed("toggle_mirror_mode"):
		mirror_mode = not mirror_mode
		$"../../GameUI/MirrorLine".visible = mirror_mode
	
	if Input.is_action_just_pressed("toggle_hand_y_z_swap"):
		hand_swap_y_z = not hand_swap_y_z
		for arm in arms:
			hands[arm.get_meta("hand_index")].get_node("MeshInstance3D").material_override.albedo_color = Color.DARK_BLUE if hand_swap_y_z else Color.WHITE
	
	if Input.is_action_just_released("drop"):
		for arm in arms:
			if Input.is_action_pressed(arm.get_meta("MainAction")) or mirror_mode or not using_any_hands():
				toggle_grab(arm.get_meta("hand_index"), GRAB_MODE.ONLY_DROP)

func _on_return_timer_timeout(arm: Node3D) -> void:
	arm.set_meta("ReturningHome", true)

func _input(event) -> void:
	if not is_authority():
		return
	
	if chatbox.visible:
		return
	
	if event is InputEventMouseButton:
		if event.double_click:
			if event.button_index == MOUSE_BUTTON_LEFT:
				toggle_grab(arms[0].get_meta("hand_index"))
			if event.button_index == MOUSE_BUTTON_RIGHT:
				toggle_grab(arms[1].get_meta("hand_index"))
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			for arm in arms:
				if Input.is_action_pressed(arm.get_meta("MainAction")) or (mirror_mode and using_any_hands()) or not using_any_hands():
					move_arm_hand_unit(arm, Vector3(0.0, 0.0, 0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1))
	if event is InputEventMouseMotion:
		var camera_drag_amount: Vector2 = Vector2.ZERO
		for arm in arms:
			if Input.is_action_pressed(arm.get_meta("MainAction")) or (mirror_mode and using_any_hands()):
				camera_drag_amount += move_arm_hand_unit(arm, Vector3(event.relative.x * -0.0015, event.relative.y * 0.0015, 0.0))
		
		if using_any_hands():
			rotation.y += camera_drag_amount.y * 0.6
			$Camera3D.rotation.x += camera_drag_amount.x * 0.4
		else:
			rotation.y += event.relative.x * -0.005
			$Camera3D.rotation.x += event.relative.y * -0.0015
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func move_arm_hand_unit(arm: Node3D, movement: Vector3):
	arm.get_node("ReturnTimer").stop()
	arm.set_meta("ReturningHome", false)
	if hand_swap_y_z:
		arm.get_node("HandDestination").position.z += movement.y
		arm.rotation.x += movement.z
	else:
		arm.get_node("HandDestination").position.z -= movement.z
		arm.rotation.x -= movement.y
	var camera_drag_amount: Vector2 = Vector2.ZERO
	arm.rotation.y += movement.x * (-1 if mirror_mode and arm.get_meta("MirrorInMirrorMode") else 1)
	
	var range_limit = 75
	
	camera_drag_amount.x = arm.rotation.x - clamp(arm.rotation.x, deg_to_rad(-range_limit), deg_to_rad(range_limit))
	camera_drag_amount.y = arm.rotation.y - clamp(arm.rotation.y, deg_to_rad(-range_limit), deg_to_rad(range_limit))
	arm.rotation.x = clamp(arm.rotation.x, deg_to_rad(-range_limit), deg_to_rad(range_limit))
	arm.rotation.y = clamp(arm.rotation.y, deg_to_rad(-range_limit), deg_to_rad(range_limit))
	arm.get_node("HandDestination").position.z = clamp(arm.get_node("HandDestination").position.z, -2, 0)
	return camera_drag_amount

func using_any_hands() -> bool:
	for arm in arms:
		if Input.is_action_pressed(arm.get_meta("MainAction")):
			return true
	return false

func is_empty_hand(hand) -> bool:
	return hand.get_node("Generic6DOFJoint3D").node_b.is_empty()

func toggle_grab(hand_index: int, grab_mode: GRAB_MODE = GRAB_MODE.GRAB_OR_DROP):
	var hand: Node3D = hands[hand_index]
	if grab_mode == GRAB_MODE.ONLY_DROP or (grab_mode == GRAB_MODE.GRAB_OR_DROP and not is_empty_hand(hand)):
		if not is_empty_hand(hand) and get_node(hand.get_node("Generic6DOFJoint3D").node_b) is RigidBody3D:
			get_node(hand.get_node("Generic6DOFJoint3D").node_b).gravity_scale = 1
		hand.get_node("Generic6DOFJoint3D").node_b = ""
		rpc_id(1, "grab_item", null, hand_index, false)
		return
	
	for body in hand.get_node("Area3D").get_overlapping_bodies():
		if not body.is_in_group("player") and not body.is_in_group("hand"):
			hand.get_node("Generic6DOFJoint3D").node_b = body.get_path()
			hand.set_meta("grab_offset", hand.global_position - body.global_position)
			if body is RigidBody3D:
				body.gravity_scale = 0
				body.linear_velocity = Vector3.ZERO
				body.angular_velocity = Vector3.ZERO
				body.collision_layer = 1
				body.collision_mask = 1
			rpc_id(1, "grab_item", body.get_path(), hand_index, true)

@rpc("any_peer", "call_local")
func grab_item(item_path, hand_index, is_grab: bool = true):
	var hand = get_node_or_null("../" + str($NetworkData.get_multiplayer_authority()) + "Hand" + str(hand_index))
	if not hand:
		return
	if is_grab:
		var item = get_node(item_path)
		hand.get_node("Generic6DOFJoint3D").node_b = item_path
		if item is RigidBody3D:
			item.gravity_scale = 0
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
			item.collision_layer = 1
			item.collision_mask = 1
	else:
		if not is_empty_hand(hand) and get_node(hand.get_node("Generic6DOFJoint3D").node_b) is RigidBody3D:
			var item: RigidBody3D = get_node(hand.get_node("Generic6DOFJoint3D").node_b)
			item.gravity_scale = 1
			item.collision_layer = 3
			item.collision_mask = 3
		hand.get_node("Generic6DOFJoint3D").node_b = ""

func chat_submit(chat: String):
	chatbox.clear()
	chatbox.visible = false
	handling_chat = true
	chat_timer.start(5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if chat.length() == 0:
		return
	if chat[0] == "/":
		handle_command(chat.substr(1))
	else:
		rpc("chat_said", chat, true)

@rpc("call_local", "any_peer")
func chat_said(chat: String, show_id: bool = false):
	if show_id:
		chat_history.append_text("<" + $NetworkData.username + "> " + chat + "\n")
	else:
		chat_history.append_text(chat + "\n")
	chat_history.visible = true
	if not chatbox.visible:
		chat_timer.start(5)

func hide_chat():
	chat_history.visible = false

func handle_command(command: String):
	var parameters := command.split(" ", false)
	if parameters.size() == 0:
		return
	if parameters[0] == "tp":
		if parameters.size() != 4:
			print("Bad command usage")
			return
		var x: float = parameters[1].to_float()
		var y: float = parameters[2].to_float()
		var z: float = parameters[3].to_float()
		global_position = Vector3(x, y, z)
		velocity = Vector3.ZERO
		rotation = Vector3.ZERO
	if parameters[0] == "fly":
		flying = not flying
