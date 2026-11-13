extends Node3D
## Vertical slice: a playable, mobile-first 3D district with quests, collisions,
## a chase camera, touch controls and persistent progression.
const SPEED := 5.0
const RUN_SPEED := 8.0
const GRAVITY := 22.0
const SAVE_PATH := "user://savegame.json"

var player: CharacterBody3D
var pivot: Node3D
var cam: Camera3D
var hud: Label
var action_button: Button
var joystick_base: Control
var joystick_knob: ColorRect
var touch_origin := Vector2.ZERO
var touch_axis := Vector2.ZERO
var move_finger := -1
var camera_finger := -1
var yaw := 0.0
var pitch := -0.25
var money := 250
var energy := 80
var mission := 0
var targets: Array[Dictionary] = []
var active_target := -1
var day_time := 8.0
var notice := ""
var notice_timer := 0.0
var ui: CanvasLayer
var sprint := false

func _ready() -> void:
    _build_environment()
    _build_city()
    _build_player()
    _build_ui()
    _load_game()
    _refresh_ui()

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := true) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _mat(color)
    node.position = pos
    parent.add_child(node)
    if solid:
        var body := StaticBody3D.new()
        node.add_child(body)
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
    return node

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#a9c9d9")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#e2e9f0")
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)
    _box(self, Vector3(0,-0.3,0), Vector3(180,0.5,180), Color("#77966c"))
    for x in range(-60, 61, 24):
        _box(self, Vector3(x,0.015,0), Vector3(8,0.07,150), Color("#48525c"), false)
    for z in range(-60, 61, 24):
        _box(self, Vector3(0,0.02,z), Vector3(150,0.08,8), Color("#48525c"), false)

func _build_city() -> void:
    var facades := [Color("#e6c9ae"),Color("#c9d8ce"),Color("#d8c3b5"),Color("#e1d9c5")]
    for ix in range(-2,3):
        for iz in range(-2,3):
            var x := float(ix * 24 + 12)
            var z := float(iz * 24 + 12)
            if ix == 0 and iz == 0:
                continue
            var height := float(9 + posmod(ix * 3 + iz * 7, 4) * 3)
            _box(self, Vector3(x,height/2.0,z),Vector3(11,height,11),facades[posmod(ix+iz,4)])
            _box(self, Vector3(x,height+0.2,z),Vector3(12,0.4,12),Color("#454c55"))
            for level in range(2,int(height)-1,3):
                for offset in [-3.3,0.0,3.3]:
                    _box(self, Vector3(x+offset,float(level),z-5.56),Vector3(1.7,1.8,0.08),Color("#6e9ba8"),false)
                    _box(self, Vector3(x+offset,float(level),z+5.56),Vector3(1.7,1.8,0.08),Color("#6e9ba8"),false)
                    _box(self, Vector3(x-5.56,float(level),z+offset),Vector3(0.08,1.8,1.7),Color("#6e9ba8"),false)
                    _box(self, Vector3(x+5.56,float(level),z+offset),Vector3(0.08,1.8,1.7),Color("#6e9ba8"),false)
    # Real glTF props imported by the free GitHub build pipeline.
    for i in range(8):
        var car_x := float(-38 + (i % 4) * 24)
        var car_z := float(-29 + int(i / 4) * 48)
        _place_glb("res://assets/props/ToyCar.glb", Vector3(car_x,0,car_z), 2.8, float(i % 2) * PI)
    for i in range(12):
        var lx := float(-35 + (i % 4) * 24)
        var lz := float(-35 + int(i / 4) * 24)
        _place_glb("res://assets/props/Lantern.glb", Vector3(lx,0,lz), 2.1, 0.0)
    for i in range(25):
        var x := float(-54 + (i % 5) * 24 + 2)
        var z := float(-54 + int(i / 5) * 24 + 2)
        _tree(Vector3(x,0,z))
    _target("Appartement",Vector3(-7,0,-7),Color("#e2a868"))
    _target("Bureau",Vector3(7,0,-7),Color("#77b9d0"))
    _target("Café",Vector3(7,0,7),Color("#d88d86"))
    _target("Parc",Vector3(-7,0,7),Color("#8dc795"))
    _box(self,Vector3(-7,0.3,-7),Vector3(5,0.5,5),Color("#b99b83"))
    _box(self,Vector3(7,0.3,-7),Vector3(5,0.5,5),Color("#8396ac"))
    _box(self,Vector3(7,0.3,7),Vector3(5,0.5,5),Color("#b97b69"))
    _box(self,Vector3(-7,0.3,7),Vector3(5,0.5,5),Color("#8bb38c"))

func _place_glb(path: String, at: Vector3, desired_height: float, rotation_angle: float) -> void:
    if not ResourceLoader.exists(path):
        return
    var scene_resource := load(path) as PackedScene
    if scene_resource == null:
        return
    var instance := scene_resource.instantiate() as Node3D
    if instance == null:
        return
    add_child(instance)
    var bounds := _visual_bounds(instance)
    var size_y := maxf(bounds.size.y, 0.001)
    var factor := desired_height / size_y
    instance.scale = Vector3.ONE * factor
    instance.position = at - Vector3(0,bounds.position.y * factor,0)
    instance.rotation.y = rotation_angle

func _visual_bounds(root: Node3D) -> AABB:
    var found := false
    var result := AABB(Vector3.ZERO,Vector3.ONE)
    for child in root.find_children("*","MeshInstance3D",true,false):
        var mesh_node := child as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        var box := mesh_node.get_aabb()
        var transform_to_root := root.global_transform.affine_inverse() * mesh_node.global_transform
        var transformed := transform_to_root * box
        if not found:
            result = transformed
            found = true
        else:
            result = result.merge(transformed)
    return result

func _tree(at: Vector3) -> void:
    _box(self,at+Vector3(0,1.2,0),Vector3(0.5,2.4,0.5),Color("#705746"))
    var crown := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.65
    mesh.height = 3.3
    crown.mesh = mesh
    crown.material_override = _mat(Color("#578e68"))
    crown.position = at + Vector3(0,3.2,0)
    add_child(crown)

func _target(label: String, pos: Vector3, color: Color) -> void:
    targets.append({"name":label,"pos":pos})
    var marker := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.75
    mesh.bottom_radius = 0.75
    mesh.height = 0.08
    marker.mesh = mesh
    marker.material_override = _mat(color)
    marker.position = pos + Vector3(0,0.09,0)
    add_child(marker)
    var text := Label3D.new()
    text.text = label
    text.font_size = 70
    text.pixel_size = 0.008
    text.position = pos + Vector3(0,2.5,0)
    text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    text.modulate = Color.WHITE
    text.outline_modulate = Color("#243342")
    add_child(text)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,0.25,0)
    add_child(player)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    player.add_child(shape)
    var body := MeshInstance3D.new()
    var bodymesh := CapsuleMesh.new()
    bodymesh.radius = 0.31
    bodymesh.height = 1.35
    body.mesh = bodymesh
    body.material_override = _mat(Color("#334d71"))
    body.position.y = 0.9
    player.add_child(body)
    var head := MeshInstance3D.new()
    var headmesh := SphereMesh.new()
    headmesh.radius = 0.28
    headmesh.height = 0.56
    head.mesh = headmesh
    head.material_override = _mat(Color("#d7a58c"))
    head.position.y = 1.85
    player.add_child(head)
    # Asset pipeline downloads the glTF model before Godot imports the project.
    # Keep primitive avatar as fallback for offline editing.
    var character_path := "res://assets/characters/CesiumMan.glb"
    if ResourceLoader.exists(character_path):
        var packed := load(character_path) as PackedScene
        if packed != null:
            var character := packed.instantiate()
            player.add_child(character)
            body.visible = false
            head.visible = false
            var character_bounds := _visual_bounds(character)
            var scale_factor := 1.9 / maxf(character_bounds.size.y,0.001)
            character.scale = Vector3.ONE * scale_factor
            character.position.y = -character_bounds.position.y * scale_factor
            var anims := character.find_children("*", "AnimationPlayer", true, false)
            for animation_node in anims:
                var anim_player := animation_node as AnimationPlayer
                if anim_player != null and anim_player.get_animation_list().size() > 0:
                    anim_player.play(anim_player.get_animation_list()[0])
                    break
    pivot = Node3D.new()
    add_child(pivot)
    pivot.global_position = player.global_position + Vector3(0,1.45,0)
    cam = Camera3D.new()
    cam.current = true
    cam.position = Vector3(0,2.0,5.8)
    cam.fov = 64
    pivot.add_child(cam)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    ui.add_child(root)
    hud = Label.new()
    hud.position = Vector2(24,50)
    hud.add_theme_font_size_override("font_size",31)
    hud.add_theme_color_override("font_color",Color.WHITE)
    hud.add_theme_color_override("font_shadow_color",Color.BLACK)
    hud.add_theme_constant_override("shadow_offset_x",2)
    hud.add_theme_constant_override("shadow_offset_y",2)
    root.add_child(hud)
    joystick_base = Control.new()
    joystick_base.anchor_top = 1
    joystick_base.anchor_bottom = 1
    joystick_base.offset_left = 55
    joystick_base.offset_right = 235
    joystick_base.offset_top = -250
    joystick_base.offset_bottom = -70
    root.add_child(joystick_base)
    var bg := ColorRect.new()
    bg.color = Color(0.15,0.2,0.3,0.3)
    bg.size = Vector2(180,180)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.add_child(bg)
    joystick_knob = ColorRect.new()
    joystick_knob.color = Color(1,1,1,0.65)
    joystick_knob.size = Vector2(70,70)
    joystick_knob.position = Vector2(55,55)
    joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick_base.add_child(joystick_knob)
    action_button = Button.new()
    action_button.text = "INTERAGIR"
    action_button.anchor_left = 1
    action_button.anchor_right = 1
    action_button.anchor_top = 1
    action_button.anchor_bottom = 1
    action_button.offset_left = -280
    action_button.offset_right = -30
    action_button.offset_top = -220
    action_button.offset_bottom = -110
    action_button.add_theme_font_size_override("font_size",30)
    action_button.pressed.connect(_interact)
    root.add_child(action_button)
    var save_button := Button.new()
    save_button.text = "SAUVER"
    save_button.anchor_left = 1
    save_button.anchor_right = 1
    save_button.offset_left = -200
    save_button.offset_right = -25
    save_button.offset_top = 45
    save_button.offset_bottom = 110
    save_button.pressed.connect(_save_game)
    root.add_child(save_button)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and move_finger == -1:
                move_finger = event.index
                touch_origin = event.position
            elif camera_finger == -1:
                camera_finger = event.index
        else:
            if event.index == move_finger:
                move_finger = -1
                touch_axis = Vector2.ZERO
            if event.index == camera_finger:
                camera_finger = -1
    elif event is InputEventScreenDrag:
        if event.index == move_finger:
            touch_axis = (event.position-touch_origin).limit_length(95)/95.0
        elif event.index == camera_finger:
            yaw -= event.relative.x*0.004
            pitch = clamp(pitch-event.relative.y*0.003,-0.75,0.25)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x*0.004
        pitch = clamp(pitch-event.relative.y*0.003,-0.75,0.25)

func _physics_process(delta: float) -> void:
    var axis := touch_axis
    axis.x += Input.get_action_strength("ui_right")-Input.get_action_strength("ui_left")
    axis.y += Input.get_action_strength("ui_down")-Input.get_action_strength("ui_up")
    axis = axis.limit_length(1.0)
    var forward := Vector3(-sin(yaw),0,-cos(yaw))
    var right := Vector3(cos(yaw),0,-sin(yaw))
    var movement := right*axis.x+forward*(-axis.y)
    sprint = axis.length() > 0.9
    var speed := RUN_SPEED if sprint else SPEED
    player.velocity.x = movement.x*speed
    player.velocity.z = movement.z*speed
    player.velocity.y -= GRAVITY*delta
    player.move_and_slide()
    if movement.length() > 0.05:
        player.rotation.y = atan2(-movement.x,-movement.z)
    pivot.global_position = player.global_position + Vector3(0,1.45,0)
    pivot.rotation.y = yaw
    cam.rotation.x = pitch
    joystick_knob.position = Vector2(55,55)+touch_axis*48
    active_target = -1
    for i in targets.size():
        if player.global_position.distance_to(targets[i]["pos"]) < 3.6:
            active_target = i
    action_button.disabled = active_target == -1
    action_button.text = "ENTRER : "+str(targets[active_target]["name"]) if active_target >= 0 else "APPROCHER"
    day_time += delta*0.008
    if day_time >= 24:
        day_time -= 24
    if notice_timer > 0:
        notice_timer -= delta
    _refresh_ui()

func _interact() -> void:
    if active_target == -1:
        return
    var place: String = targets[active_target]["name"]
    if place == "Bureau":
        if mission == 1:
            money += 100
            energy -= 12
            mission = 2
            _notify("Mission accomplie : +100 €")
        else:
            _notify("Bienvenue au bureau")
    elif place == "Café":
        if money >= 12:
            money -= 12
            energy = mini(100,energy+15)
            if mission == 2:
                mission = 3
            _notify("Pause café : -12 €, +15 énergie")
        else:
            _notify("Solde insuffisant")
    elif place == "Appartement":
        energy = mini(100,energy+30)
        if mission == 0:
            mission = 1
        elif mission == 3:
            mission = 4
        _notify("Repos à la maison : +30 énergie")
    elif place == "Parc":
        energy = mini(100,energy+8)
        _notify("Promenade au parc : +8 énergie")
    _save_game()

func _notify(msg: String) -> void:
    notice = msg
    notice_timer = 4.0

func _refresh_ui() -> void:
    var missions := ["Rentre chez toi","Va travailler au bureau","Prends un café","Retourne à l'appartement","Journée terminée !"]
    var line := missions[clampi(mission,0,missions.size()-1)]
    hud.text = "MÉTRO, BOULOT, ÉVOLUTION\n%d €  |  Énergie %d/100\nObjectif : %s" % [money,energy,line]
    if notice_timer > 0:
        hud.text += "\n"+notice

func _save_game() -> void:
    var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify({"money":money,"energy":energy,"mission":mission,"position":[player.position.x,player.position.y,player.position.z]}))
    file.close()
    _notify("Progression sauvegardée")

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not (parsed is Dictionary):
        return
    money = int(parsed.get("money",250))
    energy = int(parsed.get("energy",80))
    mission = int(parsed.get("mission",0))
    var p: Array = parsed.get("position",[])
    if p.size() == 3:
        player.position = Vector3(float(p[0]),float(p[1]),float(p[2]))
