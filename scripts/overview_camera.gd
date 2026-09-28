extends Camera3D

@export var player_path: NodePath
@export var first_person_camera_path: NodePath
@export var camera_offset := Vector3(22.0, 27.0, 25.0)

var player: CharacterBody3D
var first_person_camera: Camera3D
var overview_enabled := true
var last_floor := -1

func _ready() -> void:
    player = get_node(player_path) as CharacterBody3D
    first_person_camera = get_node(first_person_camera_path) as Camera3D
    current = true
    first_person_camera.current = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _update_camera(true)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_view"):
        overview_enabled = not overview_enabled
        current = overview_enabled
        first_person_camera.current = not overview_enabled
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if overview_enabled else Input.MOUSE_MODE_CAPTURED
        _set_current_ceiling(not overview_enabled)

func _process(_delta: float) -> void:
    if overview_enabled:
        _update_camera(false)

func _update_camera(force_update: bool) -> void:
    if player == null:
        return
    var floor_index := clampi(int(floor((player.global_position.y + 0.45) / 4.0)), 0, 5)
    var floor_y := floor_index * 4.0
    var focus_z := 2.5 if floor_index == 0 else 0.0
    var focus := Vector3(0.0, floor_y, focus_z)
    global_position = focus + camera_offset
    look_at(focus + Vector3(0.0, 0.35, 0.0), Vector3.UP)
    if force_update or floor_index != last_floor:
        last_floor = floor_index
        _show_only_floor(floor_index)

func _show_only_floor(floor_index: int) -> void:
    var names := ["PRIMER_PISO", "SEGUNDO_PISO", "TERCER_PISO", "CUARTO_PISO", "QUINTO_PISO", "AZOTEA"]
    var school := get_parent()
    for i in range(names.size()):
        var level := school.get_node_or_null(names[i]) as Node3D
        if level:
            level.visible = i == floor_index


func _set_current_ceiling(show_ceiling: bool) -> void:
    var names := ["PRIMER_PISO", "SEGUNDO_PISO", "TERCER_PISO", "CUARTO_PISO", "QUINTO_PISO", "AZOTEA"]
    if last_floor < 0 or last_floor >= names.size():
        return
    var level := get_parent().get_node_or_null(names[last_floor]) as Node3D
    if level:
        var ceiling := level.get_node_or_null("Ceiling") as Node3D
        if ceiling:
            ceiling.visible = show_ceiling