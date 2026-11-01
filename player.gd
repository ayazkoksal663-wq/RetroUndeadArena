extends CharacterBody3D
var sandbox_flying := false

var game
var camera: Camera3D
var pitch := 0.0
var yaw := 0.0
var cooldown := 0.0
var gun_root: Node3D
var gun_home := Vector3(0.32, -0.28, -0.55)
var walk_time := 0.0
var moving := false
var weapon_index := 0
var weapon_names := ["PISTOL", "ASSAULT RIFLE", "SHOTGUN", "SNIPER", "RPG", "MINIGUN", "ELECTRIC RIFLE", "GUNNER'S GUN", "TOXIC GUN", "MULTI-GUN"]
var unlocked_weapons: Array[bool] = [true, true, true, true, true, true, false, false, false, false]
var weapon_cooldowns := [0.28, 0.105, 0.72, 0.95, 1.15, 0.065, 0.22, 0.085, 0.16, 0.34]
var weapon_damages := [1, 1, 2, 8, 18, 1, 2, 2, 1, 2]
var weapon_ranges := [55.0, 65.0, 42.0, 100.0, 75.0, 62.0, 60.0, 72.0, 58.0, 65.0]
var weapon_pellets := [1, 1, 7, 1, 1, 1, 1, 1, 1, 1]
var weapon_spreads := [0.0, 0.018, 0.105, 0.002, 0.006, 0.035, 0.008, 0.025, 0.012, 0.018]
var weapon_pitch := [1.0, 1.24, 0.72, 0.58, 0.48, 1.55, 1.05, 1.35, 0.9, 0.8]
var weapon_volume := [-3.0, -5.0, -1.0, -2.0, 1.0, -7.0, -4.0, -6.0, -3.0, -2.0]
var weapon_colors := [
    Color(1.0, 0.78, 0.18), Color(0.35, 1.0, 0.35), Color(1.0, 0.42, 0.12),
    Color(0.3, 0.85, 1.0), Color(1.0, 0.20, 0.035), Color(1.0, 0.83, 0.24), Color(0.15, 0.85, 1.0), Color(0.75, 0.82, 0.88), Color(0.45, 1.0, 0.12), Color(0.65, 1.0, 0.35)
]

func setup(game_ref) -> void:
    game = game_ref
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.7
    col.shape = shape
    add_child(col)
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.55, 0)
    camera.current = true
    add_child(camera)
    _build_gun()
    if game.gunner_weapon_unlocked:
        unlock_gunner_weapon(false)
    if game.multi_gun_unlocked:
        unlocked_weapons[9] = true
    game.set_weapon_name(weapon_names[weapon_index])

func _build_gun() -> void:
    gun_root = Node3D.new()
    gun_root.position = gun_home
    camera.add_child(gun_root)
    _rebuild_weapon_model()

func _clear_gun_model() -> void:
    for child in gun_root.get_children():
        child.queue_free()

func _rebuild_weapon_model() -> void:
    _clear_gun_model()
    # Shared receiver, grip and stock proportions are tuned for the existing
    # first-person camera. All parts use lit materials and small surface textures.
    var body_size := Vector3(0.22, 0.16, 0.38)
    var barrel_length := 0.28
    var barrel_radius := 0.038
    var body_color := Color(0.16, 0.18, 0.19)
    match weapon_index:
        1: # Assault rifle
            body_size = Vector3(0.23, 0.17, 0.49)
            barrel_length = 0.43
            barrel_radius = 0.029
            body_color = Color(0.20, 0.23, 0.19)
        2: # Shotgun
            body_size = Vector3(0.24, 0.18, 0.43)
            barrel_length = 0.34
            barrel_radius = 0.052
            body_color = Color(0.18, 0.16, 0.13)
        3: # Sniper rifle
            body_size = Vector3(0.19, 0.15, 0.60)
            barrel_length = 0.60
            barrel_radius = 0.025
            body_color = Color(0.12, 0.17, 0.20)
        4: # RPG-style launcher
            body_size = Vector3(0.27, 0.22, 0.44)
            barrel_length = 0.37
            barrel_radius = 0.074
            body_color = Color(0.24, 0.22, 0.16)
        5: # Minigun
            body_size = Vector3(0.29, 0.21, 0.44)
            barrel_length = 0.42
            barrel_radius = 0.033
            body_color = Color(0.24, 0.23, 0.18)
        6: # Electric rifle
            body_size = Vector3(0.23, 0.18, 0.45)
            barrel_length = 0.39
            barrel_radius = 0.035
            body_color = Color(0.08, 0.20, 0.23)
        7: # Rare heavy weapon
            body_size = Vector3(0.27, 0.20, 0.49)
            barrel_length = 0.44
            barrel_radius = 0.038
            body_color = Color(0.27, 0.29, 0.30)
        9: # Secret four-barrel Multi-Gun
            body_size = Vector3(0.34, 0.24, 0.48)
            barrel_length = 0.48
            barrel_radius = 0.045
            body_color = Color(0.18, 0.25, 0.19)

    _gun_box(Vector3(0, 0, -0.035), body_size, body_color)
    # Barrel, muzzle collar and dark recessed muzzle opening.
    _gun_cylinder(Vector3(0, 0.015, -0.22 - barrel_length * 0.5), barrel_radius, barrel_length, Color(0.075, 0.082, 0.085))
    _gun_cylinder(Vector3(0, 0.015, -0.22 - barrel_length), barrel_radius * 1.28, 0.045, Color(0.19, 0.20, 0.20))
    _gun_cylinder(Vector3(0, 0.015, -0.22 - barrel_length - 0.024), barrel_radius * 0.72, 0.006, Color(0.012, 0.014, 0.015))
    if weapon_index == 9:
        for bx in [-0.105, -0.035, 0.035, 0.105]:
            _gun_cylinder(Vector3(bx, 0.025, -0.22 - barrel_length - 0.06), 0.026, 0.52, Color(0.12, 0.14, 0.13))
        _gun_box(Vector3(0, 0.14, -0.23), Vector3(0.31, 0.07, 0.34), Color(0.10, 0.13, 0.11))
    # Textured pistol grip and rear stock/handguard.
    _gun_box(Vector3(0, -0.145, 0.075), Vector3(0.115, 0.20, 0.13), Color(0.105, 0.11, 0.105))
    if weapon_index == 0:
        _gun_box(Vector3(0, -0.075, 0.18), Vector3(0.105, 0.075, 0.12), Color(0.10, 0.11, 0.11))
    else:
        _gun_box(Vector3(0, -0.075, 0.245), Vector3(0.13, 0.12, 0.27), Color(0.25, 0.17, 0.105))
    _gun_box(Vector3(0, -0.065, -0.19), Vector3(body_size.x * 0.83, 0.075, 0.19), Color(0.095, 0.105, 0.10))
    # Top rail with evenly spaced raised grooves and compact iron sights.
    _gun_box(Vector3(0, body_size.y * 0.5 + 0.018, -0.11), Vector3(body_size.x * 0.52, 0.025, 0.29), Color(0.075, 0.08, 0.08))
    for groove in range(6):
        _gun_box(Vector3(0, body_size.y * 0.5 + 0.034, -0.22 + groove * 0.043), Vector3(body_size.x * 0.58, 0.008, 0.012), Color(0.30, 0.31, 0.30))
    _gun_box(Vector3(0, body_size.y * 0.5 + 0.055, -0.27), Vector3(0.035, 0.035, 0.045), Color(0.10, 0.11, 0.11))
    _gun_box(Vector3(0, body_size.y * 0.5 + 0.045, 0.015), Vector3(0.055, 0.025, 0.045), Color(0.12, 0.13, 0.13))
    # Magazine, release catch, trigger guard and small receiver fasteners.
    var mag_size := Vector3(0.105, 0.18, 0.12)
    if weapon_index == 2:
        mag_size = Vector3(0.11, 0.12, 0.18)
    elif weapon_index == 5:
        mag_size = Vector3(0.18, 0.15, 0.18)
    elif weapon_index == 4:
        mag_size = Vector3(0.14, 0.12, 0.17)
    _gun_box(Vector3(0, -0.18, -0.015), mag_size, Color(0.075, 0.085, 0.08))
    _gun_box(Vector3(0, -0.27, -0.015), Vector3(mag_size.x * 0.82, 0.012, mag_size.z * 0.84), Color(0.18, 0.19, 0.18))
    _gun_box(Vector3(0.07, -0.055, 0.035), Vector3(0.035, 0.025, 0.055), Color(0.38, 0.39, 0.37))
    _gun_box(Vector3(0, -0.09, 0.0), Vector3(0.075, 0.018, 0.065), Color(0.035, 0.04, 0.04))
    for side in [-1.0, 1.0]:
        _gun_sphere(Vector3(side * body_size.x * 0.39, 0.015, -0.035), 0.012, Color(0.42, 0.43, 0.41))
        _gun_box(Vector3(side * (body_size.x * 0.5 + 0.002), -0.005, -0.10), Vector3(0.008, 0.035, 0.12), Color(0.25, 0.27, 0.26))

    match weapon_index:
        1: # Rifle: long handguard, adjustable stock and compact optic
            _gun_box(Vector3(0, -0.02, 0.17), Vector3(0.15, 0.14, 0.20), Color(0.12, 0.14, 0.12))
            _gun_box(Vector3(0, 0.105, -0.10), Vector3(0.105, 0.07, 0.16), Color(0.055, 0.06, 0.06))
            _gun_box(Vector3(0, 0.15, -0.10), Vector3(0.13, 0.025, 0.19), Color(0.25, 0.27, 0.25))
        2: # Shotgun: wood furniture and twin barrel bands
            _gun_box(Vector3(0, -0.02, -0.20), Vector3(0.17, 0.105, 0.22), Color(0.37, 0.22, 0.12))
            _gun_cylinder(Vector3(-0.035, 0.025, -0.40), 0.027, 0.35, Color(0.07, 0.075, 0.075))
            _gun_cylinder(Vector3(0.035, 0.025, -0.40), 0.027, 0.35, Color(0.07, 0.075, 0.075))
            _gun_box(Vector3(0, 0.075, -0.30), Vector3(0.19, 0.025, 0.06), Color(0.35, 0.36, 0.34))
        3: # Sniper: scope tube and lens rings
            _gun_cylinder(Vector3(0, 0.14, -0.17), 0.047, 0.27, Color(0.045, 0.05, 0.052))
            _gun_cylinder(Vector3(0, 0.14, -0.315), 0.058, 0.035, Color(0.25, 0.27, 0.27))
            _gun_cylinder(Vector3(0, 0.14, -0.025), 0.055, 0.035, Color(0.25, 0.27, 0.27))
            _gun_box(Vector3(0, -0.03, 0.20), Vector3(0.12, 0.10, 0.24), Color(0.11, 0.15, 0.17))
        4: # Launcher: broad tube, bands and warning stripe
            _gun_cylinder(Vector3(0, 0.04, -0.39), 0.085, 0.40, Color(0.16, 0.17, 0.15))
            _gun_cylinder(Vector3(0, 0.04, -0.59), 0.095, 0.045, Color(0.39, 0.40, 0.35))
            _gun_box(Vector3(0, 0.17, -0.30), Vector3(0.18, 0.12, 0.20), Color(0.09, 0.10, 0.09))
            _gun_box(Vector3(0, 0.105, -0.43), Vector3(0.18, 0.018, 0.045), Color(0.78, 0.31, 0.06))
        5: # Minigun: cluster of barrels and bulky receiver
            for i in range(6):
                var angle := TAU * float(i) / 6.0
                _gun_cylinder(Vector3(cos(angle) * 0.065, 0.025 + sin(angle) * 0.065, -0.48), 0.022, 0.40, Color(0.065, 0.07, 0.07))
            _gun_cylinder(Vector3(0, 0.025, -0.69), 0.10, 0.045, Color(0.28, 0.29, 0.27))
            _gun_box(Vector3(0, 0.16, -0.16), Vector3(0.25, 0.10, 0.28), Color(0.11, 0.12, 0.11))
        6: # Electric rifle: insulated coils and restrained cyan glow
            _gun_box(Vector3(0, 0.11, -0.17), Vector3(0.16, 0.10, 0.25), Color(0.045, 0.10, 0.12))
            for z in [-0.25, -0.34, -0.43]:
                _gun_box(Vector3(0, 0.11, z), Vector3(0.18, 0.025, 0.035), Color(0.12, 0.58, 0.66))
            _gun_sphere(Vector3(0, 0.15, -0.49), 0.045, Color(0.12, 0.75, 0.95), true)
        7: # Rare weapon: reinforced receiver and silver accents
            _gun_box(Vector3(0, 0.11, -0.14), Vector3(0.18, 0.10, 0.31), Color(0.14, 0.16, 0.17))
            _gun_box(Vector3(0, 0.13, -0.43), Vector3(0.12, 0.12, 0.23), Color(0.42, 0.45, 0.46))
            _gun_box(Vector3(0, -0.02, 0.16), Vector3(0.17, 0.13, 0.19), Color(0.08, 0.09, 0.10))

func _gun_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mat.roughness = 0.62
    var luminance := (color.r + color.g + color.b) / 3.0
    if color.r > color.g * 1.35 and color.g > color.b * 1.25:
        mat.albedo_texture = load("res://textures/gun_wood.png")
        mat.roughness = 0.78
    elif luminance > 0.22 and absf(color.r - color.b) < 0.12:
        mat.albedo_texture = load("res://textures/gun_metal.png")
        mat.metallic = 0.72
        mat.roughness = 0.34
    else:
        mat.albedo_texture = load("res://textures/gun_polymer.png")
        mat.roughness = 0.72
    if color.b > 0.55 and color.g > 0.45:
        mat.emission_enabled = true
        mat.emission = color * 0.22
        mat.emission_energy_multiplier = 1.15
    return mat

func _gun_box(pos: Vector3, size: Vector3, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _gun_material(color)
    mesh.position = pos
    gun_root.add_child(mesh)

func _gun_cylinder(pos: Vector3, radius: float, length: float, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = length
    cylinder.radial_segments = 12
    mesh.mesh = cylinder
    mesh.material_override = _gun_material(color)
    mesh.position = pos
    mesh.rotation.x = PI * 0.5
    gun_root.add_child(mesh)

func _gun_sphere(pos: Vector3, radius: float, color: Color, glowing: bool = false) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 10
    sphere.rings = 6
    mesh.mesh = sphere
    var mat := _gun_material(color)
    if glowing:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 2.0
    mesh.material_override = mat
    mesh.position = pos
    gun_root.add_child(mesh)

func switch_weapon() -> void:
    var next_index := weapon_index
    for attempt in range(weapon_names.size()):
        next_index = (next_index + 1) % weapon_names.size()
        if unlocked_weapons[next_index]:
            weapon_index = next_index
            break
    _rebuild_weapon_model()
    game.set_weapon_name(weapon_names[weapon_index])
    game._show_message("WEAPON: " + weapon_names[weapon_index])
    game.play_sfx("res://audio/hit.wav", -12.0)

func unlock_gunner_weapon(show_notice: bool = true) -> void:
    if unlocked_weapons.size() > 7 and not unlocked_weapons[7]:
        unlocked_weapons[7] = true
        if is_instance_valid(game):
            game._check_achievements()
        if show_notice and is_instance_valid(game):
            game._show_message("RARE UNLOCK: GUNNER'S GUN!")

func unlock_electric_rifle() -> void:
    if unlocked_weapons.size() > 6 and not unlocked_weapons[6]:
        unlocked_weapons[6] = true
        game.electric_rifle_unlocked = true
        game._show_message("NEW WEAPON UNLOCKED: ELECTRIC RIFLE")

func unlock_multi_gun() -> void:
    if unlocked_weapons.size() > 9:
        unlocked_weapons[9] = true
        game._show_message("MULTI-GUN UNLOCKED!")

func unlock_toxic_gun() -> void:
    if unlocked_weapons.size() > 8 and not unlocked_weapons[8]:
        unlocked_weapons[8] = true
        if is_instance_valid(game):
            game._show_message("NEW WEAPON UNLOCKED: TOXIC GUN")

func _physics_process(delta: float) -> void:
    if not game.game_started:
        return
    cooldown = maxf(0.0, cooldown - delta)
    var mobile: Vector2 = game.get_mobile_move()
    var input_dir := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left") + mobile.x,
        Input.get_action_strength("move_forward") - Input.get_action_strength("move_back") - mobile.y
    ).limit_length(1.0)
    var forward := -global_transform.basis.z
    var right := global_transform.basis.x
    var direction := (right * input_dir.x + forward * input_dir.y).normalized()
    velocity.x = direction.x * 6.0
    velocity.z = direction.z * 6.0
    if game.dash_time > 0.0:
        velocity.x = game.dash_direction.x * 17.0
        velocity.z = game.dash_direction.z * 17.0
    moving = input_dir.length() > 0.1
    walk_time += delta * (10.0 if moving else 3.0)
    var bob := sin(walk_time) * (0.018 if moving else 0.004)
    camera.position.y = 0.55 + bob
    gun_root.position = gun_home + Vector3(0, absf(bob) * 0.8, 0)
    if game.sandbox_mode and sandbox_flying:
        var vertical: float = game.sandbox_vertical_input
        if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
            vertical += 1.0
        if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
            vertical -= 1.0
        velocity.y = vertical * 7.0
    else:
        if not is_on_floor():
            velocity.y -= 18.0 * delta
        else:
            velocity.y = 0.0
    move_and_slide()

func look_by(relative: Vector2) -> void:
    yaw -= relative.x * 0.003
    pitch = clampf(pitch - relative.y * 0.003, -1.35, 1.35)
    rotation.y = yaw
    camera.rotation.x = pitch

func fire() -> void:
    if cooldown > 0.0 or not game.game_started:
        return
    cooldown = weapon_cooldowns[weapon_index]
    if weapon_index == 9:
        _fire_multi_gun()
        return
    gun_root.position.z = gun_home.z + (0.20 if weapon_index == 2 else 0.13)
    _spawn_muzzle_flash()
    game.trigger_screen_shake(0.012 if weapon_index == 1 else (0.045 if weapon_index == 2 else (0.055 if weapon_index == 3 else 0.025)), 0.08)
    var recoil := create_tween()
    recoil.tween_property(gun_root, "position", gun_home, 0.14)
    game.play_weapon_sfx(weapon_pitch[weapon_index], weapon_volume[weapon_index])
    var from: Vector3 = camera.global_position
    var base_direction: Vector3 = -camera.global_transform.basis.z
    var pellets: int = weapon_pellets[weapon_index]
    for pellet in range(pellets):
        var direction := base_direction
        var spread: float = weapon_spreads[weapon_index]
        if spread > 0.0:
            direction = (base_direction + camera.global_transform.basis.x * randf_range(-spread, spread) + camera.global_transform.basis.y * randf_range(-spread, spread)).normalized()
        var to: Vector3 = from + direction * weapon_ranges[weapon_index]
        var query := PhysicsRayQueryParameters3D.create(from, to)
        query.exclude = [self]
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        var end_point: Vector3 = hit.position if not hit.is_empty() else to
        _spawn_visible_bullet(from, end_point, weapon_colors[weapon_index], weapon_index)
        if not hit.is_empty():
            var target = hit.collider
            if weapon_index == 4:
                # RPG damage is handled by the blast so every target follows
                # the same distance-based 5/10 damage rule.
                _rpg_blast(end_point, target)
            elif target and target.has_method("take_hit"):
                if game.network_active and not game.network_is_host and target.has_meta("network_enemy_id"):
                    game.request_network_enemy_hit(target, weapon_damages[weapon_index], weapon_index)
                else:
                    target.set_meta("last_damage_weapon_index", weapon_index)
                    target.set_meta("last_damage_peer_id", 1)
                    target.take_hit(weapon_damages[weapon_index])
                    if weapon_index == 8 and target.has_method("apply_poison"):
                        target.apply_poison()
                    elif weapon_index == 6 and target.has_method("apply_shock"):
                        target.apply_shock()
                    elif weapon_index == 7 and target.has_method("apply_burn"):
                        target.apply_burn()
                game.show_hit_marker()
                game.play_sfx("res://audio/hit.wav", -7.0)

func _fire_multi_gun() -> void:
    gun_root.position.z = gun_home.z + 0.13
    _spawn_muzzle_flash()
    game.trigger_screen_shake(0.035, 0.09)
    game.play_weapon_sfx(0.8, -2.0)
    var from: Vector3 = camera.global_position
    var base_direction: Vector3 = -camera.global_transform.basis.z
    var bullet_colors := [Color(0.45, 1.0, 0.12), Color(0.15, 0.85, 1.0), Color(1.0, 0.78, 0.18), Color(1.0, 0.25, 0.06)]
    for i in range(4):
        var direction := (base_direction + camera.global_transform.basis.x * randf_range(-0.018, 0.018) + camera.global_transform.basis.y * randf_range(-0.018, 0.018)).normalized()
        var to: Vector3 = from + direction * 65.0
        var query := PhysicsRayQueryParameters3D.create(from, to)
        query.exclude = [self]
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        var end_point: Vector3 = hit.position if not hit.is_empty() else to
        _spawn_visible_bullet(from, end_point, bullet_colors[i], 9)
        if not hit.is_empty():
            var target = hit.collider
            if target and target.has_method("take_hit"):
                if game.network_active and not game.network_is_host and target.has_meta("network_enemy_id"):
                    game.request_network_enemy_hit(target, 2, 9, i)
                else:
                    target.set_meta("last_damage_weapon_index", 9)
                    target.set_meta("last_damage_peer_id", 1)
                    target.take_hit(2)
                    if i == 0 and target.has_method("apply_poison"):
                        target.apply_poison()
                    elif i == 1 and target.has_method("apply_shock"):
                        target.apply_shock()
                    elif i == 3 and target.has_method("apply_burn"):
                        target.apply_burn()
                game.show_hit_marker()
                game.play_sfx("res://audio/hit.wav", -7.0)

func _rpg_blast(point: Vector3, direct_target: Object) -> void:
    game.trigger_screen_shake(0.12, 0.24)
    game.play_sfx("res://audio/hit.wav", -2.0)
    # Short-lived blast light and a visible expanding shockwave; only visual
    # nodes are created, so the arena and barriers are never damaged.
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.22, 0.035)
    flash.light_energy = 4.0
    flash.omni_range = 8.0
    flash.position = point + Vector3(0, 0.3, 0)
    game.arena.add_child(flash)
    var light_tw: Tween = game.create_tween()
    light_tw.tween_property(flash, "light_energy", 0.0, 0.32)
    light_tw.tween_callback(flash.queue_free)

    var blast := MeshInstance3D.new()
    var blast_mesh := SphereMesh.new()
    blast_mesh.radius = 0.5
    blast_mesh.height = 1.0
    blast.mesh = blast_mesh
    var blast_mat := StandardMaterial3D.new()
    blast_mat.albedo_color = Color(1.0, 0.19, 0.025, 0.82)
    blast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    blast_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    blast_mat.emission_enabled = true
    blast_mat.emission = Color(1.0, 0.12, 0.015)
    blast_mat.emission_energy_multiplier = 2.5
    blast.material_override = blast_mat
    blast.position = point + Vector3(0, 0.35, 0)
    game.arena.add_child(blast)
    var blast_tw: Tween = game.create_tween()
    blast_tw.set_parallel(true)
    blast_tw.tween_property(blast, "scale", Vector3(8.0, 5.0, 8.0), 0.24)
    blast_tw.tween_property(blast_mat, "albedo_color:a", 0.0, 0.27)
    blast_tw.set_parallel(false)
    blast_tw.tween_callback(blast.queue_free)

    for enemy in game.enemies.duplicate():
        if not is_instance_valid(enemy) or not enemy.has_method("take_hit"):
            continue
        var offset: Vector3 = enemy.global_position - point
        var distance := offset.length()
        if distance > 4.0:
            continue
        var damage := 10 if distance <= 2.0 else 5
        enemy.take_hit(damage)
        var push := Vector3(offset.x, 0.0, offset.z)
        if push.length_squared() > 0.001:
            var strength := 13.0 if not enemy.is_boss else 4.0
            enemy.velocity.x += push.normalized().x * strength
            enemy.velocity.z += push.normalized().z * strength
    game.show_hit_marker()

func launch_fireball() -> void:
    var orb := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.24
    mesh.height = 0.48
    orb.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.18, 0.025)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.10, 0.01)
    mat.emission_energy_multiplier = 3.2
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    orb.material_override = mat
    game.arena.add_child(orb)
    var origin: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.9)
    var direction: Vector3 = -camera.global_transform.basis.z
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 42.0)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var endpoint: Vector3 = hit.position if not hit.is_empty() else origin + direction * 42.0
    orb.global_position = origin
    var travel: Tween = game.create_tween()
    travel.tween_property(orb, "global_position", endpoint, clampf(origin.distance_to(endpoint) / 28.0, 0.12, 0.65))
    travel.tween_callback(func():
        game.trigger_screen_shake(0.07, 0.12)
        for enemy in game.enemies.duplicate():
            if is_instance_valid(enemy) and enemy.global_position.distance_to(endpoint) < 4.5 and enemy.has_method("take_hit"):
                enemy.take_hit(12 if enemy.is_boss else 25)
        if is_instance_valid(orb):
            orb.queue_free()
    )

func _spawn_muzzle_flash() -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.09 if weapon_index != 2 else 0.15
    sphere.height = sphere.radius * 2.0
    flash.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = weapon_colors[weapon_index]
    mat.emission_enabled = true
    mat.emission = weapon_colors[weapon_index]
    mat.emission_energy_multiplier = 3.0
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flash.material_override = mat
    flash.position = Vector3(0, 0.02, -0.82 if weapon_index == 3 else -0.62)
    gun_root.add_child(flash)
    var flash_tween: Tween = create_tween()
    flash_tween.tween_property(flash, "scale", Vector3.ZERO, 0.075)
    flash_tween.tween_callback(flash.queue_free)

func _spawn_visible_bullet(from: Vector3, end_point: Vector3, color: Color, kind: int) -> void:
    var tracer := MeshInstance3D.new()
    var orb := SphereMesh.new()
    orb.radius = 0.045 if kind == 1 else (0.09 if kind == 2 else 0.065)
    orb.height = orb.radius * 2.0
    tracer.mesh = orb
    var tracer_mat := StandardMaterial3D.new()
    tracer_mat.albedo_color = color
    tracer_mat.emission_enabled = true
    tracer_mat.emission = color
    tracer_mat.emission_energy_multiplier = 2.0
    tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tracer.material_override = tracer_mat
    get_tree().current_scene.add_child(tracer)
    tracer.global_position = from + Vector3(0, -0.03, 0)
    var travel_time := clampf(from.distance_to(end_point) / (95.0 if kind == 1 else (55.0 if kind == 2 else 80.0)), 0.045, 0.18)
    var travel := create_tween()
    travel.tween_property(tracer, "global_position", end_point, travel_time)
    travel.tween_callback(tracer.queue_free)
