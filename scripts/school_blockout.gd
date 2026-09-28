extends Node3D

const FLOOR_H := 4.0
const BUILDING_W := 28.0
const BUILDING_D := 20.0
const DOOR_SCRIPT = preload("res://scripts/door.gd")
const COIN_SCRIPT = preload("res://scripts/coin.gd")

var mats: Dictionary = {}

func _ready() -> void:
    _make_materials()
    _make_world()
    _build_school()

func _mat(color: Color, roughness := 0.84, emission := Color(0, 0, 0)) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    if emission != Color(0, 0, 0):
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = 2.4
    return material

func _concrete_material(base_color: Color, dirt_color: Color) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color;
uniform vec4 dirt_color : source_color;
uniform float grime_strength = 0.72;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 tiled = UV * vec2(8.0, 5.0);
    float coarse = value_noise(tiled * 1.7);
    float fine = value_noise(tiled * 8.5);
    float mottling = coarse * 0.72 + fine * 0.28;
    float bottom_dirt = pow(clamp(1.0 - UV.y, 0.0, 1.0), 3.2);
    float damp_patch = smoothstep(0.55, 0.88, value_noise(tiled * 0.55 + vec2(6.3, 2.1)));
    float vertical_streak = smoothstep(0.60, 0.92, value_noise(vec2(tiled.x * 0.55, tiled.y * 0.10 + 3.7))) * (1.0 - UV.y);
    float grime = clamp(bottom_dirt * 0.85 + damp_patch * 0.35 + vertical_streak * 0.45, 0.0, 1.0) * grime_strength;
    vec3 concrete = base_color.rgb * (0.68 + mottling * 0.38);
    concrete = mix(concrete, dirt_color.rgb, grime);
    ALBEDO = concrete;
    ROUGHNESS = 0.93;
    SPECULAR = 0.18;
    float nx = value_noise(tiled * 11.0 + vec2(0.04, 0.0)) - fine;
    float ny = value_noise(tiled * 11.0 + vec2(0.0, 0.04)) - fine;
    NORMAL_MAP = vec3(0.5 + nx * 0.28, 0.5 + ny * 0.28, 1.0);
    NORMAL_MAP_DEPTH = 0.32;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    material.set_shader_parameter("base_color", base_color)
    material.set_shader_parameter("dirt_color", dirt_color)
    return material

func _grimy_floor_material() -> ShaderMaterial:
    var material := _concrete_material(Color("77756f"), Color("292d2b"))
    material.set_shader_parameter("grime_strength", 0.48)
    return material
func _make_materials() -> void:
    mats.floor = _grimy_floor_material()
    mats.wall = _concrete_material(Color("a9a89f"), Color("343b36"))
    mats.dark_wall = _concrete_material(Color("4a4e50"), Color("171c1d"))
    mats.wood = _mat(Color("5d4634"))
    mats.metal = _mat(Color("4d5660"), 0.35)
    mats.safe = _mat(Color("277a4b"), 0.65, Color("0a391d"))
    mats.danger = _mat(Color("821f26"), 0.7, Color("3b0508"))
    mats.item = _mat(Color("d3a819"), 0.4, Color("5b3d00"))
    mats.blue = _mat(Color("315e82"))
    mats.roof = _mat(Color("555b60"))

func _make_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("74808b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("c5d0db")
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("7a858c")
    env.fog_density = 0.005
    environment.environment = env
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)

func _box(parent: Node, name_text: String, pos: Vector3, size: Vector3, material: Material, collision := true) -> Node3D:
    var body: Node3D
    if collision:
        body = StaticBody3D.new()
    else:
        body = MeshInstance3D.new()
    body.name = name_text
    body.position = pos
    parent.add_child(body)
    var mesh_instance: MeshInstance3D
    if collision:
        mesh_instance = MeshInstance3D.new()
        body.add_child(mesh_instance)
    else:
        mesh_instance = body as MeshInstance3D
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    mesh_instance.mesh = mesh
    if collision:
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
    return body

func _label(parent: Node, text_value: String, pos: Vector3, color := Color.WHITE, size := 42) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = size
    label.modulate = color
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    parent.add_child(label)

func _item(parent: Node, name_text: String, pos: Vector3, color_mat: Material = null) -> void:
    if name_text == "Moneda":
        var coin := Area3D.new()
        coin.name = "MonedaInteractiva"
        coin.set_script(COIN_SCRIPT)
        coin.position = pos + Vector3(0, 0.55, 0)
        parent.add_child(coin)
        return
    var mesh := MeshInstance3D.new()
    mesh.name = name_text
    mesh.position = pos
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.18
    cylinder.bottom_radius = 0.18
    cylinder.height = 0.09
    cylinder.material = color_mat if color_mat else mats.item
    mesh.mesh = cylinder
    parent.add_child(mesh)

func _enemy(parent: Node, pos: Vector3) -> void:
    var enemy := MeshInstance3D.new()
    enemy.name = "InfectadoPlaceholder"
    enemy.position = pos
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.38
    capsule.height = 1.7
    capsule.material = mats.danger
    enemy.mesh = capsule
    parent.add_child(enemy)

func _wall_with_doors(parent: Node, y: float, z: float, door_centers: Array[float]) -> void:
    var centers := door_centers.duplicate()
    centers.sort()
    var cursor := -13.75
    var half_gap := 0.62
    for center in centers:
        var segment_end: float = center - half_gap
        var width: float = segment_end - cursor
        if width > 0.08:
            _box(parent, "MuroCerrado", Vector3(cursor + width * 0.5, y + 1.55, z), Vector3(width, 3.1, 0.22), mats.wall)
        _open_door(parent, Vector3(center, y + 1.12, z), 0.0)
        cursor = center + half_gap
    var final_width := 13.75 - cursor
    if final_width > 0.08:
        _box(parent, "MuroCerrado", Vector3(cursor + final_width * 0.5, y + 1.55, z), Vector3(final_width, 3.1, 0.22), mats.wall)
func _room_divider(parent: Node, y: float, z: float, gaps: Array[float] = []) -> void:
    # Tramos de pared con huecos amplios para puertas y lectura de ruta.
    var x_points := [-10.5, -5.25, 0.0, 5.25, 10.5]
    for x in x_points:
        if x in gaps:
            continue
        _box(parent, "Tabique", Vector3(x, y + 1.55, z), Vector3(4.0, 3.1, 0.22), mats.wall)

func _floor_shell(index: int, title: String, dark := false) -> Node3D:
    var level := Node3D.new()
    level.name = title.replace(" ", "_")
    add_child(level)
    var y := index * FLOOR_H
    var floor_mat: Material = mats.roof if index == 5 else mats.floor
    if index == 0:
        _box(level, "LosaCompleta", Vector3(0, y - 0.18, 0), Vector3(BUILDING_W, 0.35, BUILDING_D), floor_mat)
    else:
        # La losa se divide para dejar un hueco real sobre la escalera A.
        _box(level, "LosaPrincipal", Vector3(2.1, y - 0.18, 0), Vector3(23.6, 0.35, BUILDING_D), floor_mat)
        _box(level, "LosaOesteNorte", Vector3(-11.8, y - 0.18, -5.0), Vector3(4.2, 0.35, 10.0), floor_mat)
        _box(level, "DescansoEscalera", Vector3(-11.8, y - 0.18, -0.75), Vector3(4.2, 0.35, 1.5), floor_mat)
    if index < 5:
        var ceiling := Node3D.new()
        ceiling.name = "Ceiling"
        level.add_child(ceiling)
        # Techo independiente con hueco alineado sobre la escalera A.
        _box(ceiling, "TechoPrincipal", Vector3(2.1, y + 3.12, 0), Vector3(23.6, 0.22, BUILDING_D), mats.dark_wall)
        _box(ceiling, "TechoOesteNorte", Vector3(-11.8, y + 3.12, -5.0), Vector3(4.2, 0.22, 10.0), mats.dark_wall)
        _box(ceiling, "TechoDescanso", Vector3(-11.8, y + 3.12, -0.75), Vector3(4.2, 0.22, 1.5), mats.dark_wall)
    var wall_mat: Material = mats.dark_wall if dark else mats.wall
    _box(level, "MuroNorte", Vector3(0, y + 1.55, -9.9), Vector3(BUILDING_W, 3.1, 0.25), wall_mat)
    _box(level, "MuroOeste", Vector3(-13.9, y + 1.55, 0), Vector3(0.25, 3.1, BUILDING_D), wall_mat)
    _box(level, "MuroEste", Vector3(13.9, y + 1.55, 0), Vector3(0.25, 3.1, BUILDING_D), wall_mat)
    _label(level, title, Vector3(0, y + 2.7, -9.5), Color("f3f0e7"), 56)
    return level

func _desk(parent: Node, pos: Vector3, rotation_y := 0.0) -> void:
    var desk := _box(parent, "Escritorio", pos, Vector3(1.6, 0.72, 0.75), mats.wood)
    desk.rotation.y = rotation_y

func _stairs(parent: Node, from_y: float, x := -11.8, z_start := 7.7) -> void:
    for i in range(16):
        var step_y := from_y + 0.125 + i * 0.25
        var step_z := z_start - i * 0.48
        _box(parent, "Escalon_%02d" % i, Vector3(x, step_y, step_z), Vector3(2.4, 0.25, 0.52), mats.metal)
    # Rampa invisible para que CharacterBody3D pueda recorrer los escalones sin atascarse.
    var ramp_body := StaticBody3D.new()
    ramp_body.name = "RampaColisionEscalera"
    ramp_body.position = Vector3(x, from_y + 2.08, 4.1)
    ramp_body.rotation_degrees.x = 29.0
    parent.add_child(ramp_body)
    var ramp_shape_node := CollisionShape3D.new()
    var ramp_shape := BoxShape3D.new()
    ramp_shape.size = Vector3(2.2, 0.16, 8.3)
    ramp_shape_node.shape = ramp_shape
    ramp_body.add_child(ramp_shape_node)

func _open_door(parent: Node, pos: Vector3, yaw_degrees := 0.0) -> void:
    var door := AnimatableBody3D.new()
    door.name = "PuertaInteractiva"
    door.set_script(DOOR_SCRIPT)
    var hinge_offset := Basis(Vector3.UP, deg_to_rad(yaw_degrees)) * Vector3(-0.48, 0, 0)
    door.position = pos + hinge_offset
    door.rotation_degrees.y = yaw_degrees
    parent.add_child(door)

func _stair_enclosure(parent: Node, y: float) -> void:
    # Caja cerrada de escalera con dos accesos: entrada inferior y salida del descanso.
    _box(parent, "MuroEscaleraMedio", Vector3(-9.55, y + 1.55, 4.05), Vector3(0.22, 3.1, 4.6), mats.wall)
    _box(parent, "MuroEscaleraSur", Vector3(-9.55, y + 1.55, 9.05), Vector3(0.22, 3.1, 1.5), mats.wall)
    _box(parent, "MuroEscaleraNorte", Vector3(-9.55, y + 1.55, -0.35), Vector3(0.22, 3.1, 0.7), mats.wall)
    _box(parent, "CierreEscalera", Vector3(-11.75, y + 1.55, 9.75), Vector3(4.5, 3.1, 0.22), mats.wall)
    _open_door(parent, Vector3(-9.35, y + 1.12, 0.65), 90.0)
    _open_door(parent, Vector3(-9.35, y + 1.12, 7.25), 90.0)
    _label(parent, "ESCALERA A", Vector3(-9.1, y + 2.35, 4.0), Color("b9dcff"), 28)

func _classroom_partitions(parent: Node, y: float) -> void:
    # Aulas cerradas al norte con accesos hacia el pasillo central.
    for x in [-7.0, -1.0, 5.0, 10.5]:
        _box(parent, "TabiqueAula", Vector3(x, y + 1.55, -6.45), Vector3(0.22, 3.1, 6.7), mats.wall)
func _build_school() -> void:
    _build_first()
    _build_second()
    _build_third()
    _build_fourth()
    _build_fifth()
    _build_rooftop()

func _enclosed_room(parent: Node, y: float, center: Vector2, room_size: Vector2, room_label: String) -> void:
    var half_w := room_size.x * 0.5
    var half_d := room_size.y * 0.5
    _box(parent, room_label + "_Fondo", Vector3(center.x, y + 1.55, center.y - half_d), Vector3(room_size.x, 3.1, 0.22), mats.wall)
    _box(parent, room_label + "_Izquierda", Vector3(center.x - half_w, y + 1.55, center.y), Vector3(0.22, 3.1, room_size.y), mats.wall)
    _box(parent, room_label + "_Derecha", Vector3(center.x + half_w, y + 1.55, center.y), Vector3(0.22, 3.1, room_size.y), mats.wall)
    var front_piece := (room_size.x - 1.4) * 0.5
    _box(parent, room_label + "_FrenteA", Vector3(center.x - half_w + front_piece * 0.5, y + 1.55, center.y + half_d), Vector3(front_piece, 3.1, 0.22), mats.wall)
    _box(parent, room_label + "_FrenteB", Vector3(center.x + half_w - front_piece * 0.5, y + 1.55, center.y + half_d), Vector3(front_piece, 3.1, 0.22), mats.wall)
    _open_door(parent, Vector3(center.x - 0.55, y + 1.12, center.y + half_d - 0.05), 0.0)
    _label(parent, room_label, Vector3(center.x, y + 2.35, center.y), Color("f2ead8"), 28)

func _build_first_floor_rooms(level: Node3D, y: float) -> void:
    # Fila superior: baños, casilleros y enfermería.
    _box(level, "DivisionBaños", Vector3(-7.8, y + 1.55, -6.55), Vector3(0.22, 3.1, 6.5), mats.wall)
    _box(level, "DivisionEnfermeria", Vector3(4.2, y + 1.55, -6.55), Vector3(0.22, 3.1, 6.5), mats.wall)
    _label(level, "BAÑOS", Vector3(-10.8, y + 2.25, -6.3), Color.WHITE, 30)
    _label(level, "CASILLEROS", Vector3(-1.8, y + 2.25, -6.3), Color.WHITE, 30)
    _label(level, "ENFERMERÍA", Vector3(8.7, y + 2.25, -6.3), Color.WHITE, 30)
    for x in [-11.8, -10.4, -9.0]:
        _box(level, "Sanitario", Vector3(x, y + 0.35, -7.0), Vector3(0.7, 0.7, 1.0), _mat(Color("e7e2d5")), false)
    for x in [-5.8, -3.9, -2.0, -0.1, 1.8]:
        _box(level, "CasilleroInterior", Vector3(x, y + 0.9, -8.6), Vector3(1.15, 1.8, 0.55), mats.blue)
    _box(level, "Camilla", Vector3(8.5, y + 0.48, -7.0), Vector3(3.2, 0.55, 1.25), _mat(Color("d7d9d5")))
    _box(level, "Botiquin", Vector3(11.2, y + 1.35, -9.55), Vector3(0.9, 1.0, 0.16), _mat(Color("e8ece8")), false)

    # Dos oficinas cerradas alrededor del pasillo central.
    _enclosed_room(level, y, Vector2(-3.9, 3.1), Vector2(5.4, 5.0), "DIRECCIÓN")
    _enclosed_room(level, y, Vector2(3.4, 3.1), Vector2(5.2, 5.0), "SEGURIDAD")
    _desk(level, Vector3(-3.9, y + 0.36, 2.5))
    _desk(level, Vector3(3.4, y + 0.36, 2.5))
    _box(level, "MonitoresSeguridad", Vector3(3.4, y + 1.35, 0.72), Vector3(2.2, 1.3, 0.18), mats.dark_wall, false)

    # Escalera B derrumbada y acceso principal bloqueado.
    for i in range(7):
        var debris := _box(level, "Escombro_%02d" % i, Vector3(10.4 + (i % 2) * 1.1, y + 0.35 + i * 0.12, 5.0 + (i % 3) * 0.8), Vector3(1.5, 0.45, 0.7), mats.wood)
        debris.rotation_degrees.y = i * 19.0
    _label(level, "ESCALERA B  CAÍDA", Vector3(10.8, y + 2.5, 5.0), Color("ff7777"), 26)
func _build_entrance_lobby(level: Node3D, y: float) -> void:
    # Vestíbulo ampliado para la puerta principal, la horda y el bloqueo narrativo.
    _box(level, "LosaVestibulo", Vector3(0, y - 0.18, 13.1), Vector3(17.0, 0.35, 6.2), mats.floor)
    var ceiling := level.get_node_or_null("Ceiling") as Node3D
    if ceiling:
        _box(ceiling, "TechoVestibulo", Vector3(0, y + 3.12, 13.1), Vector3(17.0, 0.22, 6.2), mats.dark_wall)
    _box(level, "MuroVestibuloOeste", Vector3(-8.4, y + 1.55, 13.1), Vector3(0.25, 3.1, 6.2), mats.wall)
    _box(level, "MuroVestibuloEste", Vector3(8.4, y + 1.55, 13.1), Vector3(0.25, 3.1, 6.2), mats.wall)
    _box(level, "FrenteEntradaIzq", Vector3(-5.0, y + 1.55, 16.1), Vector3(6.8, 3.1, 0.25), mats.wall)
    _box(level, "FrenteEntradaDer", Vector3(5.0, y + 1.55, 16.1), Vector3(6.8, 3.1, 0.25), mats.wall)
    # Puertas dobles principales visibles, bloqueadas desde dentro.
    _box(level, "PuertaPrincipalIzq", Vector3(-0.82, y + 1.25, 16.0), Vector3(1.55, 2.5, 0.14), mats.metal)
    _box(level, "PuertaPrincipalDer", Vector3(0.82, y + 1.25, 16.0), Vector3(1.55, 2.5, 0.14), mats.metal)
    _label(level, "ENTRADA PRINCIPAL", Vector3(0, y + 2.65, 15.6), Color("ffd1a1"), 34)
    # Barricada irregular: muebles, tablas y archivadores, sin cerrar visualmente todo el vestíbulo.
    for i in range(5):
        var board := _box(level, "TablaBarricada_%02d" % i, Vector3(-3.0 + i * 1.5, y + 0.65 + (i % 2) * 0.42, 14.55), Vector3(2.1, 0.28, 0.38), mats.wood)
        board.rotation_degrees.z = -8.0 + i * 4.0
    _box(level, "ArchivadorBarricadaA", Vector3(-3.7, y + 0.75, 14.0), Vector3(1.2, 1.5, 0.75), mats.metal)
    _box(level, "ArchivadorBarricadaB", Vector3(3.8, y + 0.75, 14.0), Vector3(1.2, 1.5, 0.75), mats.metal)
    _label(level, "BLOQUEADA", Vector3(0, y + 1.9, 14.0), Color("ff5b5b"), 30)
    # Infectados distribuidos para dejar rutas de movimiento y lectura clara del acceso.
    var zombie_positions := [Vector3(-5.8, y + 0.9, 11.2), Vector3(-2.5, y + 0.9, 11.8), Vector3(1.0, y + 0.9, 11.0), Vector3(5.1, y + 0.9, 11.8), Vector3(-4.2, y + 0.9, 13.2), Vector3(0.0, y + 0.9, 12.9), Vector3(4.0, y + 0.9, 13.5)]
    for zombie_position in zombie_positions:
        _enemy(level, zombie_position)
func _build_first() -> void:
    var level := _floor_shell(0, "PRIMER PISO")
    _build_first_floor_rooms(level, 0.0)
    _build_entrance_lobby(level, 0.0)
    _wall_with_doors(level, 0.0, -3.2, [-10.2, -1.8, 8.8])
    _label(level, "DIRECCIÓN", Vector3(-5.4, 2.1, -4.0))
    _label(level, "ENFERMERÍA", Vector3(5.0, 2.1, -4.0))
    _label(level, "SEGURIDAD", Vector3(8.4, 2.1, 2.0))
    for x in [-9.0, -6.5, -4.0]: _box(level, "Casillero", Vector3(x, 0.9, 0.0), Vector3(0.8, 1.8, 0.6), mats.blue)
    _stairs(level, 0.0)
    _stair_enclosure(level, 0.0)

func _build_second() -> void:
    var y := FLOOR_H
    var level := _floor_shell(1, "SEGUNDO PISO")
    _wall_with_doors(level, y, -2.8, [-8.5, -2.0, 4.2, 9.8])
    _label(level, "SECRETARÍA", Vector3(-5.3, y + 2.1, -4.0))
    _label(level, "ARCHIVO", Vector3(3.0, y + 2.1, -4.0))
    _label(level, "DIRECTOR", Vector3(8.4, y + 2.1, 2.0))
    for p in [Vector3(-7, y + .36, -5), Vector3(-4.5, y + .36, -5), Vector3(7.5, y + .36, 2.2)]: _desk(level, p)
    _item(level, "Moneda", Vector3(-3.8, y + 0.08, 1.0))
    _item(level, "Llave307", Vector3(7.5, y + 0.82, 2.2))
    _box(level, "Mapa", Vector3(-0.5, y + 1.7, -9.55), Vector3(3.2, 1.4, 0.08), mats.blue, false)
    _label(level, "MAPA  HORARIO  TELÉFONO", Vector3(-0.5, y + 2.2, -9.2), Color("e5d59a"), 32)
    _stairs(level, y)
    _stair_enclosure(level, y)

func _build_third() -> void:
    var y := FLOOR_H * 2.0
    var level := _floor_shell(2, "TERCER PISO")
    _classroom_partitions(level, y)
    _wall_with_doors(level, y, -3.0, [-10.0, -4.0, 2.0, 8.0, 11.8])
    for i in range(4):
        var x := -9.3 + i * 6.2
        _label(level, "AULA 30%d" % (i + 1), Vector3(x, y + 2.1, -4.0), Color.WHITE, 32)
        _desk(level, Vector3(x, y + .36, -5.5))
    _box(level, "Aula307", Vector3(10.6, y + 1.55, -6.5), Vector3(5.0, 3.1, 0.25), mats.wall)
    _label(level, "AULA 307  BRUNO", Vector3(9.7, y + 2.1, -5.8), Color("ffd25c"), 34)
    for x in [-6.0, -2.0, 2.5, 6.0]:
        _box(level, "Telefono", Vector3(x, y + 0.18, 1.0), Vector3(0.35, 0.22, 0.5), mats.danger, false)
    _enemy(level, Vector3(2.0, y + .9, 3.8)); _enemy(level, Vector3(7.0, y + .9, 1.8))
    _item(level, "Moneda", Vector3(8.2, y + .08, 5.0)); _item(level, "Pilas", Vector3(-1.0, y + .08, -5.0))
    _stairs(level, y)
    _stair_enclosure(level, y)

func _build_fourth() -> void:
    var y := FLOOR_H * 3.0
    var level := _floor_shell(3, "CUARTO PISO")
    _label(level, "CAFETERÍA", Vector3(-3.0, y + 2.2, -4.5), Color.WHITE, 46)
    for x in [-8.5, -4.0, 0.5, 5.0]:
        for z in [-4.5, 0.0, 4.5]: _desk(level, Vector3(x, y + .36, z))
    _box(level, "Cocina", Vector3(9.7, y + 1.0, -5.0), Vector3(7.5, 2.0, 3.8), mats.metal)
    _label(level, "COCINA", Vector3(9.0, y + 2.2, -4.0))
    _box(level, "TiendaSegura", Vector3(9.8, y + 1.5, 4.8), Vector3(7.2, 3.0, 5.8), mats.safe)
    _label(level, "TIENDA SEGURA", Vector3(9.2, y + 2.3, 1.8), Color("87ffad"), 34)
    _enemy(level, Vector3(8.0, y + .9, -2.0))
    for x in [-6.0, -2.5, 1.0]: _box(level, "Bandeja", Vector3(x, y + .06, 2.1), Vector3(0.7, 0.06, 0.45), mats.metal, false)
    _stairs(level, y)
    _stair_enclosure(level, y)

func _build_fifth() -> void:
    var y := FLOOR_H * 4.0
    var level := _floor_shell(4, "QUINTO PISO", true)
    _wall_with_doors(level, y, -3.1, [-8.5, -2.0, 4.5, 10.0])
    _label(level, "OFICINAS", Vector3(-6.2, y + 2.15, -4.0), Color("d6deea"))
    _label(level, "CUARTO ELÉCTRICO", Vector3(4.0, y + 2.15, -4.0), Color("ffd35a"), 32)
    _label(level, "LLAVE AZOTEA", Vector3(8.5, y + 2.15, 3.0), Color("ffd35a"), 32)
    _box(level, "CajaElectrica", Vector3(4.5, y + 1.2, -9.55), Vector3(1.2, 1.5, 0.18), mats.danger, false)
    _desk(level, Vector3(8.5, y + .36, 3.2))
    _item(level, "LlaveAzotea", Vector3(8.5, y + .82, 3.2))
    _enemy(level, Vector3(1.5, y + .9, 1.2))
    _stairs(level, y)
    _stair_enclosure(level, y)

func _build_rooftop() -> void:
    var y := FLOOR_H * 5.0
    var level := _floor_shell(5, "AZOTEA")
    _box(level, "CasetaEscalera", Vector3(-11.2, y + 1.5, 6.7), Vector3(4.5, 3.0, 5.0), mats.dark_wall)
    _label(level, "LLEGADA CAPÍTULO 1", Vector3(-7.0, y + 2.4, 6.0), Color("9ed8ff"), 36)
    for x in [-3.0, 1.0]:
        var tank := MeshInstance3D.new(); tank.position = Vector3(x, y + 1.0, -4.8)
        var cylinder := CylinderMesh.new(); cylinder.top_radius = 1.1; cylinder.bottom_radius = 1.1; cylinder.height = 2.0; cylinder.material = mats.metal
        tank.mesh = cylinder; level.add_child(tank)
    _box(level, "Tablas", Vector3(7.0, y + .25, 3.0), Vector3(4.0, .3, .7), mats.wood)
    _label(level, "EDIFICIO VECINO", Vector3(11.0, y + 2.0, 8.5), Color("e8d18b"), 34)

