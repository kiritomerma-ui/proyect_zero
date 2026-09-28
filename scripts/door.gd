extends AnimatableBody3D

var is_open := false
var busy := false
var closed_rotation := 0.0
var open_angle := deg_to_rad(92.0)

func _ready() -> void:
    add_to_group("interactive_door")
    closed_rotation = rotation.y
    collision_layer = 1
    collision_mask = 1

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.position = Vector3(0.48, 0.0, 0.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.96, 2.25, 0.12)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("5a3f2a")
    material.roughness = 0.72
    mesh.material = material
    mesh_instance.mesh = mesh
    add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.position = Vector3(0.48, 0.0, 0.0)
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.96, 2.25, 0.12)
    collision.shape = shape
    add_child(collision)

func interaction_text() -> String:
    return "F  Cerrar puerta" if is_open else "F  Abrir puerta"

func interact(action_name: String, _player: Node) -> bool:
    if action_name != "open_door" or busy:
        return false
    busy = true
    is_open = not is_open
    var target := closed_rotation + (open_angle if is_open else 0.0)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "rotation:y", target, 0.42)
    tween.finished.connect(func(): busy = false)
    return true

