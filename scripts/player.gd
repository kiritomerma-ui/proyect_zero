extends CharacterBody3D

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.0022

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var interaction_ray: RayCast3D
var coin_count := 0

func _ready() -> void:
    _ensure_inputs()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    $CollisionShape3D.shape = capsule
    var player_mesh := MeshInstance3D.new()
    player_mesh.name = "JugadorVisible"
    var visible_capsule := CapsuleMesh.new()
    visible_capsule.radius = 0.38
    visible_capsule.height = 1.75
    var player_material := StandardMaterial3D.new()
    player_material.albedo_color = Color("2f7ed8")
    player_material.emission_enabled = true
    player_material.emission = Color("0d2848")
    player_material.emission_energy_multiplier = 0.75
    visible_capsule.material = player_material
    player_mesh.mesh = visible_capsule
    add_child(player_mesh)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    interaction_ray = RayCast3D.new()
    interaction_ray.target_position = Vector3(0, 0, -2.6)
    interaction_ray.collision_mask = 3
    interaction_ray.collide_with_areas = true
    interaction_ray.collide_with_bodies = true
    camera.add_child(interaction_ray)

func _ensure_inputs() -> void:
    var bindings := {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "jump": KEY_SPACE,
        "sprint": KEY_SHIFT,
        "toggle_mouse": KEY_ESCAPE,
        "open_door": KEY_F,
        "pickup": KEY_E,
        "toggle_view": KEY_TAB,
    }
    for action in bindings:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        if InputMap.action_get_events(action).is_empty():
            var event := InputEventKey.new()
            event.physical_keycode = bindings[action]
            InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        head.rotate_x(-event.relative.y * mouse_sensitivity)
        head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))
    if event.is_action_pressed("toggle_mouse"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
    var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 7.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, speed * 7.0 * delta)
    move_and_slide()


func _process(_delta: float) -> void:
    _update_interaction()

func _nearest_interactable(group_name: String, maximum_distance: float) -> Node3D:
    var nearest: Node3D = null
    var best_distance := maximum_distance
    for candidate in get_tree().get_nodes_in_group(group_name):
        if candidate is Node3D:
            var distance := global_position.distance_to(candidate.global_position)
            if distance < best_distance:
                best_distance = distance
                nearest = candidate
    return nearest

func _update_interaction() -> void:
    var prompt := get_node_or_null("../HUD/Prompt") as Label
    if prompt == null:
        return
    var nearby_coin := _nearest_interactable("interactive_coin", 2.0)
    var nearby_door := _nearest_interactable("interactive_door", 2.35)
    prompt.text = ""
    if nearby_coin:
        prompt.text = nearby_coin.interaction_text()
    elif nearby_door:
        prompt.text = nearby_door.interaction_text()
    if Input.is_action_just_pressed("pickup") and nearby_coin:
        nearby_coin.interact("pickup", self)
    if Input.is_action_just_pressed("open_door") and nearby_door:
        nearby_door.interact("open_door", self)
func add_coin(amount: int) -> void:
    coin_count += amount
    var counter := get_node_or_null("../HUD/Coins") as Label
    if counter:
        counter.text = "MONEDAS  %02d" % coin_count