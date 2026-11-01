extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var player: CharacterBody3D
var arena: Node3D
var enemies: Array[Node] = []
var spawn_timer := 0.0
var game_started := false
var game_mode := "single"
var health := 12
var kills := 0
var wave := 1
var health_label: Label
var stats_label: Label
var message_label: Label
var mobile_controls: Control
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_touch := -1
var look_touch := -1
var last_look := Vector2.ZERO
var fire_button_down := false
var fire_touch := -1
var medkit_timer := 12.0
var medkits: Array[Node3D] = []
var weapon_label: Label
var switch_weapon_button: Button
var boss_spawned_wave := 0
var kills_in_wave: int = 0
var is_paused: bool = false
var pause_layer: CanvasLayer
var pause_panel: VBoxContainer
var selected_map: int = 0
var arena_map_index: int = -1
var mouse_sensitivity: float = 0.003
var hit_marker: Label
var screen_shake_time: float = 0.0
var screen_shake_strength: float = 0.0
var boss_health_label: Label
var fire_ability_button: Button
var fire_ability_unlocked := false
var fire_ability_cooldown := 0.0
var electric_rifle_unlocked := false
var toxic_gun_unlocked := false
var boss_active: Node = null
var special_event_active := ""
var special_event_timer := 0.0
var last_special_event_wave := -999
var high_score_kills := 0
var high_score_wave := 1
var high_score_label: Label
var rare_event_active := false
var gunner_weapon_unlocked := false
var dash_button: Button
var sandbox_fly_button: Button
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var achievements: Dictionary = {}
var player_username: String = ""
var name_entry_layer: CanvasLayer
var name_entry_input: LineEdit
var name_entry_error: Label
var friend_easter_egg_playing: bool = false
var menu_username_label: Label
var sandbox_mode := false
var sandbox_panel: PanelContainer
var sandbox_toggle_button: Button
var sandbox_fly_label: Label
var sandbox_requested_kind := ""
var sandbox_vertical_input := 0.0
var secret_door: StaticBody3D
var secret_door_open := false
var multi_gun_unlocked := false
var secret_pickup: Area3D

# Multiplayer state. Room codes are direct IPv4:port addresses: LAN addresses work
# on the same network; internet hosting requires forwarding UDP 24567 to the host.
const MULTIPLAYER_PORT := 24567
const MAX_REMOTE_PLAYERS := 7 # 7 clients + the host = 8 players total.
var network_active := false
var network_is_host := false
var network_room_mode := "single"
var network_server_code := ""
var network_sync_timer := 0.0
var network_enemy_sync_timer := 0.0
var network_stats_sync_timer := 0.0
var network_next_enemy_id := 1
var network_remote_players: Dictionary = {}
var network_enemy_nodes: Dictionary = {}
var network_dialog_layer: CanvasLayer
var network_status_text := ""
var network_enemy_target_peer := 1
var network_arena_seed := 0
var network_room_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_gunner_weapon_unlock()
    multi_gun_unlocked = _is_permanent_unlock("multi_gun")
    _load_achievements()
    _load_profile()
    _build_arena()
    _build_menu()
    _build_pause_menu()
    _connect_multiplayer_signals()
    get_viewport().size_changed.connect(_layout_menu_panels)
    _layout_menu_panels()
    if player_username.strip_edges().is_empty():
        menu_layer.visible = false
        _show_name_entry()

func _mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 1.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    # Color-matched, low-resolution pixel-art tiles keep all three arenas cohesive.
    var luminance := (c.r + c.g + c.b) / 3.0
    if c.g > c.r * 1.12 and c.g > c.b * 1.08:
        m.albedo_texture = load("res://textures/foliage_pixel.png")
    elif c.r > c.g * 1.18 and c.r > c.b * 1.12:
        m.albedo_texture = load("res://textures/rust_pixel.png")
    elif luminance < 0.22:
        m.albedo_texture = load("res://textures/ground_pixel.png")
    else:
        m.albedo_texture = load("res://textures/concrete_pixel.png")
    return m

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation.y = yaw
    var mesh := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mesh.mesh = bm
    mesh.material_override = _mat(color)
    body.add_child(mesh)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    parent.add_child(body)

func _build_arena() -> void:
    if is_instance_valid(arena):
        arena.queue_free()
    arena = Node3D.new()
    arena_map_index = selected_map
    arena.name = "Arena"
    add_child(arena)
    var floor_color: Color = Color(0.12, 0.16, 0.17)
    var obstacle_color: Color = Color(0.28, 0.18, 0.13)
    if selected_map == 1:
        floor_color = Color(0.16, 0.17, 0.19)
        obstacle_color = Color(0.25, 0.27, 0.30)
    elif selected_map == 2:
        floor_color = Color(0.12, 0.19, 0.12)
        obstacle_color = Color(0.20, 0.27, 0.16)
    _add_box(arena, Vector3(0, -0.5, 0), Vector3(70, 1, 70), floor_color)
    # Solid perimeter walls keep the player and enemies inside the arena on every map.
    var wall_color: Color = obstacle_color.darkened(0.12)
    _add_box(arena, Vector3(0, 2.0, -34.5), Vector3(70, 5.0, 1.0), wall_color)
    # The south wall has a concealed doorway at its center for the Easter egg.
    _add_box(arena, Vector3(-19.0, 2.0, 34.5), Vector3(32.0, 5.0, 1.0), wall_color)
    _add_box(arena, Vector3(19.0, 2.0, 34.5), Vector3(32.0, 5.0, 1.0), wall_color)
    _build_multi_gun_secret_room(wall_color)
    _add_box(arena, Vector3(-34.5, 2.0, 0), Vector3(1.0, 5.0, 70), wall_color)
    _add_box(arena, Vector3(34.5, 2.0, 0), Vector3(1.0, 5.0, 70), wall_color)
    for i in range(18):
        var a := TAU * float(i) / 18.0
        var r := 18.0 + float(i % 3) * 2.0
        _add_box(arena, Vector3(cos(a) * r, 1.2, sin(a) * r),
            Vector3(2.5, 2.4 + float(i % 3), 1.4), obstacle_color, a)
    for i in range(12):
        _add_box(arena, Vector3(randf_range(-13, 13), 0.8, randf_range(-13, 13)),
            Vector3(1.7, 1.6, 1.7), obstacle_color.lightened(0.08), randf_range(0, TAU))
    if selected_map == 1:
        # Military yard: chunky shipping containers and concrete barriers.
        for i in range(5):
            var container_x: float = -12.0 + float(i) * 6.0
            _add_box(arena, Vector3(container_x, 1.1, -7.0), Vector3(4.8, 2.2, 2.0), Color(0.16, 0.25, 0.20), 0.0)
        for i in range(4):
            _add_box(arena, Vector3(-8.0 + float(i) * 5.0, 0.55, 8.0), Vector3(2.8, 1.1, 0.7), Color(0.38, 0.40, 0.37), 0.0)
    elif selected_map == 2:
        # Forest: tree trunks have collision; canopies are low-poly green spheres.
        for i in range(14):
            var tree_x: float = randf_range(-22.0, 22.0)
            var tree_z: float = randf_range(-22.0, 22.0)
            if absf(tree_x) + absf(tree_z) < 10.0:
                tree_x += 11.0
            _add_box(arena, Vector3(tree_x, 1.2, tree_z), Vector3(0.65, 2.4, 0.65), Color(0.24, 0.13, 0.07))
            var canopy := MeshInstance3D.new()
            var canopy_mesh := SphereMesh.new()
            canopy_mesh.radius = 1.65
            canopy_mesh.height = 3.3
            canopy.mesh = canopy_mesh
            canopy.position = Vector3(tree_x, 3.0, tree_z)
            canopy.material_override = _mat(Color(0.08, 0.25 + randf() * 0.12, 0.09))
            arena.add_child(canopy)
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.035, 0.05, 0.11)
    sky_mat.sky_horizon_color = Color(0.36, 0.19, 0.13)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.48, 0.4)
    env.ambient_light_energy = 0.7
    env_node.environment = env
    arena.add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -30, 0)
    sun.light_energy = 1.1
    arena.add_child(sun)
func _build_multi_gun_secret_room(wall_color: Color) -> void:
    # Hidden room lies beyond the south arena wall. A solid door blocks it until
    # the Electric Brute is defeated with the Electric Rifle in a normal run.
    secret_door = StaticBody3D.new()
    secret_door.name = "SecretDoor"
    secret_door.position = Vector3(0, 2.0, 34.5)
    var door_mesh := MeshInstance3D.new()
    var door_box := BoxMesh.new()
    door_box.size = Vector3(6.0, 5.0, 1.0)
    door_mesh.mesh = door_box
    door_mesh.material_override = _mat(Color(0.12, 0.17, 0.19))
    secret_door.add_child(door_mesh)
    var door_col := CollisionShape3D.new()
    var door_shape := BoxShape3D.new()
    door_shape.size = Vector3(6.0, 5.0, 1.0)
    door_col.shape = door_shape
    secret_door.add_child(door_col)
    secret_door.set_meta("door_collision", door_col)
    arena.add_child(secret_door)
    # Smooth, gently sloped entrance ramp: bridges the arena floor (y=0)
    # to the slightly lower secret-room floor so the player can walk in/out.
    var ramp := StaticBody3D.new()
    ramp.name = "SecretRoomEntranceRamp"
    ramp.position = Vector3(0.0, -0.12, 37.5)
    ramp.rotation.x = deg_to_rad(-4.0)
    var ramp_mesh := MeshInstance3D.new()
    var ramp_box := BoxMesh.new()
    ramp_box.size = Vector3(4.5, 0.24, 7.0)
    ramp_mesh.mesh = ramp_box
    ramp_mesh.material_override = _mat(Color(0.16, 0.19, 0.20))
    ramp.add_child(ramp_mesh)
    var ramp_collision := CollisionShape3D.new()
    var ramp_shape := BoxShape3D.new()
    ramp_shape.size = ramp_box.size
    ramp_collision.shape = ramp_shape
    ramp.add_child(ramp_collision)
    arena.add_child(ramp)
    # Small, enclosed room with a lit floor and the two-line developer message.
    _add_box(arena, Vector3(0, -0.48, 41.0), Vector3(12.0, 0.2, 12.0), Color(0.075, 0.09, 0.10))
    _add_box(arena, Vector3(-6.0, 2.0, 41.0), Vector3(0.5, 5.0, 12.0), wall_color)
    _add_box(arena, Vector3(6.0, 2.0, 41.0), Vector3(0.5, 5.0, 12.0), wall_color)
    _add_box(arena, Vector3(0, 2.0, 47.0), Vector3(12.0, 5.0, 0.5), wall_color)
    var message := Label3D.new()
    message.text = "How did you even find this?\n\nI really thought nobody would find this."
    message.font_size = 34
    message.pixel_size = 0.012
    message.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    message.position = Vector3(0, 2.35, 46.68)
    message.rotation.y = PI
    message.modulate = Color(0.95, 0.88, 0.66)
    message.no_depth_test = false
    arena.add_child(message)
    # Multi-barrel pickup is a visible, glowing world object with a proximity trigger.
    var pickup := Node3D.new()
    pickup.name = "MultiGunPickup"
    pickup.position = Vector3(0, 0.45, 40.0)
    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(0.75, 0.22, 0.42)
    body.mesh = body_mesh
    body.material_override = _mat(Color(0.20, 0.24, 0.22))
    pickup.add_child(body)
    for i in range(4):
        var barrel := MeshInstance3D.new()
        var barrel_mesh := CylinderMesh.new()
        barrel_mesh.top_radius = 0.055
        barrel_mesh.bottom_radius = 0.055
        barrel_mesh.height = 0.65
        barrel.mesh = barrel_mesh
        barrel.rotation.x = PI / 2.0
        barrel.position = Vector3(-0.24 + float(i) * 0.16, 0.04, -0.40)
        barrel.material_override = _mat([Color(0.4, 1.0, 0.15), Color(0.15, 0.8, 1.0), Color(1.0, 0.35, 0.1), Color(0.8, 0.82, 0.78)][i])
        pickup.add_child(barrel)
    var glow := OmniLight3D.new()
    glow.light_color = Color(0.35, 1.0, 0.4)
    glow.light_energy = 1.4
    glow.omni_range = 4.0
    pickup.add_child(glow)
    arena.add_child(pickup)
    secret_pickup = Area3D.new()
    secret_pickup.name = "MultiGunPickupArea"
    secret_pickup.position = Vector3(0, 0.8, 40.0)
    var pickup_shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.8
    pickup_shape.shape = sphere
    secret_pickup.add_child(pickup_shape)
    secret_pickup.body_entered.connect(_on_multi_gun_pickup_entered)
    arena.add_child(secret_pickup)
    pickup.visible = not multi_gun_unlocked
    secret_pickup.monitoring = not multi_gun_unlocked
    secret_pickup.set_meta("pickup_visual", pickup)
    secret_door_open = _is_permanent_unlock("multi_gun_door")
    if secret_door_open:
        _open_secret_door()

func _open_secret_door() -> void:
    secret_door_open = true
    if is_instance_valid(secret_door):
        var collision = secret_door.get_meta("door_collision")
        if is_instance_valid(collision):
            collision.set_deferred("disabled", true)
        var mesh := secret_door.get_child(0) as MeshInstance3D
        if is_instance_valid(mesh):
            mesh.visible = false

func _on_multi_gun_pickup_entered(body: Node3D) -> void:
    if body != player or sandbox_mode or multi_gun_unlocked or not secret_door_open:
        return
    if network_active and not network_is_host:
        rpc_id(1, "_rpc_request_multi_gun_pickup")
        return
    _grant_multi_gun()

func _grant_multi_gun() -> void:
    if multi_gun_unlocked or sandbox_mode or not secret_door_open:
        return
    multi_gun_unlocked = true
    _save_permanent_unlock("multi_gun")
    if is_instance_valid(player):
        player.unlock_multi_gun()
    if network_active and network_is_host:
        rpc("_rpc_apply_multiplayer_unlock", "multi_gun")
    _hide_multi_gun_pickup()
    _show_message("MULTI-GUN UNLOCKED!")

func _hide_multi_gun_pickup() -> void:
    if is_instance_valid(secret_pickup):
        secret_pickup.set_deferred("monitoring", false)
        var visual = secret_pickup.get_meta("pickup_visual")
        if is_instance_valid(visual):
            visual.queue_free()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_multi_gun_pickup() -> void:
    if not network_active or not network_is_host or sandbox_mode or multi_gun_unlocked or not secret_door_open:
        return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 1 or not multiplayer.get_peers().has(sender) or not network_remote_players.has(sender):
        return
    var remote = network_remote_players[sender]
    if not is_instance_valid(remote) or remote.global_position.distance_to(Vector3(0, 0.8, 40.0)) > 3.0:
        return
    _grant_multi_gun()

func _build_menu() -> void:
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    var bg := ColorRect.new()
    bg.color = Color(0.025, 0.035, 0.055, 0.96)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(bg)
    var panel := VBoxContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.size = Vector2(460, 540)
    panel.position = -panel.size * 0.5
    panel.add_theme_constant_override("separation", 12)
    menu_layer.add_child(panel)
    var title := Label.new()
    title.text = "RETRO UNDEAD"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.96, 0.42, 0.18))
    panel.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "PIXEL WARZONE // SURVIVE THE NIGHT"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color(0.55, 0.75, 0.67))
    panel.add_child(subtitle)
    high_score_label = Label.new()
    high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    high_score_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    panel.add_child(high_score_label)
    menu_username_label = Label.new()
    menu_username_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_username_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.68))
    panel.add_child(menu_username_label)
    _refresh_username_display()
    _load_high_score()
    var reset_button := Button.new()
    reset_button.text = "RESET PROGRESS"
    reset_button.tooltip_text = "Erase all local progress and start fresh"
    reset_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    reset_button.offset_left = -210.0
    reset_button.offset_top = 16.0
    reset_button.offset_right = -16.0
    reset_button.offset_bottom = 60.0
    reset_button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.72))
    reset_button.pressed.connect(_confirm_reset_progress)
    menu_layer.add_child(reset_button)
    _menu_button(panel, "PLAY → NORMAL MODE", func(): start_game("single"))
    _menu_button(panel, "SANDBOX MODE", func(): start_game("sandbox"))
    _menu_button(panel, "CONTINUE SAVED GAME", _continue_saved_game)
    _menu_button(panel, "WEAPON COLLECTION", func(): _show_weapon_collection())
    _menu_button(panel, "ACHIEVEMENTS & TITLES", func(): _show_achievements())
    _menu_button(panel, "CHANGE USERNAME", _change_username)
    var multiplayer_row := HBoxContainer.new()
    multiplayer_row.add_theme_constant_override("separation", 8)
    multiplayer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_child(multiplayer_row)
    _menu_button_in_row(multiplayer_row, "MULTIPLAYER - HOST", _show_host_dialog)
    _menu_button_in_row(multiplayer_row, "MULTIPLAYER - JOIN", _show_join_dialog)
    var controls := Label.new()
    controls.text = "MOBILE: LEFT STICK MOVE • DRAG RIGHT SIDE TO LOOK\nFIRE BUTTON • DESKTOP: WASD + MOUSE + CLICK"
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_theme_color_override("font_color", Color(0.72, 0.75, 0.79))
    panel.add_child(controls)

func _menu_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 46)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(action)
    parent.add_child(b)

func _menu_button_in_row(parent: HBoxContainer, caption: String, action: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(0, 46)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 14)
    b.pressed.connect(action)
    parent.add_child(b)

func _load_profile() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://retro_undead_profile.cfg") == OK:
        player_username = str(cfg.get_value("profile", "username", "")).strip_edges()

func _save_profile() -> bool:
    var cfg := ConfigFile.new()
    cfg.set_value("profile", "username", player_username)
    return cfg.save("user://retro_undead_profile.cfg") == OK

func _refresh_username_display() -> void:
    if is_instance_valid(menu_username_label):
        menu_username_label.text = "SURVIVOR: " + player_username.to_upper()

func _change_username() -> void:
    if is_instance_valid(menu_layer):
        menu_layer.visible = false
    _show_name_entry()

func _show_name_entry() -> void:
    if is_instance_valid(name_entry_layer):
        name_entry_layer.queue_free()
    name_entry_layer = CanvasLayer.new()
    name_entry_layer.layer = 20
    add_child(name_entry_layer)
    var bg := ColorRect.new()
    bg.color = Color(0.015, 0.025, 0.035, 0.98)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    name_entry_layer.add_child(bg)
    var panel := VBoxContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.size = Vector2(420, 250)
    panel.position = -panel.size * 0.5
    panel.add_theme_constant_override("separation", 14)
    name_entry_layer.add_child(panel)
    var title := Label.new()
    title.text = "WELCOME, SURVIVOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.96, 0.42, 0.18))
    panel.add_child(title)
    var prompt := Label.new()
    prompt.text = "What should we call you?"
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel.add_child(prompt)
    name_entry_input = LineEdit.new()
    name_entry_input.placeholder_text = "Enter your username"
    name_entry_input.max_length = 20
    name_entry_input.custom_minimum_size = Vector2(0, 44)
    name_entry_input.text = player_username
    name_entry_input.text_submitted.connect(func(_value: String): _submit_username())
    panel.add_child(name_entry_input)
    name_entry_error = Label.new()
    name_entry_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_entry_error.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
    panel.add_child(name_entry_error)
    _menu_button(panel, "CONFIRM NAME", _submit_username)
    name_entry_input.grab_focus()

func _submit_username() -> void:
    if not is_instance_valid(name_entry_input):
        return
    var candidate := name_entry_input.text.strip_edges()
    candidate = candidate.replace("\n", " ").replace("\r", " ")
    var secret_name := candidate.to_upper()
    if secret_name in ["FRIEND", "DEVICE_FRIEND", "PNG.FRIEND"]:
        if not friend_easter_egg_playing:
            _play_friend_easter_egg()
        return
    if candidate.is_empty():
        if is_instance_valid(name_entry_error):
            name_entry_error.text = "Please enter a username."
        return
    if candidate.length() > 20:
        candidate = candidate.substr(0, 20)
    player_username = candidate
    if not _save_profile():
        if is_instance_valid(name_entry_error):
            name_entry_error.text = "Could not save your name. Please try again."
        return
    if is_instance_valid(name_entry_layer):
        name_entry_layer.queue_free()
    name_entry_layer = null
    if is_instance_valid(menu_layer):
        menu_layer.visible = true
    _refresh_username_display()

func _play_friend_easter_egg() -> void:
    if friend_easter_egg_playing or not is_instance_valid(name_entry_input):
        return
    friend_easter_egg_playing = true
    name_entry_input.editable = false
    var confirm_button: Button = null
    if is_instance_valid(name_entry_layer):
        var buttons := name_entry_layer.find_children("*", "Button", true, false)
        if not buttons.is_empty():
            confirm_button = buttons[0] as Button
            if is_instance_valid(confirm_button):
                confirm_button.disabled = true

    await _friend_glitch(0.75)

    var video_layer := CanvasLayer.new()
    video_layer.layer = 30
    add_child(video_layer)
    var video_player := VideoStreamPlayer.new()
    video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    video_player.expand = true
    video_player.stream = load("res://video/friend_easter_egg.ogv") as VideoStream
    video_player.autoplay = false
    video_layer.add_child(video_player)

    if video_player.stream != null:
        video_player.play()
        await video_player.finished
    else:
        push_error("FRIEND Easter egg video could not be loaded.")

    await _friend_glitch(0.75)
    video_layer.queue_free()

    if is_instance_valid(name_entry_layer):
        name_entry_layer.visible = true
    if is_instance_valid(name_entry_input):
        name_entry_input.editable = true
        name_entry_input.clear()
        name_entry_input.grab_focus()
    if is_instance_valid(confirm_button):
        confirm_button.disabled = false
    if is_instance_valid(name_entry_error):
        name_entry_error.text = ""
    friend_easter_egg_playing = false


func _friend_glitch(duration: float) -> void:
    var glitch_layer := CanvasLayer.new()
    glitch_layer.layer = 40
    add_child(glitch_layer)
    var flash := ColorRect.new()
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glitch_layer.add_child(flash)

    var elapsed: float = 0.0
    while elapsed < duration:
        var alpha: float = randf_range(0.12, 0.82)
        var glitch_colors: Array[Color] = [
            Color(0.0, 0.95, 0.85, alpha),
            Color(0.95, 0.05, 0.32, alpha),
            Color(0.88, 0.92, 1.0, alpha),
            Color(0.015, 0.02, 0.035, 0.94)
        ]
        flash.color = glitch_colors[randi_range(0, glitch_colors.size() - 1)]
        await get_tree().create_timer(randf_range(0.035, 0.09)).timeout
        elapsed += 0.07

    glitch_layer.queue_free()


func _confirm_reset_progress() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.title = "RESET ALL PROGRESS?"
    dialog.dialog_text = "This permanently erases your username, all unlocked weapons (including the Toxic Gun and Multi-Gun), Fireball, secret-room progress, achievements, titles, high scores, and saved run. This cannot be undone.\n\nAre you sure you want to reset everything?"
    dialog.ok_button_text = "YES, RESET"
    dialog.cancel_button_text = "CANCEL"
    dialog.confirmed.connect(func():
        dialog.queue_free()
        _reset_all_progress()
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(520, 260))

func _reset_all_progress() -> void:
    get_tree().paused = false
    is_paused = false
    if game_started:
        _return_to_menu()
    var files_to_remove := [
        "user://retro_undead_profile.cfg",
        "user://retro_undead_unlocks.cfg",
        "user://retro_undead_achievements.cfg",
        "user://retro_undead_high_score.cfg",
        "user://retro_undead_save.cfg"
    ]
    for path in files_to_remove:
        if FileAccess.file_exists(path):
            var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
            if err != OK:
                _show_notice("Could not remove all save data. Please restart the game and try again.")
                return
    player_username = ""
    gunner_weapon_unlocked = false
    electric_rifle_unlocked = false
    toxic_gun_unlocked = false
    multi_gun_unlocked = false
    secret_door_open = false
    fire_ability_unlocked = false
    if is_instance_valid(player):
        if player.unlocked_weapons.size() > 9:
            player.unlocked_weapons[8] = false # Toxic / acid gun
            player.unlocked_weapons[9] = false # Multi-Gun
        if player.weapon_index == 8 or player.weapon_index == 9:
            player.weapon_index = 0
            player._rebuild_weapon_model()
    achievements.clear()
    high_score_kills = 0
    high_score_wave = 1
    if is_instance_valid(menu_layer):
        menu_layer.visible = false
    _show_name_entry()

func _connect_multiplayer_signals() -> void:
    if not multiplayer.peer_connected.is_connected(_on_network_peer_connected):
        multiplayer.peer_connected.connect(_on_network_peer_connected)
    if not multiplayer.peer_disconnected.is_connected(_on_network_peer_disconnected):
        multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
    if not multiplayer.connected_to_server.is_connected(_on_network_connected):
        multiplayer.connected_to_server.connect(_on_network_connected)
    if not multiplayer.connection_failed.is_connected(_on_network_connection_failed):
        multiplayer.connection_failed.connect(_on_network_connection_failed)
    if not multiplayer.server_disconnected.is_connected(_on_network_server_disconnected):
        multiplayer.server_disconnected.connect(_on_network_server_disconnected)

func _default_lan_address() -> String:
    for addr in IP.get_local_addresses():
        if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
            continue
        if addr.begins_with("10.") or addr.begins_with("192.168.") or addr.begins_with("172."):
            return addr
    for addr in IP.get_local_addresses():
        if not addr.contains(":") and not addr.begins_with("127."):
            return addr
    return "127.0.0.1"

func _network_popup(title_text: String, description: String) -> Dictionary:
    if is_instance_valid(network_dialog_layer):
        network_dialog_layer.queue_free()
    network_dialog_layer = CanvasLayer.new()
    network_dialog_layer.layer = 30
    add_child(network_dialog_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.02, 0.035, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    network_dialog_layer.add_child(shade)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(420, 320)
    panel.position = Vector2(-210, -160)
    network_dialog_layer.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color(1.0, 0.48, 0.20))
    box.add_child(title)
    var desc := Label.new()
    desc.text = description
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.custom_minimum_size.y = 54
    box.add_child(desc)
    return {"box": box, "panel": panel}

func _network_popup_close() -> void:
    if is_instance_valid(network_dialog_layer):
        network_dialog_layer.queue_free()
    network_dialog_layer = null

func _show_host_dialog() -> void:
    var ui := _network_popup("HOST MULTIPLAYER", "Choose a mode and share the room code. LAN works on the same Wi-Fi. Internet hosting requires UDP port 24567 forwarded to this device.")
    var box: VBoxContainer = ui.box
    var mode_select := OptionButton.new()
    mode_select.add_item("Normal Mode", 0)
    mode_select.add_item("Sandbox Mode", 1)
    box.add_child(mode_select)
    var address_label := Label.new()
    address_label.text = "Room code address (LAN IP by default; public IP for internet):"
    address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(address_label)
    var address_input := LineEdit.new()
    address_input.text = _default_lan_address()
    address_input.placeholder_text = "192.168.1.20 or your public IPv4"
    box.add_child(address_input)
    var hint := Label.new()
    hint.text = "Players: 2–8 total • UDP port 24567"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(hint)
    var buttons := HBoxContainer.new()
    box.add_child(buttons)
    var cancel := Button.new()
    cancel.text = "CANCEL"
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(_network_popup_close)
    buttons.add_child(cancel)
    var host_button := Button.new()
    host_button.text = "HOST GAME"
    host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    host_button.pressed.connect(func():
        var mode := "sandbox" if mode_select.selected == 1 else "single"
        _network_popup_close()
        _start_network_host(mode, address_input.text)
    )
    buttons.add_child(host_button)

func _show_join_dialog() -> void:
    var ui := _network_popup("JOIN MULTIPLAYER", "Enter the host's LAN IP or public IP and port. Example: 192.168.1.20:24567. Internet play requires the host to expose UDP 24567 or use a relay.")
    var box: VBoxContainer = ui.box
    var code_input := LineEdit.new()
    code_input.placeholder_text = "192.168.1.20:24567"
    code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    code_input.clear_button_enabled = true
    box.add_child(code_input)
    var status := Label.new()
    status.text = "Host must be in-game. Both phones need internet permission in the exported APK."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(status)
    var buttons := HBoxContainer.new()
    box.add_child(buttons)
    var cancel := Button.new()
    cancel.text = "CANCEL"
    cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel.pressed.connect(_network_popup_close)
    buttons.add_child(cancel)
    var join_button := Button.new()
    join_button.text = "JOIN"
    join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    join_button.pressed.connect(func():
        var code := code_input.text.strip_edges()
        code = code.trim_prefix("udp://").trim_prefix("enet://")
        var host := ""
        var port := MULTIPLAYER_PORT
        # Allow a room code as host:port, or just a host/IP using the default port.
        # IPv6 literals are intentionally not accepted by this IPv4-oriented room-code UI.
        var parts := code.split(":")
        if parts.size() == 2:
            host = parts[0].strip_edges()
            if not parts[1].strip_edges().is_valid_int():
                status.text = "Port must be a number from 1 to 65535."
                return
            port = int(parts[1].strip_edges())
        elif parts.size() == 1:
            host = code
        else:
            status.text = "Use IPv4:port or hostname:port, e.g. 192.168.1.20:24567."
            return
        if host.is_empty() or host.contains(" ") or port < 1 or port > 65535:
            status.text = "Invalid host or port. Example: 192.168.1.20:24567."
            return
        _network_popup_close()
        _start_network_client(host, port)
    )
    buttons.add_child(join_button)

func _start_network_host(mode: String, address: String) -> void:
    # Release any previous ENet socket before binding UDP 24567 again.
    # This also prevents a stale peer from making repeated Host attempts fail.
    _disconnect_multiplayer()

    var peer := ENetMultiplayerPeer.new()
    var err: Error = peer.create_server(MULTIPLAYER_PORT, MAX_REMOTE_PLAYERS)
    if err != OK:
        peer.close()
        var details := error_string(err)
        push_error("Retro Undead Arena: ENet create_server failed on UDP %d. Error %d (%s)." % [MULTIPLAYER_PORT, err, details])
        _show_notice(
            "Could not create the multiplayer server.\n"
            + "Godot error: %d (%s)\nUDP port: %d\n\n"
            % [err, details, MULTIPLAYER_PORT]
            + "If this is Android, check the exported APK's Internet permission. "
            + "If permission is enabled, this device/build could not create the UDP socket."
        )
        return
    multiplayer.multiplayer_peer = peer
    network_active = true
    network_is_host = true
    network_room_mode = mode
    network_next_enemy_id = 1
    network_enemy_nodes.clear()
    var host_address := address.strip_edges()
    if host_address.is_empty():
        host_address = _default_lan_address()
    if host_address.contains(":"):
        host_address = host_address.get_slice(":", 0)
    network_server_code = host_address + ":" + str(MULTIPLAYER_PORT)
    start_game(mode)
    _show_notice("SERVER HOSTED\nROOM CODE: " + network_server_code + "\n\nShare this code with friends. LAN: same Wi-Fi. Internet: use your public IPv4 and forward UDP 24567 to this device.")

func _start_network_client(host: String, port: int) -> void:
    # Always close a previous peer first; a stale ENet peer can block a retry.
    _disconnect_multiplayer()
    var peer := ENetMultiplayerPeer.new()
    var err: Error = peer.create_client(host, port)
    if err != OK:
        peer.close()
        var details := error_string(err)
        push_error("Retro Undead Arena: ENet create_client failed for %s:%d. Error %d (%s)." % [host, port, err, details])
        _show_notice("Could not start connection to %s:%d.\\nGodot error %d (%s).\\n\\nCheck the address, port, and Android Internet permission." % [host, port, err, details])
        return
    multiplayer.multiplayer_peer = peer
    network_active = true
    network_is_host = false
    network_server_code = host + ":" + str(port)
    _show_notice("CONNECTING TO " + network_server_code + "…\\nWaiting up to 12 seconds for the host.")
    _wait_for_network_connection(host, port, peer)

func _wait_for_network_connection(host: String, port: int, expected_peer: ENetMultiplayerPeer) -> void:
    await get_tree().create_timer(12.0).timeout
    if not network_active or network_is_host or multiplayer.multiplayer_peer != expected_peer:
        return
    if expected_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        _disconnect_multiplayer()
        _show_notice("Connection timed out: %s:%d did not answer.\\n\\nLAN: use the host phone's Wi-Fi IP and the same Wi-Fi.\\nInternet: the host needs UDP 24567 port forwarding or a relay. Mobile carrier NAT may block direct hosting." % [host, port])

func _disconnect_multiplayer() -> void:
    network_active = false
    network_is_host = false
    network_room_mode = "single"
    for remote in network_remote_players.values():
        if is_instance_valid(remote):
            remote.queue_free()
    network_remote_players.clear()
    network_enemy_nodes.clear()
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null

func _on_network_peer_connected(peer_id: int) -> void:
    if not network_is_host:
        return
    # The new peer receives the same mode/map and all currently alive enemies.
    rpc_id(peer_id, "_rpc_client_start_game", network_room_mode, selected_map, network_arena_seed)
    await get_tree().create_timer(0.45).timeout
    if not network_active or not network_is_host or not multiplayer.get_peers().has(peer_id):
        return
    for net_key in network_enemy_nodes.keys():
        var e = network_enemy_nodes.get(net_key)
        if is_instance_valid(e):
            rpc_id(peer_id, "_rpc_spawn_enemy", int(net_key), str(e.enemy_kind), bool(e.is_gunner), bool(e.is_boss), e.global_position)
    _show_message("PLAYER CONNECTED • %d/8" % (multiplayer.get_peers().size() + 1))

func _on_network_peer_disconnected(peer_id: int) -> void:
    if network_remote_players.has(peer_id):
        var remote = network_remote_players[peer_id]
        if is_instance_valid(remote):
            remote.queue_free()
        network_remote_players.erase(peer_id)
    _show_message("PLAYER DISCONNECTED")

func _on_network_connected() -> void:
    _show_notice("CONNECTED! Joining the host's game…")

func _on_network_connection_failed() -> void:
    var attempted_code := network_server_code
    _disconnect_multiplayer()
    _show_notice("Connection failed to " + attempted_code + ".\\n\\nCheck that the host is running, the code is correct, both APKs have Internet permission, and UDP 24567 is reachable. For LAN, both phones must be on the same Wi-Fi.")

func _on_network_server_disconnected() -> void:
    _disconnect_multiplayer()
    _return_to_menu()
    _show_notice("The host disconnected. You returned to the main menu.")

@rpc("authority", "call_remote", "reliable")
func _rpc_client_take_damage(amount: int) -> void:
    if network_active and not network_is_host:
        damage_player(clampi(amount, 1, 20))

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sandbox_spawn(kind: String) -> void:
    if not network_active or not network_is_host or not sandbox_mode:
        return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 1 or not multiplayer.get_peers().has(sender):
        return
    if not ["normal", "runner", "tank", "exploder", "spitter", "charger", "screamer", "boss", "electric_boss", "toxic_tank"].has(kind):
        return
    if kind == "boss":
        _spawn_enemy(true, false, false)
    elif kind == "electric_boss":
        _spawn_enemy(false, true, false)
    elif kind == "toxic_tank":
        _spawn_enemy(true, false, true)
    else:
        sandbox_requested_kind = kind
        var old_wave := wave
        wave = 1
        _spawn_enemy(false)
        wave = old_wave
        sandbox_requested_kind = ""

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sandbox_clear() -> void:
    if not network_active or not network_is_host or not sandbox_mode:
        return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 1 or not multiplayer.get_peers().has(sender):
        return
    _sandbox_clear_enemies()

func _network_tick(delta: float) -> void:
    if not network_active or not game_started or not is_instance_valid(player):
        return
    network_sync_timer -= delta
    if network_sync_timer > 0.0:
        return
    network_sync_timer = 0.065
    if network_is_host:
        rpc("_rpc_receive_player_state", 1, player_username, player.global_position, player.rotation.y, int(player.weapon_index))
    else:
        rpc_id(1, "_rpc_submit_player_state", player_username, player.global_position, player.rotation.y, int(player.weapon_index))

func _make_remote_player(peer_id: int, username: String) -> Node3D:
    var avatar := Node3D.new()
    avatar.name = "RemotePlayer_%d" % peer_id
    var body_mesh := MeshInstance3D.new()
    var body := CapsuleMesh.new()
    body.radius = 0.38
    body.height = 1.35
    body_mesh.mesh = body
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.18 + float(peer_id % 3) * 0.16, 0.48, 0.72 - float(peer_id % 2) * 0.2)
    body_mesh.material_override = body_mat
    body_mesh.position.y = 0.86
    avatar.add_child(body_mesh)
    var head_mesh := MeshInstance3D.new()
    var head := SphereMesh.new()
    head.radius = 0.25
    head.height = 0.5
    head_mesh.mesh = head
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.78, 0.62, 0.46)
    head_mesh.material_override = skin
    head_mesh.position.y = 1.72
    avatar.add_child(head_mesh)
    var gun_mesh := MeshInstance3D.new()
    var gun := BoxMesh.new()
    gun.size = Vector3(0.13, 0.13, 0.72)
    gun_mesh.mesh = gun
    var gun_mat := StandardMaterial3D.new()
    gun_mat.albedo_color = Color(0.12, 0.14, 0.13)
    gun_mesh.material_override = gun_mat
    gun_mesh.position = Vector3(0.34, 1.05, -0.42)
    avatar.add_child(gun_mesh)
    var label := Label3D.new()
    label.name = "NameLabel"
    label.text = username if not username.is_empty() else "PLAYER %d" % peer_id
    label.position.y = 2.15
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.pixel_size = 0.008
    avatar.add_child(label)
    add_child(avatar)
    return avatar

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_submit_player_state(username: String, pos: Vector3, yaw: float, weapon_index: int) -> void:
    if not network_active or not network_is_host:
        return
    var peer_id := multiplayer.get_remote_sender_id()
    if peer_id <= 1 or not multiplayer.get_peers().has(peer_id):
        return
    rpc("_rpc_receive_player_state", peer_id, username, pos, yaw, weapon_index)

@rpc("authority", "call_local", "unreliable")
func _rpc_receive_player_state(peer_id: int, username: String, pos: Vector3, yaw: float, weapon_index: int) -> void:
    if not network_active or peer_id == multiplayer.get_unique_id():
        return
    var avatar: Node3D = network_remote_players.get(peer_id)
    if not is_instance_valid(avatar):
        avatar = _make_remote_player(peer_id, username)
        network_remote_players[peer_id] = avatar
    var name_label := avatar.get_node_or_null("NameLabel") as Label3D
    if name_label != null and not username.is_empty():
        name_label.text = username
    avatar.global_position = avatar.global_position.lerp(pos, 0.72) if avatar.global_position.distance_to(pos) < 8.0 else pos
    avatar.rotation.y = yaw
    var gun_mesh := avatar.get_child(2) as MeshInstance3D
    if is_instance_valid(gun_mesh):
        gun_mesh.rotation.y = 0.0
        gun_mesh.visible = weapon_index >= 0

@rpc("authority", "call_remote", "unreliable")
func _rpc_sync_match_stats(wave_value: int, kills_value: int, is_sandbox: bool) -> void:
    if network_is_host or not network_active:
        return
    wave = wave_value
    kills = kills_value
    sandbox_mode = is_sandbox
    _update_hud()

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_multiplayer_unlock(key: String) -> void:
    if network_is_host or sandbox_mode:
        return
    match key:
        "electric_rifle":
            electric_rifle_unlocked = true
            _save_permanent_unlock("electric_rifle")
            if is_instance_valid(player):
                player.unlock_electric_rifle()
        "toxic_gun":
            toxic_gun_unlocked = true
            _save_permanent_unlock("toxic_gun")
            if is_instance_valid(player):
                player.unlock_toxic_gun()
        "fireball":
            fire_ability_unlocked = true
            _save_permanent_unlock("fireball")
            _show_message("FIREBALL UNLOCKED!")
        "multi_gun_door":
            _save_permanent_unlock("multi_gun_door")
            _open_secret_door()
        "multi_gun":
            multi_gun_unlocked = true
            _save_permanent_unlock("multi_gun")
            if is_instance_valid(player):
                player.unlock_multi_gun()
            _hide_multi_gun_pickup()

@rpc("authority", "call_remote", "reliable")
func _rpc_client_start_game(mode: String, map_index: int, arena_seed: int) -> void:
    if network_is_host:
        return
    selected_map = clampi(map_index, 0, 2)
    network_arena_seed = arena_seed
    start_game(mode, true)
    _show_message("CONNECTED • MULTIPLAYER %s" % ("SANDBOX" if mode == "sandbox" else "NORMAL"))

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_enemy(net_id: int, kind: String, gunner: bool, boss: bool, pos: Vector3) -> void:
    if network_is_host or not network_active or not game_started or not is_instance_valid(arena):
        return
    if network_enemy_nodes.has(net_id) and is_instance_valid(network_enemy_nodes[net_id]):
        return
    var e := CharacterBody3D.new()
    e.set_script(EnemyScript)
    e.position = pos
    arena.add_child(e)
    e.setup(self, gunner, boss, kind)
    e.set_meta("network_enemy_id", net_id)
    e.set("network_proxy", true)
    e.set_physics_process(true)
    network_enemy_nodes[net_id] = e
    enemies.append(e)

@rpc("authority", "call_remote", "unreliable")
func _rpc_sync_enemy(net_id: int, pos: Vector3, yaw: float, hp_value: int, dying: bool) -> void:
    if network_is_host or not network_enemy_nodes.has(net_id):
        return
    var e = network_enemy_nodes[net_id]
    if not is_instance_valid(e):
        network_enemy_nodes.erase(net_id)
        return
    e.global_position = e.global_position.lerp(pos, 0.72) if e.global_position.distance_to(pos) < 8.0 else pos
    e.rotation.y = yaw
    e.hp = hp_value
    if dying and not e.is_dying:
        e.is_dying = true
        e.set_physics_process(false)

@rpc("authority", "call_remote", "reliable")
func _rpc_remove_enemy(net_id: int) -> void:
    if network_is_host:
        return
    if network_enemy_nodes.has(net_id):
        var e = network_enemy_nodes[net_id]
        network_enemy_nodes.erase(net_id)
        enemies.erase(e)
        if is_instance_valid(e):
            e.queue_free()

func request_network_enemy_hit(target: Node, amount: int, weapon_index: int, effect_index: int = -1) -> void:
    if not network_active or network_is_host or not is_instance_valid(target) or not target.has_meta("network_enemy_id"):
        return
    rpc_id(1, "_rpc_request_enemy_hit", int(target.get_meta("network_enemy_id")), amount, weapon_index, effect_index)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_enemy_hit(net_id: int, amount: int, weapon_index: int, effect_index: int = -1) -> void:
    if not network_active or not network_is_host:
        return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 1 or not multiplayer.get_peers().has(sender):
        return
    if not network_enemy_nodes.has(net_id):
        return
    var enemy = network_enemy_nodes[net_id]
    if not is_instance_valid(enemy) or enemy.is_dying:
        return
    enemy.set_meta("last_damage_weapon_index", weapon_index)
    enemy.set_meta("last_damage_peer_id", sender)
    enemy.take_hit(clampi(amount, 1, 25))
    var effect := effect_index if effect_index >= 0 else weapon_index
    if effect == 8 or effect == 9 and effect_index == 0:
        enemy.apply_poison()
    elif effect == 6 or effect == 9 and effect_index == 1:
        enemy.apply_shock()
    elif effect == 9 and effect_index == 3:
        enemy.apply_burn()

func _show_notice(msg: String) -> void:
    var dialog := AcceptDialog.new()
    dialog.dialog_text = msg
    add_child(dialog)
    dialog.confirmed.connect(func(): dialog.queue_free())
    dialog.popup_centered()

func start_game(mode: String, keep_selected_map: bool = false) -> void:
    game_mode = mode
    # Pick a fresh arena at the start of a run; clients use the host's map/seed.
    if not keep_selected_map:
        selected_map = randi_range(0, 2)
    if network_active and network_is_host:
        network_arena_seed = randi()
    game_started = true
    health = 12
    kills = 0
    wave = 1
    boss_spawned_wave = 0
    boss_active = null
    fire_ability_unlocked = _is_permanent_unlock("fireball")
    fire_ability_cooldown = 0.0
    electric_rifle_unlocked = _is_permanent_unlock("electric_rifle")
    special_event_active = ""
    special_event_timer = 0.0
    last_special_event_wave = -999
    rare_event_active = false
    kills_in_wave = 0
    sandbox_mode = mode == "sandbox"
    if sandbox_mode:
        _build_sandbox_arena()
    elif network_active:
        seed(network_arena_seed)
        _build_arena()
    elif arena_map_index != selected_map:
        _build_arena()
    get_tree().paused = false
    is_paused = false
    if is_instance_valid(pause_layer):
        pause_layer.visible = false
    spawn_timer = 999999.0 if sandbox_mode else 1.2
    medkit_timer = 999999.0 if sandbox_mode else randf_range(16.0, 23.0)
    for kit in medkits:
        if is_instance_valid(kit):
            kit.queue_free()
    medkits.clear()
    enemies.clear()
    menu_layer.visible = false
    if is_instance_valid(player):
        player.queue_free()
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PlayerScript)
    player.position = Vector3(0, 1.1, 0)
    if network_active and not network_is_host:
        var spawn_lane := int(multiplayer.get_unique_id()) % 7
        player.position = Vector3(float(spawn_lane - 3) * 2.0, 1.1, 3.0 + float(spawn_lane % 2) * 2.0)
    add_child(player)
    player.setup(self)
    if gunner_weapon_unlocked:
        player.unlock_gunner_weapon(false)
    if electric_rifle_unlocked:
        player.unlock_electric_rifle()
    if toxic_gun_unlocked:
        player.unlock_toxic_gun()
    _build_hud()
    if sandbox_mode:
        _build_sandbox_tools()
        _show_message("SANDBOX MODE • NOTHING SPAWNS UNTIL YOU SPAWN IT")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE
    _show_message("SURVIVE THE WAVES")

func _build_sandbox_arena() -> void:
    if is_instance_valid(arena):
        arena.queue_free()
    arena = Node3D.new()
    arena.name = "SandboxBaseplate"
    arena_map_index = -99
    add_child(arena)
    # Huge, flat baseplate with a simple pixel-art grid.
    _add_box(arena, Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.12, 0.16, 0.18))
    for i in range(-190, 200, 10):
        _add_box(arena, Vector3(float(i), 0.012, 0), Vector3(0.045, 0.025, 400), Color(0.20, 0.25, 0.27))
        _add_box(arena, Vector3(0, 0.013, float(i)), Vector3(400, 0.025, 0.045), Color(0.20, 0.25, 0.27))
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.035, 0.05, 0.11)
    sky_mat.sky_horizon_color = Color(0.18, 0.22, 0.25)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.75, 0.8)
    env.ambient_light_energy = 0.8
    env_node.environment = env
    arena.add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    arena.add_child(sun)

func _build_sandbox_tools() -> void:
    if is_instance_valid(sandbox_panel):
        sandbox_panel.queue_free()
    if is_instance_valid(sandbox_toggle_button):
        sandbox_toggle_button.queue_free()
    sandbox_panel = PanelContainer.new()
    sandbox_panel.name = "SandboxSpawnMenu"
    sandbox_panel.position = Vector2(14, 140)
    sandbox_panel.size = Vector2(220, 430)
    sandbox_panel.add_theme_stylebox_override("panel", _sandbox_panel_style())
    hud_layer.add_child(sandbox_panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    sandbox_panel.add_child(box)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 4)
    box.add_child(header)
    var title := Label.new()
    title.text = "SANDBOX SPAWNER"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 13)
    title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.45))
    header.add_child(title)
    var close_btn := Button.new()
    close_btn.text = "X"
    close_btn.custom_minimum_size = Vector2(28, 24)
    close_btn.add_theme_font_size_override("font_size", 12)
    close_btn.tooltip_text = "Close sandbox menu"
    close_btn.pressed.connect(_toggle_sandbox_menu)
    header.add_child(close_btn)

    sandbox_fly_label = Label.new()
    sandbox_fly_label.text = "SANDBOX • F TO FLY"
    sandbox_fly_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sandbox_fly_label.add_theme_font_size_override("font_size", 11)
    box.add_child(sandbox_fly_label)
    _sandbox_spawn_button(box, "Spawn Zombie", "normal")
    var up_btn := Button.new()
    up_btn.text = "HOLD TO FLY UP"
    up_btn.custom_minimum_size.y = 24
    up_btn.add_theme_font_size_override("font_size", 11)
    up_btn.button_down.connect(func(): sandbox_vertical_input = 1.0)
    up_btn.button_up.connect(func(): sandbox_vertical_input = 0.0)
    box.add_child(up_btn)
    var down_btn := Button.new()
    down_btn.text = "HOLD TO FLY DOWN"
    down_btn.custom_minimum_size.y = 24
    down_btn.add_theme_font_size_override("font_size", 11)
    down_btn.button_down.connect(func(): sandbox_vertical_input = -1.0)
    down_btn.button_up.connect(func(): sandbox_vertical_input = 0.0)
    box.add_child(down_btn)
    _sandbox_spawn_button(box, "Spawn Runner", "runner")
    _sandbox_spawn_button(box, "Spawn Tank", "tank")
    _sandbox_spawn_button(box, "Spawn Exploder", "exploder")
    _sandbox_spawn_button(box, "Spawn Spitter", "spitter")
    _sandbox_spawn_button(box, "Spawn Charger", "charger")
    _sandbox_spawn_button(box, "Spawn Screamer", "screamer")
    _sandbox_spawn_button(box, "Spawn Abomination Boss", "boss")
    _sandbox_spawn_button(box, "Spawn Electric Boss", "electric_boss")
    _sandbox_spawn_button(box, "Spawn Toxic Tank", "toxic_tank")
    var clear_btn := Button.new()
    clear_btn.text = "CLEAR ALL SPAWNED"
    clear_btn.custom_minimum_size.y = 24
    clear_btn.add_theme_font_size_override("font_size", 11)
    clear_btn.pressed.connect(_sandbox_clear_enemies)
    box.add_child(clear_btn)
    var back_btn := Button.new()
    back_btn.text = "RETURN TO MAIN MENU"
    back_btn.custom_minimum_size.y = 24
    back_btn.add_theme_font_size_override("font_size", 11)
    back_btn.pressed.connect(_return_to_menu)
    box.add_child(back_btn)

    sandbox_toggle_button = Button.new()
    sandbox_toggle_button.name = "OpenSandboxMenu"
    sandbox_toggle_button.text = "TOOLS"
    sandbox_toggle_button.position = Vector2(14, 140)
    sandbox_toggle_button.size = Vector2(64, 30)
    sandbox_toggle_button.add_theme_font_size_override("font_size", 11)
    sandbox_toggle_button.tooltip_text = "Open sandbox menu"
    sandbox_toggle_button.pressed.connect(_toggle_sandbox_menu)
    hud_layer.add_child(sandbox_toggle_button)
    _update_sandbox_menu_visibility()

func _toggle_sandbox_menu() -> void:
    if not is_instance_valid(sandbox_panel):
        return
    sandbox_panel.visible = not sandbox_panel.visible
    _update_sandbox_menu_visibility()

func _update_sandbox_menu_visibility() -> void:
    if is_instance_valid(sandbox_toggle_button):
        sandbox_toggle_button.visible = not is_instance_valid(sandbox_panel) or not sandbox_panel.visible

func _sandbox_panel_style() -> StyleBoxFlat:
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.015, 0.025, 0.035, 0.92)
    st.border_color = Color(0.22, 0.8, 0.38, 0.95)
    st.set_border_width_all(2)
    st.set_corner_radius_all(6)
    st.content_margin_left = 6
    st.content_margin_right = 6
    st.content_margin_top = 6
    st.content_margin_bottom = 6
    return st

func _sandbox_spawn_button(parent: VBoxContainer, caption: String, kind: String) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size.y = 24
    b.add_theme_font_size_override("font_size", 11)
    b.pressed.connect(func(): _sandbox_spawn_kind(kind))
    parent.add_child(b)

func _sandbox_spawn_kind(kind: String) -> void:
    if not sandbox_mode or not game_started:
        return
    if network_active and not network_is_host:
        rpc_id(1, "_rpc_request_sandbox_spawn", kind)
        return
    if kind == "boss":
        _spawn_enemy(true, false, false)
    elif kind == "electric_boss":
        _spawn_enemy(false, true, false)
    elif kind == "toxic_tank":
        _spawn_enemy(true, false, true)
    else:
        sandbox_requested_kind = kind
        var old_wave := wave
        wave = 1
        _spawn_enemy(false)
        wave = old_wave
        sandbox_requested_kind = ""

func _sandbox_clear_enemies() -> void:
    if network_active and not network_is_host:
        rpc_id(1, "_rpc_request_sandbox_clear")
        return
    if network_active and network_is_host:
        for net_id in network_enemy_nodes.keys():
            rpc("_rpc_remove_enemy", int(net_id))
        network_enemy_nodes.clear()
    for e in enemies:
        if is_instance_valid(e):
            e.queue_free()
    enemies.clear()
    boss_active = null
    if is_instance_valid(boss_health_label):
        boss_health_label.visible = false

func _build_hud() -> void:
    if is_instance_valid(hud_layer):
        hud_layer.queue_free()
    hud_layer = CanvasLayer.new()
    hud_layer.layer = 5
    add_child(hud_layer)
    network_room_label = null
    if network_active:
        network_room_label = Label.new()
        network_room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
        network_room_label.position = Vector2(-420, 14)
        network_room_label.size = Vector2(405, 42)
        network_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        network_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        network_room_label.add_theme_font_size_override("font_size", 14)
        network_room_label.add_theme_color_override("font_color", Color(0.60, 1.0, 0.70))
        network_room_label.text = ("ROOM CODE: " + network_server_code + " • 1/8") if network_is_host else ("CONNECTED: " + network_server_code)
        hud_layer.add_child(network_room_label)
    var top := Panel.new()
    top.position = Vector2(14, 14)
    top.size = Vector2(350, 112)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.035, 0.045, 0.88)
    style.border_color = Color(0.25, 0.72, 0.48, 0.9)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    top.add_theme_stylebox_override("panel", style)
    hud_layer.add_child(top)
    health_label = Label.new()
    health_label.position = Vector2(28, 22)
    health_label.size = Vector2(320, 32)
    health_label.add_theme_font_size_override("font_size", 18)
    health_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28))
    hud_layer.add_child(health_label)
    stats_label = Label.new()
    stats_label.position = Vector2(28, 54)
    stats_label.size = Vector2(320, 24)
    stats_label.add_theme_font_size_override("font_size", 16)
    stats_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.70))
    hud_layer.add_child(stats_label)
    weapon_label = Label.new()
    weapon_label.position = Vector2(28, 80)
    weapon_label.size = Vector2(320, 26)
    weapon_label.add_theme_font_size_override("font_size", 16)
    weapon_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
    hud_layer.add_child(weapon_label)
    boss_health_label = Label.new()
    boss_health_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    boss_health_label.position = Vector2(-230, 72)
    boss_health_label.size = Vector2(460, 32)
    boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_health_label.add_theme_font_size_override("font_size", 20)
    boss_health_label.add_theme_color_override("font_color", Color(1.0, 0.16, 0.10))
    boss_health_label.visible = false
    hud_layer.add_child(boss_health_label)
    fire_ability_button = Button.new()
    fire_ability_button.text = "FIREBALL LOCKED"
    fire_ability_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    fire_ability_button.position = Vector2(-238, -402)
    fire_ability_button.size = Vector2(210, 58)
    fire_ability_button.add_theme_font_size_override("font_size", 15)
    fire_ability_button.pressed.connect(_use_fire_ability)
    fire_ability_button.visible = OS.has_feature("mobile")
    hud_layer.add_child(fire_ability_button)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-8, -19)
    cross.add_theme_font_size_override("font_size", 30)
    cross.add_theme_color_override("font_color", Color(1, 0.9, 0.58))
    hud_layer.add_child(cross)
    message_label = Label.new()
    message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    message_label.position = Vector2(-260, 24)
    message_label.size = Vector2(520, 42)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 22)
    message_label.add_theme_color_override("font_color", Color(1, 0.64, 0.28))
    hud_layer.add_child(message_label)
    switch_weapon_button = Button.new()
    switch_weapon_button.text = "SWITCH GUN  [Q]"
    switch_weapon_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    switch_weapon_button.position = Vector2(-238, -270)
    switch_weapon_button.size = Vector2(210, 58)
    switch_weapon_button.add_theme_font_size_override("font_size", 18)
    var switch_style := StyleBoxFlat.new()
    switch_style.bg_color = Color(0.08, 0.22, 0.17, 0.94)
    switch_style.border_color = Color(0.35, 1.0, 0.55, 0.95)
    switch_style.set_border_width_all(2)
    switch_style.set_corner_radius_all(14)
    switch_weapon_button.add_theme_stylebox_override("normal", switch_style)
    switch_weapon_button.add_theme_stylebox_override("hover", switch_style)
    switch_weapon_button.pressed.connect(_switch_weapon)
    hud_layer.add_child(switch_weapon_button)
    var pause_button := Button.new()
    pause_button.text = "Ⅱ  PAUSE"
    pause_button.position = Vector2(-166, 14)
    pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    pause_button.size = Vector2(150, 48)
    pause_button.add_theme_font_size_override("font_size", 17)
    pause_button.pressed.connect(pause_game)
    hud_layer.add_child(pause_button)
    hit_marker = Label.new()
    hit_marker.text = "×"
    hit_marker.set_anchors_preset(Control.PRESET_CENTER)
    hit_marker.position = Vector2(-14, -28)
    hit_marker.size = Vector2(28, 28)
    hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hit_marker.add_theme_font_size_override("font_size", 34)
    hit_marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    hit_marker.visible = false
    hud_layer.add_child(hit_marker)
    dash_button = Button.new()
    dash_button.text = "DASH"
    dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    dash_button.position = Vector2(-238, -336)
    dash_button.size = Vector2(210, 58)
    dash_button.add_theme_font_size_override("font_size", 18)
    dash_button.pressed.connect(try_dash)
    dash_button.visible = OS.has_feature("mobile")
    hud_layer.add_child(dash_button)
    sandbox_fly_button = Button.new()
    sandbox_fly_button.name = "SandboxFlyButton"
    sandbox_fly_button.text = "FLY: OFF"
    sandbox_fly_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    sandbox_fly_button.position = Vector2(-238, -468)
    sandbox_fly_button.size = Vector2(210, 48)
    sandbox_fly_button.add_theme_font_size_override("font_size", 16)
    sandbox_fly_button.pressed.connect(_toggle_sandbox_flight)
    sandbox_fly_button.visible = OS.has_feature("mobile") and sandbox_mode
    hud_layer.add_child(sandbox_fly_button)
    _build_mobile_controls()
    if is_instance_valid(player):
        set_weapon_name(player.weapon_names[player.weapon_index])
    _update_hud()

func _toggle_sandbox_flight() -> void:
    if not sandbox_mode or not is_instance_valid(player):
        return
    player.set("sandbox_flying", not bool(player.get("sandbox_flying")))
    if is_instance_valid(sandbox_fly_button):
        sandbox_fly_button.text = "FLY: ON" if bool(player.get("sandbox_flying")) else "FLY: OFF"

func _build_mobile_controls() -> void:
    mobile_controls = Control.new()
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(mobile_controls)
    # A dedicated Control script draws the mobile joystick and fire button.
    mobile_controls.set_script(load("res://scripts/mobile_controls.gd"))
    mobile_controls.set("game", self)
    mobile_controls.queue_redraw()

func _input(event: InputEvent) -> void:
    if sandbox_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and is_instance_valid(player):
        player.set("sandbox_flying", not bool(player.get("sandbox_flying")))
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if game_started and not is_paused:
            pause_game()
        elif is_paused:
            resume_game()
        return
    if not game_started or is_paused:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
        _switch_weapon()
    if event is InputEventKey and event.pressed and event.keycode in [KEY_SHIFT, KEY_SPACE]:
        try_dash()
    if event is InputEventKey and event.pressed and event.keycode == KEY_F:
        _use_fire_ability()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
        _switch_weapon()
    if event is InputEventScreenTouch:
        var size := get_viewport().get_visible_rect().size
        if event.pressed:
            if event.position.x < size.x * 0.42 and event.position.y > size.y * 0.48:
                joystick_touch = event.index
                joystick_center = Vector2(115, size.y - 125)
                _update_joystick(event.position)
            elif event.position.x > size.x - 170 and event.position.y > size.y - 190:
                fire_button_down = true
                fire_touch = event.index
                player.fire()
            elif event.position.x > size.x - 250 and event.position.y > size.y - 300 and event.position.y < size.y - 195:
                pass
            else:
                look_touch = event.index
                last_look = event.position
        else:
            if event.index == joystick_touch:
                joystick_touch = -1
                joystick_vector = Vector2.ZERO
            if event.index == look_touch:
                look_touch = -1
            if event.index == fire_touch:
                fire_button_down = false
                fire_touch = -1
            if is_instance_valid(mobile_controls):
                mobile_controls.set("joystick_vector", joystick_vector)
                mobile_controls.queue_redraw()
    elif event is InputEventScreenDrag:
        if event.index == joystick_touch:
            _update_joystick(event.position)
        elif event.index == look_touch:
            player.look_by(event.relative * (mouse_sensitivity / 0.003))
            last_look = event.position
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.look_by(event.relative * (mouse_sensitivity / 0.003))
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var view_size := get_viewport().get_visible_rect().size
        var clicked_switch: bool = event.position.x > view_size.x - 250 and event.position.y > view_size.y - 300 and event.position.y < view_size.y - 195
        if not clicked_switch:
            player.fire()

func _update_joystick(pos: Vector2) -> void:
    var delta := pos - joystick_center
    joystick_vector = delta.limit_length(65) / 65.0
    if is_instance_valid(mobile_controls):
        mobile_controls.set("joystick_vector", joystick_vector)
        mobile_controls.queue_redraw()

func get_mobile_move() -> Vector2:
    return joystick_vector

func _switch_weapon() -> void:
    if game_started and is_instance_valid(player):
        player.switch_weapon()

func set_weapon_name(name: String) -> void:
    if is_instance_valid(weapon_label):
        weapon_label.text = "WEAPON  " + name + "   •   Q / SWITCH"

func show_damage_number(target: Node3D, amount: int, boss: bool = false) -> void:
    var number := Label3D.new()
    number.text = "-" + str(amount)
    number.font_size = 52 if boss else 34
    number.pixel_size = 0.012
    number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    number.no_depth_test = true
    number.modulate = Color(1.0, 0.22, 0.12) if boss else Color(1.0, 0.9, 0.32)
    add_child(number)
    number.global_position = target.global_position + Vector3(randf_range(-0.2, 0.2), 2.0 if boss else 1.65, 0)
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(number, "global_position", number.global_position + Vector3(0, 0.9, 0), 0.62)
    tween.tween_property(number, "modulate:a", 0.0, 0.62)
    tween.set_parallel(false)
    tween.tween_callback(number.queue_free)

func play_weapon_sfx(pitch: float, volume_db: float) -> void:
    var stream: AudioStream = load("res://audio/gunshot.wav") as AudioStream
    if stream == null:
        return
    var audio := AudioStreamPlayer.new()
    audio.stream = stream
    audio.volume_db = volume_db
    audio.pitch_scale = pitch
    add_child(audio)
    audio.finished.connect(audio.queue_free)
    audio.play()

func _update_hud() -> void:
    if not is_instance_valid(health_label):
        return
    var blocks := ""
    for i in range(12):
        blocks += "■ " if i < health else "□ "
    health_label.text = "HEALTH  " + blocks
    stats_label.text = "KILLS %03d     WAVE %02d" % [kills, wave]
    if is_instance_valid(boss_active) and is_instance_valid(boss_health_label):
        boss_health_label.visible = true
        if boss_active.get("enemy_kind") == "electric_boss":
            boss_health_label.text = "ELECTRIC BRUTE  %03d / 100 HP" % maxi(0, int(boss_active.get("hp")))
        elif boss_active.get("enemy_kind") == "toxic_tank":
            boss_health_label.text = "TOXIC TANK  %04d / 1150 HP" % maxi(0, int(boss_active.get("hp")))
        else:
            boss_health_label.text = "THE ABOMINATION  %04d / 1000 HP" % maxi(0, int(boss_active.get("hp")))
    elif is_instance_valid(boss_health_label):
        boss_health_label.visible = false
    if is_instance_valid(fire_ability_button):
        if not fire_ability_unlocked:
            fire_ability_button.text = "FIREBALL LOCKED"
            fire_ability_button.disabled = true
        elif fire_ability_cooldown > 0.0:
            fire_ability_button.text = "FIREBALL %.1fs" % fire_ability_cooldown
            fire_ability_button.disabled = true
        else:
            fire_ability_button.text = "FIREBALL READY [F]"
            fire_ability_button.disabled = false

func _show_message(s: String) -> void:
    if is_instance_valid(message_label):
        message_label.text = s

func damage_player(amount: int = 1) -> void:
    if not game_started:
        return
    if network_active and network_is_host and network_enemy_target_peer > 1:
        var target_peer := network_enemy_target_peer
        network_enemy_target_peer = 1
        if multiplayer.get_peers().has(target_peer):
            rpc_id(target_peer, "_rpc_client_take_damage", amount)
        return
    health = max(0, health - amount)
    _update_hud()
    if health <= 0:
        _save_high_score()
        _delete_saved_game()
        game_started = false
        get_tree().paused = false
        is_paused = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        _show_message("YOU DIED • KILLS %d" % kills)
        await get_tree().create_timer(1.4).timeout
        _return_to_menu()

func enemy_killed(enemy: Node) -> void:
    if network_active and network_is_host and is_instance_valid(enemy) and enemy.has_meta("network_enemy_id"):
        var dead_id: int = int(enemy.get_meta("network_enemy_id"))
        network_enemy_nodes.erase(dead_id)
        rpc("_rpc_remove_enemy", dead_id)
    if not sandbox_mode and is_instance_valid(enemy) and bool(enemy.get("is_gunner")) and not gunner_weapon_unlocked and randf() < 0.05:
        gunner_weapon_unlocked = true
        _save_gunner_weapon_unlock()
        if is_instance_valid(player) and player.has_method("unlock_gunner_weapon"):
            player.unlock_gunner_weapon(true)
        else:
            _show_message("RARE UNLOCK: GUNNER'S GUN!")
    kills += 1
    _check_achievements()
    kills_in_wave += 1
    enemies.erase(enemy)
    if is_instance_valid(enemy):
        enemy.queue_free()
    var wave_target: int = 8 + wave * 2
    if kills_in_wave >= wave_target:
        kills_in_wave = 0
        wave += 1
        _check_achievements()
        spawn_timer = 0.6
        _show_message("WAVE %d INCOMING" % wave)
    _update_hud()

func _process(delta: float) -> void:
    if not game_started or is_paused:
        return
    _network_tick(delta)
    if is_instance_valid(network_room_label):
        network_room_label.text = ("ROOM CODE: " + network_server_code + " • %d/8" % (multiplayer.get_peers().size() + 1)) if network_is_host else ("CONNECTED: " + network_server_code)
    if network_active and not network_is_host:
        # Clients predict their own movement and firing, while the host owns
        # enemy AI, wave progression, boss state, and pickups.
        if fire_button_down and is_instance_valid(player):
            player.fire()
        dash_cooldown = maxf(0.0, dash_cooldown - delta)
        if dash_time > 0.0 and is_instance_valid(player):
            dash_time = maxf(0.0, dash_time - delta)
            player.velocity.x = dash_direction.x * 17.0
            player.velocity.z = dash_direction.z * 17.0
        if sandbox_mode and is_instance_valid(sandbox_fly_label):
            sandbox_fly_label.text = "SANDBOX • FLY: ON (SPACE UP / CTRL DOWN)" if is_instance_valid(player) and bool(player.get("sandbox_flying")) else "SANDBOX • FLY: OFF (F TO TOGGLE)"
        return
    # Keep hold-to-fire active in every game mode, including Sandbox.
    if fire_button_down and is_instance_valid(player):
        player.fire()
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    if dash_time > 0.0 and is_instance_valid(player):
        dash_time = maxf(0.0, dash_time - delta)
        player.velocity.x = dash_direction.x * 17.0
        player.velocity.z = dash_direction.z * 17.0
    if network_active and network_is_host:
        network_enemy_sync_timer -= delta
        if network_enemy_sync_timer <= 0.0:
            network_enemy_sync_timer = 0.10
            for net_key in network_enemy_nodes.keys():
                var synced_enemy = network_enemy_nodes.get(net_key)
                if is_instance_valid(synced_enemy):
                    rpc("_rpc_sync_enemy", int(net_key), synced_enemy.global_position, synced_enemy.rotation.y, int(synced_enemy.hp), bool(synced_enemy.is_dying))
        network_stats_sync_timer -= delta
        if network_stats_sync_timer <= 0.0:
            network_stats_sync_timer = 0.35
            rpc("_rpc_sync_match_stats", wave, kills, sandbox_mode)
    if sandbox_mode:
        if is_instance_valid(sandbox_fly_label):
            sandbox_fly_label.text = "SANDBOX • FLY: ON (SPACE UP / CTRL DOWN)" if is_instance_valid(player) and bool(player.get("sandbox_flying")) else "SANDBOX • FLY: OFF (F TO TOGGLE)"
        if is_instance_valid(sandbox_fly_button) and is_instance_valid(player):
            sandbox_fly_button.visible = OS.has_feature("mobile")
            sandbox_fly_button.text = "FLY: ON" if bool(player.get("sandbox_flying")) else "FLY: OFF"
        return
    fire_ability_cooldown = maxf(0.0, fire_ability_cooldown - delta)
    if screen_shake_time > 0.0 and is_instance_valid(player) and is_instance_valid(player.camera):
        screen_shake_time = maxf(0.0, screen_shake_time - delta)
        var shake_offset := Vector3(randf_range(-screen_shake_strength, screen_shake_strength), randf_range(-screen_shake_strength, screen_shake_strength), 0.0)
        player.camera.position = Vector3(0, 0.55, 0) + shake_offset
    # Medkits are intentionally uncommon: a new one appears roughly every 22–32 seconds,
    # with at most two available around the arena at once.
    for kit in medkits:
        if is_instance_valid(kit):
            kit.rotation.y += delta * 1.25
            var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + kit.position.x)
            kit.position.y = float(kit.get_meta("base_y", 0.65)) + sin(Time.get_ticks_msec() * 0.003 + kit.position.x) * 0.12
            var glow_light := kit.get_node_or_null("GlowLight") as OmniLight3D
            if glow_light != null:
                glow_light.light_energy = 0.45 + pulse * 1.0
            var aura := kit.get_node_or_null("GlowAura") as MeshInstance3D
            if aura != null:
                aura.scale = Vector3.ONE * (1.05 + pulse * 0.22)
    medkit_timer -= delta
    if medkit_timer <= 0.0:
        medkit_timer = randf_range(22.0, 32.0)
        if medkits.size() < 2:
            _spawn_medkit()
    if special_event_timer > 0.0:
        special_event_timer -= delta
        if special_event_timer <= 0.0:
            special_event_active = ""
            rare_event_active = false
            _show_message("SPECIAL EVENT COMPLETE")
    spawn_timer -= delta
    if spawn_timer <= 0:
        spawn_timer = max(1.8, 3.8 - float(wave) * 0.06)
        if wave > 0 and wave % 15 == 0 and boss_spawned_wave != wave:
            # Toxic Tank is the scheduled boss every 15 waves (15, 30, 45...).
            _spawn_enemy(true, false, true)
        elif wave > 0 and wave % 10 == 0 and boss_spawned_wave != wave:
            _spawn_enemy(true)
        elif wave > 0 and wave % 5 == 0 and wave % 10 != 0 and boss_spawned_wave != wave:
            _spawn_enemy(false, true)
        elif enemies.size() < mini(14 + wave, 26) and (wave % 10 != 0 or boss_spawned_wave == wave):
            _spawn_enemy(false)
        # Rare events are intentionally uncommon and never begin on boss waves.
        if wave >= 4 and wave % 5 != 0 and wave % 10 != 0 and special_event_active == "" and wave - last_special_event_wave >= 8 and randf() < 0.22:
            _start_special_event()

func _spawn_enemy(force_boss: bool = false, electric_boss: bool = false, toxic_tank: bool = false) -> void:
    var e := CharacterBody3D.new()
    e.set_script(EnemyScript)
    var boss := force_boss or electric_boss
    if boss:
        boss_spawned_wave = wave
    var a := randf() * TAU
    var r := randf_range(17, 25)
    e.position = Vector3(cos(a) * r, 0.9, sin(a) * r)
    arena.add_child(e)
    var kind: String = "normal"
    if not boss:
        var roll: float = randf()
        # Mini-bosses are random, rare, and only spawn on non-major-boss waves.
        if wave >= 3 and wave % 5 != 0 and wave % 10 != 0 and roll < 0.035:
            kind = "charger"
        elif wave >= 3 and wave % 5 != 0 and wave % 10 != 0 and roll < 0.065:
            kind = "screamer"
        elif roll < 0.17:
            kind = "runner"
        elif roll < 0.27:
            kind = "tank"
        elif roll < 0.37:
            kind = "exploder"
        elif roll < 0.45:
            kind = "spitter"
    if sandbox_mode and not sandbox_requested_kind.is_empty():
        kind = sandbox_requested_kind
    if electric_boss:
        kind = "electric_boss"
    elif toxic_tank:
        kind = "toxic_tank"
    var gunner := not boss and kind == "normal" and randf() < 0.10
    e.setup(self, gunner, boss, kind)
    if network_active and network_is_host:
        var net_id := network_next_enemy_id
        network_next_enemy_id += 1
        e.set_meta("network_enemy_id", net_id)
        network_enemy_nodes[net_id] = e
        rpc("_rpc_spawn_enemy", net_id, kind, gunner, boss, e.global_position)
    if not boss and special_event_active == "ARMORED HORDE":
        e.hp = ceili(float(e.hp) * 1.5)
    enemies.append(e)
    if not boss and kind == "charger":
        _show_message("MINI-BOSS: THE CHARGER!")
    elif not boss and kind == "screamer":
        _show_message("MINI-BOSS: THE SCREAMER!")
    if boss:
        boss_active = e
        if electric_boss:
            _show_message("WARNING: THE ELECTRIC BRUTE APPROACHES!")
            if is_instance_valid(boss_health_label):
                boss_health_label.visible = true
                boss_health_label.text = "ELECTRIC BRUTE  100 / 100 HP"
            trigger_screen_shake(0.07, 0.4)
        elif toxic_tank:
            _show_message("WARNING: THE TOXIC TANK APPROACHES!")
            if is_instance_valid(boss_health_label):
                boss_health_label.visible = true
                boss_health_label.text = "TOXIC TANK  1150 / 1150 HP"
            trigger_screen_shake(0.12, 0.7)
        else:
            _show_message("WARNING: THE ABOMINATION APPROACHES")
            if is_instance_valid(boss_health_label):
                boss_health_label.visible = true
                boss_health_label.text = "THE ABOMINATION  1000 / 1000 HP"
            trigger_screen_shake(0.10, 0.65)


func _screamer_summon(screamer: Node3D) -> void:
    if not game_started or not is_instance_valid(screamer) or enemies.size() >= mini(14 + wave, 26):
        return
    _show_message("SCREAMER! MORE UNDEAD INCOMING!")
    var summon_count: int = mini(2, mini(14 + wave, 26) - enemies.size())
    for i in range(summon_count):
        var minion := CharacterBody3D.new()
        minion.set_script(EnemyScript)
        var angle: float = randf() * TAU
        minion.position = screamer.global_position + Vector3(cos(angle) * 2.2, 0.0, sin(angle) * 2.2)
        arena.add_child(minion)
        minion.setup(self, false, false, "normal")
        if network_active and network_is_host:
            var net_id := network_next_enemy_id
            network_next_enemy_id += 1
            minion.set_meta("network_enemy_id", net_id)
            network_enemy_nodes[net_id] = minion
            rpc("_rpc_spawn_enemy", net_id, "normal", false, false, minion.global_position)
        enemies.append(minion)

func _load_gunner_weapon_unlock() -> void:
    var data := ConfigFile.new()
    if data.load("user://retro_undead_unlocks.cfg") == OK:
        gunner_weapon_unlocked = bool(data.get_value("unlocks", "gunner_weapon", false))
        electric_rifle_unlocked = bool(data.get_value("unlocks", "electric_rifle", false))
        toxic_gun_unlocked = bool(data.get_value("unlocks", "toxic_gun", false))
        fire_ability_unlocked = bool(data.get_value("unlocks", "fireball", false))

func _is_permanent_unlock(key: String) -> bool:
    var data := ConfigFile.new()
    if data.load("user://retro_undead_unlocks.cfg") != OK:
        return false
    return bool(data.get_value("unlocks", key, false))

func _save_permanent_unlock(key: String) -> void:
    var data := ConfigFile.new()
    data.load("user://retro_undead_unlocks.cfg")
    data.set_value("unlocks", key, true)
    var result := data.save("user://retro_undead_unlocks.cfg")
    if result != OK:
        _show_notice("Could not save permanent unlock. Check device storage.")

func _save_gunner_weapon_unlock() -> void:
    gunner_weapon_unlocked = true
    _save_permanent_unlock("gunner_weapon")

func _use_fire_ability() -> void:
    if not game_started or not fire_ability_unlocked or fire_ability_cooldown > 0.0 or not is_instance_valid(player):
        return
    fire_ability_cooldown = 15.0
    _update_hud()
    _show_message("INFERNO! FIREBALL LAUNCHED")
    player.launch_fireball()

func boss_defeated(defeated_kind: String = "abomination", electric_rifle_finisher: bool = false) -> void:
    boss_active = null
    # Sandbox is for experimentation and must never grant permanent weapon/ability unlocks.
    if sandbox_mode:
        _update_hud()
        return
    _unlock_achievement("boss_slayer")
    if defeated_kind == "electric_boss" and electric_rifle_finisher and not _is_permanent_unlock("multi_gun_door"):
        _save_permanent_unlock("multi_gun_door")
        _open_secret_door()
        if network_active and network_is_host:
            rpc("_rpc_apply_multiplayer_unlock", "multi_gun_door")
        _show_message("A HIDDEN WALL RUMBLES OPEN...")
    if defeated_kind == "toxic_tank":
        if not toxic_gun_unlocked:
            toxic_gun_unlocked = true
            _save_permanent_unlock("toxic_gun")
            if is_instance_valid(player):
                player.unlock_toxic_gun()
            if network_active and network_is_host:
                rpc("_rpc_apply_multiplayer_unlock", "toxic_gun")
            _show_message("TOXIC TANK SLAIN! TOXIC GUN UNLOCKED")
        else:
            _show_message("TOXIC TANK SLAIN!")
    elif defeated_kind == "electric_boss":
        if not electric_rifle_unlocked:
            electric_rifle_unlocked = true
            _save_permanent_unlock("electric_rifle")
            if is_instance_valid(player):
                player.unlock_electric_rifle()
            if network_active and network_is_host:
                rpc("_rpc_apply_multiplayer_unlock", "electric_rifle")
            _show_message("ELECTRIC BRUTE SLAIN! ELECTRIC RIFLE UNLOCKED")
        else:
            _show_message("ELECTRIC BRUTE SLAIN!")
    else:
        if not fire_ability_unlocked:
            fire_ability_unlocked = true
            _save_permanent_unlock("fireball")
            fire_ability_cooldown = 0.0
            if network_active and network_is_host:
                rpc("_rpc_apply_multiplayer_unlock", "fireball")
            _show_message("ABOMINATION SLAIN! FIREBALL UNLOCKED")
        else:
            _show_message("ABOMINATION SLAIN!")
    _update_hud()

func _start_special_event() -> void:
    var events := ["ZOMBIE RUSH", "TOXIC OUTBREAK", "BLACKOUT", "BLOOD MOON", "ARMORED HORDE"]
    special_event_active = events[randi_range(0, events.size() - 1)]
    rare_event_active = special_event_active == "BLOOD MOON" or special_event_active == "ARMORED HORDE"
    special_event_timer = 35.0
    last_special_event_wave = wave
    match special_event_active:
        "ZOMBIE RUSH":
            _show_message("RARE EVENT: ZOMBIE RUSH! FAST HORDE!")
            spawn_timer = minf(spawn_timer, 0.25)
        "TOXIC OUTBREAK":
            _show_message("RARE EVENT: TOXIC OUTBREAK! KEEP MOVING!")
        "BLACKOUT":
            _show_message("RARE EVENT: BLACKOUT! SURVIVE 35 SECONDS!")
        "BLOOD MOON":
            _show_message("RARE EVENT: BLOOD MOON! ZOMBIES MOVE FASTER!")
            spawn_timer = minf(spawn_timer, 0.5)
        "ARMORED HORDE":
            _show_message("RARE EVENT: ARMORED HORDE! TOUGHER ZOMBIES!")

func _spawn_medkit() -> void:
    var kit := Area3D.new()
    kit.name = "Medkit"
    kit.position = Vector3(randf_range(-14.0, 14.0), 0.65, randf_range(-14.0, 14.0))
    kit.set_meta("base_y", kit.position.y)
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 1.0
    shape_node.shape = shape
    kit.add_child(shape_node)

    var box := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = Vector3(0.62, 0.42, 0.42)
    box.mesh = box_mesh
    box.material_override = _mat(Color(0.88, 0.90, 0.82))
    kit.add_child(box)
    var cross_mat := StandardMaterial3D.new()
    cross_mat.albedo_color = Color(0.9, 0.08, 0.07)
    cross_mat.emission_enabled = true
    cross_mat.emission = Color(0.35, 0.015, 0.01)
    var vertical := MeshInstance3D.new()
    var vmesh := BoxMesh.new()
    vmesh.size = Vector3(0.15, 0.3, 0.045)
    vertical.mesh = vmesh
    vertical.position = Vector3(0, 0, -0.225)
    vertical.material_override = cross_mat
    kit.add_child(vertical)
    var horizontal := MeshInstance3D.new()
    var hmesh := BoxMesh.new()
    hmesh.size = Vector3(0.32, 0.11, 0.045)
    horizontal.mesh = hmesh
    horizontal.position = Vector3(0, 0, -0.23)
    horizontal.material_override = cross_mat
    kit.add_child(horizontal)
    # Visible emissive aura makes medkits easy to spot in the dark arena.
    var aura := MeshInstance3D.new()
    aura.name = "GlowAura"
    var aura_mesh := SphereMesh.new()
    aura_mesh.radius = 0.62
    aura_mesh.height = 1.24
    aura.mesh = aura_mesh
    aura.position.y = 0.18
    var aura_mat := StandardMaterial3D.new()
    aura_mat.albedo_color = Color(0.12, 1.0, 0.28, 0.16)
    aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    aura_mat.emission_enabled = true
    aura_mat.emission = Color(0.08, 1.0, 0.22)
    aura_mat.emission_energy_multiplier = 1.8
    aura.material_override = aura_mat
    kit.add_child(aura)
    var glow := OmniLight3D.new()
    glow.name = "GlowLight"
    glow.light_color = Color(0.25, 1.0, 0.38)
    glow.light_energy = 0.8
    glow.omni_range = 4.2
    glow.position.y = 0.3
    kit.add_child(glow)
    kit.body_entered.connect(func(body: Node3D):
        if body == player and game_started and health < 12:
            health = mini(12, health + 5)
            _update_hud()
            _show_message("MEDKIT COLLECTED  +HEALTH")
            play_sfx("res://audio/hit.wav", -2.0)
            medkits.erase(kit)
            kit.queue_free()
    )
    arena.add_child(kit)
    medkits.append(kit)

func play_sfx(path: String, volume_db: float = 0.0) -> void:
    var stream: AudioStream = load(path) as AudioStream
    if stream == null:
        return
    var audio := AudioStreamPlayer.new()
    audio.stream = stream
    audio.volume_db = volume_db
    add_child(audio)
    audio.finished.connect(audio.queue_free)
    audio.play()


func _build_pause_menu() -> void:
    pause_layer = CanvasLayer.new()
    pause_layer.layer = 20
    pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_layer.visible = false
    add_child(pause_layer)
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.025, 0.035, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_layer.add_child(shade)
    pause_panel = VBoxContainer.new()
    pause_panel.set_anchors_preset(Control.PRESET_CENTER)
    pause_panel.size = Vector2(380, 300)
    pause_panel.position = -pause_panel.size * 0.5
    pause_panel.add_theme_constant_override("separation", 12)
    pause_layer.add_child(pause_panel)
    var title := Label.new()
    title.text = "GAME PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
    pause_panel.add_child(title)
    _menu_button(pause_panel, "RESUME", resume_game)
    _menu_button(pause_panel, "SAVE GAME", _save_game)
    _menu_button(pause_panel, "RETURN TO MENU", _return_to_menu)

func _layout_menu_panels() -> void:
    # Recenter menu panels and constrain them to the visible viewport. This keeps
    # every button reachable on short landscape screens and narrow portrait phones.
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var horizontal_margin: float = 18.0
    var vertical_margin: float = 18.0
    if is_instance_valid(menu_layer):
        var menu_panel: Control = menu_layer.get_child(1) as Control if menu_layer.get_child_count() > 1 else null
        if is_instance_valid(menu_panel):
            _fit_centered_panel(menu_panel, Vector2(440.0, 430.0), viewport_size, horizontal_margin, vertical_margin)
    if is_instance_valid(pause_panel):
        _fit_centered_panel(pause_panel, Vector2(380.0, 300.0), viewport_size, horizontal_margin, vertical_margin)

func _fit_centered_panel(panel: Control, preferred_size: Vector2, viewport_size: Vector2, h_margin: float, v_margin: float) -> void:
    var available_width: float = maxf(220.0, viewport_size.x - h_margin * 2.0)
    var available_height: float = maxf(200.0, viewport_size.y - v_margin * 2.0)
    var panel_width: float = minf(preferred_size.x, available_width)
    var panel_height: float = minf(preferred_size.y, available_height)
    # Set all four offsets explicitly. With centered anchors, assigning position
    # and size separately can leave stale right/bottom offsets and push the panel
    # beyond the viewport on some window sizes.
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -panel_width * 0.5
    panel.offset_top = -panel_height * 0.5
    panel.offset_right = panel_width * 0.5
    panel.offset_bottom = panel_height * 0.5
    panel.custom_minimum_size = Vector2(minf(220.0, panel_width), 0.0)
    # Compact menu controls on short screens so the last button remains reachable.
    if panel_height < preferred_size.y and panel is VBoxContainer:
        (panel as VBoxContainer).add_theme_constant_override("separation", 7)
        for child in panel.get_children():
            if child is Button:
                (child as Button).custom_minimum_size.y = 36.0
                (child as Button).add_theme_font_size_override("font_size", 15)
            elif child is Label:
                (child as Label).add_theme_font_size_override("font_size", 25 if panel == pause_panel else 28)
    panel.queue_sort()

func _save_game() -> void:
    if not game_started or not is_instance_valid(player):
        _show_notice("There is no active run to save.")
        return
    var cfg := ConfigFile.new()
    cfg.set_value("save", "version", 1)
    cfg.set_value("save", "game_mode", game_mode)
    cfg.set_value("save", "health", health)
    cfg.set_value("save", "kills", kills)
    cfg.set_value("save", "wave", wave)
    cfg.set_value("save", "kills_in_wave", kills_in_wave)
    cfg.set_value("save", "selected_map", selected_map)
    cfg.set_value("save", "spawn_timer", spawn_timer)
    cfg.set_value("save", "medkit_timer", medkit_timer)
    cfg.set_value("save", "player_position", player.global_position)
    cfg.set_value("save", "player_yaw", player.yaw)
    cfg.set_value("save", "player_pitch", player.pitch)
    cfg.set_value("save", "weapon_index", player.weapon_index)
    cfg.set_value("save", "fire_ability_unlocked", fire_ability_unlocked)
    cfg.set_value("save", "electric_rifle_unlocked", electric_rifle_unlocked)
    cfg.set_value("save", "toxic_gun_unlocked", toxic_gun_unlocked)
    cfg.set_value("save", "gunner_weapon_unlocked", gunner_weapon_unlocked)
    cfg.set_value("save", "dash_cooldown", dash_cooldown)
    cfg.set_value("save", "achievements", achievements)
    var result := cfg.save("user://retro_undead_save.cfg")
    if result == OK:
        _show_message("GAME SAVED • WAVE %d" % wave)
    else:
        _show_notice("Could not save the game. Check device storage permissions.")

func _continue_saved_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://retro_undead_save.cfg") != OK:
        _show_notice("No saved run found yet. Start a game and use PAUSE → SAVE GAME.")
        return
    # Rebuild the run first, then restore its saved progression and position.
    var saved_map := clampi(int(cfg.get_value("save", "selected_map", 0)), 0, 2)
    start_game(str(cfg.get_value("save", "game_mode", "single")))
    selected_map = saved_map
    sandbox_mode = game_mode == "sandbox"
    if sandbox_mode:
        _build_sandbox_arena()
    elif arena_map_index != selected_map:
        _build_arena()
    health = clampi(int(cfg.get_value("save", "health", 12)), 1, 12)
    kills = maxi(0, int(cfg.get_value("save", "kills", 0)))
    wave = maxi(1, int(cfg.get_value("save", "wave", 1)))
    kills_in_wave = maxi(0, int(cfg.get_value("save", "kills_in_wave", 0)))
    spawn_timer = maxf(0.2, float(cfg.get_value("save", "spawn_timer", 1.2)))
    medkit_timer = maxf(1.0, float(cfg.get_value("save", "medkit_timer", 12.0)))
    fire_ability_unlocked = _is_permanent_unlock("fireball") or bool(cfg.get_value("save", "fire_ability_unlocked", false))
    electric_rifle_unlocked = _is_permanent_unlock("electric_rifle") or bool(cfg.get_value("save", "electric_rifle_unlocked", false))
    toxic_gun_unlocked = _is_permanent_unlock("toxic_gun") or bool(cfg.get_value("save", "toxic_gun_unlocked", false))
    gunner_weapon_unlocked = bool(cfg.get_value("save", "gunner_weapon_unlocked", gunner_weapon_unlocked))
    dash_cooldown = maxf(0.0, float(cfg.get_value("save", "dash_cooldown", 0.0)))
    var saved_achievements = cfg.get_value("save", "achievements", achievements)
    if typeof(saved_achievements) == TYPE_DICTIONARY:
        for key in saved_achievements:
            if bool(saved_achievements[key]):
                achievements[key] = true
        _save_achievements()
    var saved_position: Variant = cfg.get_value("save", "player_position", Vector3(0, 1.1, 0))
    if saved_position is Vector3:
        player.global_position = saved_position
    player.yaw = float(cfg.get_value("save", "player_yaw", 0.0))
    player.pitch = clampf(float(cfg.get_value("save", "player_pitch", 0.0)), -1.35, 1.35)
    player.rotation.y = player.yaw
    player.camera.rotation.x = player.pitch
    if gunner_weapon_unlocked:
        player.unlock_gunner_weapon(false)
    if electric_rifle_unlocked:
        player.unlock_electric_rifle()
    if toxic_gun_unlocked:
        player.unlock_toxic_gun()
    var saved_weapon := clampi(int(cfg.get_value("save", "weapon_index", 0)), 0, player.weapon_names.size() - 1)
    if saved_weapon == 6 and not electric_rifle_unlocked:
        saved_weapon = 0
    if saved_weapon == 7 and not gunner_weapon_unlocked:
        saved_weapon = 0
    if saved_weapon == 8 and not toxic_gun_unlocked:
        saved_weapon = 0
    player.weapon_index = saved_weapon
    player._rebuild_weapon_model()
    set_weapon_name(player.weapon_names[player.weapon_index])
    # The saved checkpoint restores the wave, not individual enemy instances;
    # let its scheduled boss spawn again if this is a boss wave.
    boss_spawned_wave = 0
    _update_hud()
    _show_message("SAVE LOADED • WAVE %d" % wave)

func _delete_saved_game() -> void:
    if FileAccess.file_exists("user://retro_undead_save.cfg"):
        DirAccess.remove_absolute("user://retro_undead_save.cfg")

func pause_game() -> void:
    if not game_started or is_paused:
        return
    is_paused = true
    get_tree().paused = true
    pause_layer.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume_game() -> void:
    if not is_paused:
        return
    is_paused = false
    get_tree().paused = false
    pause_layer.visible = false
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _load_high_score() -> void:
    var data := ConfigFile.new()
    if data.load("user://retro_undead_high_score.cfg") == OK:
        high_score_kills = int(data.get_value("record", "kills", 0))
        high_score_wave = int(data.get_value("record", "wave", 1))
    if is_instance_valid(high_score_label):
        high_score_label.text = "BEST RUN  •  %d KILLS  •  WAVE %d" % [high_score_kills, high_score_wave]

func _save_high_score() -> void:
    if kills > high_score_kills or (kills == high_score_kills and wave > high_score_wave):
        high_score_kills = kills
        high_score_wave = wave
        var data := ConfigFile.new()
        data.set_value("record", "kills", high_score_kills)
        data.set_value("record", "wave", high_score_wave)
        data.save("user://retro_undead_high_score.cfg")
    _load_high_score()

func _return_to_menu() -> void:
    if network_active:
        _disconnect_multiplayer()
    if game_started and is_instance_valid(player):
        _save_game()
    get_tree().paused = false
    is_paused = false
    game_started = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if is_instance_valid(pause_layer):
        pause_layer.visible = false
    if is_instance_valid(hud_layer):
        hud_layer.queue_free()
    if is_instance_valid(player):
        player.queue_free()
    for enemy in enemies:
        if is_instance_valid(enemy):
            enemy.queue_free()
    enemies.clear()
    for kit in medkits:
        if is_instance_valid(kit):
            kit.queue_free()
    medkits.clear()
    if is_instance_valid(menu_layer):
        menu_layer.visible = true
    _load_high_score()
    _refresh_username_display()

func show_hit_marker() -> void:
    if not is_instance_valid(hit_marker):
        return
    hit_marker.visible = true
    hit_marker.modulate.a = 1.0
    var marker_tween: Tween = create_tween()
    marker_tween.tween_property(hit_marker, "modulate:a", 0.0, 0.18)
    marker_tween.tween_callback(func():
        if is_instance_valid(hit_marker):
            hit_marker.visible = false
            hit_marker.modulate.a = 1.0
    )

func trigger_screen_shake(strength: float = 0.045, duration: float = 0.10) -> void:
    screen_shake_strength = strength
    screen_shake_time = duration

func explode_barrel(world_position: Vector3, radius: float = 5.0, damage: int = 8) -> void:
    play_sfx("res://audio/gunshot.wav", 0.0)
    trigger_screen_shake(0.12, 0.22)
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.28, 0.05)
    flash.light_energy = 4.0
    flash.omni_range = radius * 2.0
    flash.position = world_position
    arena.add_child(flash)
    var light_tween: Tween = create_tween()
    light_tween.tween_property(flash, "light_energy", 0.0, 0.35)
    light_tween.tween_callback(flash.queue_free)
    for enemy in enemies.duplicate():
        if is_instance_valid(enemy) and enemy.global_position.distance_to(world_position) <= radius:
            if enemy.has_method("take_hit"):
                enemy.take_hit(damage)
    if is_instance_valid(player) and player.global_position.distance_to(world_position) <= radius:
        damage_player(2)


func try_dash() -> void:
    if not game_started or is_paused or dash_cooldown > 0.0 or not is_instance_valid(player):
        return
    var input_dir := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left") + joystick_vector.x,
        Input.get_action_strength("move_forward") - Input.get_action_strength("move_back") - joystick_vector.y
    ).limit_length(1.0)
    if input_dir.length() < 0.1:
        dash_direction = -player.global_transform.basis.z
    else:
        dash_direction = (player.global_transform.basis.x * input_dir.x - player.global_transform.basis.z * input_dir.y).normalized()
    dash_direction.y = 0.0
    dash_direction = dash_direction.normalized()
    dash_time = 0.20
    # A dash must be a short burst, not a permanent glide in Sandbox.
    if sandbox_mode and not bool(player.get("sandbox_flying")):
        player.velocity.y = 0.0
    dash_cooldown = 3.0
    trigger_screen_shake(0.018, 0.10)
    _show_message("DASH!")

func _load_achievements() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://retro_undead_achievements.cfg") == OK:
        achievements = cfg.get_value("achievements", "unlocked", {})
    if typeof(achievements) != TYPE_DICTIONARY:
        achievements = {}

func _save_achievements() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("achievements", "unlocked", achievements)
    cfg.save("user://retro_undead_achievements.cfg")

func _unlock_achievement(key: String) -> void:
    if bool(achievements.get(key, false)):
        return
    achievements[key] = true
    _save_achievements()
    var title := _title_for_achievement(key)
    _show_message("ACHIEVEMENT UNLOCKED: " + title)

func _check_achievements() -> void:
    if kills >= 10:
        _unlock_achievement("first_10")
    if kills >= 50:
        _unlock_achievement("slayer_50")
    if wave >= 10:
        _unlock_achievement("wave_10")
    if wave >= 25:
        _unlock_achievement("wave_25")
    if gunner_weapon_unlocked:
        _unlock_achievement("gunner_collector")

func _title_for_achievement(key: String) -> String:
    var titles := {"first_10":"FIRST BLOOD", "slayer_50":"ZOMBIE SLAYER", "wave_10":"SURVIVOR", "wave_25":"ARENA LEGEND", "boss_slayer":"BOSS BREAKER", "gunner_collector":"GUNNER COLLECTOR"}
    return str(titles.get(key, key.to_upper()))

func _show_achievements() -> void:
    var lines := ["ACHIEVEMENTS & TITLES", ""]
    var all := ["first_10", "slayer_50", "wave_10", "wave_25", "boss_slayer", "gunner_collector"]
    for key in all:
        lines.append(("[UNLOCKED] " if bool(achievements.get(key, false)) else "[LOCKED]   ") + _title_for_achievement(key))
    var dialog := AcceptDialog.new()
    dialog.title = "ACHIEVEMENTS"
    dialog.dialog_text = "\n".join(lines)
    add_child(dialog)
    dialog.confirmed.connect(func(): dialog.queue_free())
    dialog.popup_centered(Vector2i(430, 360))

func _show_weapon_collection() -> void:
    var lines := ["WEAPON COLLECTION", ""]
    var names := ["PISTOL", "ASSAULT RIFLE", "SHOTGUN", "SNIPER", "RPG", "MINIGUN", "ELECTRIC RIFLE", "GUNNER'S GUN", "TOXIC GUN"]
    var unlocked := [true, true, true, true, true, true, electric_rifle_unlocked, gunner_weapon_unlocked, toxic_gun_unlocked]
    if is_instance_valid(player):
        unlocked[6] = player.unlocked_weapons[6]
        unlocked[7] = player.unlocked_weapons[7]
    else:
        unlocked[6] = _is_permanent_unlock("electric_rifle")
    for i in range(names.size()):
        lines.append(("[UNLOCKED] " if unlocked[i] else "[LOCKED]   ") + names[i])
    lines.append("\nGunner's Gun: 5% chance per Gunner defeated until unlocked.")
    var dialog := AcceptDialog.new()
    dialog.title = "WEAPON COLLECTION"
    dialog.dialog_text = "\n".join(lines)
    add_child(dialog)
    dialog.confirmed.connect(func(): dialog.queue_free())
    dialog.popup_centered(Vector2i(430, 380))
