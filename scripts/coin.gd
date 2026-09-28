extends Area3D

var base_y := 0.0

func _ready() -> void:
    add_to_group("interactive_coin")
    collision_layer = 2
    collision_mask = 0
    base_y = position.y

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.rotation_degrees.x = 90.0
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.20
    mesh.bottom_radius = 0.20
    mesh.height = 0.06
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("ffc933")
    material.metallic = 0.78
    material.roughness = 0.24
    material.emission_enabled = true
    material.emission = Color("8a5700")
    material.emission_energy_multiplier = 1.7
    mesh.material = material
    mesh_instance.mesh = mesh
    add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.34
    collision.shape = shape
    add_child(collision)

func _process(delta: float) -> void:
    rotate_y(delta * 2.4)
    position.y = base_y + sin(Time.get_ticks_msec() * 0.004) * 0.08

func interaction_text() -> String:
    return "E  Recoger moneda"

func interact(action_name: String, player: Node) -> bool:
    if action_name != "pickup":
        return false
    if player.has_method("add_coin"):
        player.add_coin(1)
    queue_free()
    return true

