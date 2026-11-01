extends CharacterBody3D

var game
var is_gunner := false
var is_boss := false
var is_abomination := false
var hp := 2
var attack_timer := 0.0
var body_mesh: MeshInstance3D
var animated_limbs: Array[MeshInstance3D] = []
var anim_time := 0.0
var previous_attack_timer := 0.0
var is_dying := false
var enemy_kind: String = "normal"
var spitter_timer: float = 0.0
var boss_attack_timer: float = 1.5
var boss_ground_slam := false
var is_enraged := false
var mini_boss_attack_timer: float = 5.0
var charge_timer: float = 0.0
var enrage_aura: MeshInstance3D
var poison_timer := 0.0
var poison_tick_timer := 0.0
var burn_timer := 0.0
var burn_tick_timer := 0.0
var shock_timer := 0.0
var network_proxy := false

func setup(game_ref, gunner: bool, boss: bool = false, kind: String = "normal") -> void:
    game = game_ref
    is_gunner = gunner
    is_boss = boss
    is_abomination = boss and kind != "electric_boss"
    enemy_kind = kind
    hp = (1150 if kind == "toxic_tank" else (1000 if is_abomination else (100 if kind == "electric_boss" else (42 if kind == "charger" else (34 if kind == "screamer" else (6 if gunner else (9 if kind == "tank" else (3 if kind == "runner" else (6 if kind == "spitter" else (5 if kind == "exploder" else 4))))))))))
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.68 if boss else 0.42
    shape.height = 2.4 if boss else 1.7
    col.shape = shape
    col.position.y = 0.85
    add_child(col)

    # Procedural low-poly character models built from distinct parts (no external assets required).
    var skin_color: Color = Color(0.38, 0.52, 0.29) if not is_gunner else Color(0.62, 0.43, 0.25)
    if kind == "toxic_tank":
        skin_color = Color(0.42, 0.56, 0.18)
    if kind == "electric_boss":
        skin_color = Color(0.22, 0.48, 0.58)
    var clothes_color: Color = Color(0.20, 0.25, 0.16) if not is_gunner else Color(0.10, 0.19, 0.31)
    if kind == "runner":
        skin_color = Color(0.62, 0.72, 0.28)
        clothes_color = Color(0.28, 0.36, 0.12)
    elif kind == "tank":
        skin_color = Color(0.30, 0.36, 0.28)
        clothes_color = Color(0.16, 0.19, 0.15)
    elif kind == "exploder":
        skin_color = Color(0.72, 0.26, 0.12)
        clothes_color = Color(0.34, 0.10, 0.06)
    elif kind == "spitter":
        skin_color = Color(0.24, 0.64, 0.36)
        clothes_color = Color(0.12, 0.30, 0.18)
    elif kind == "charger":
        skin_color = Color(0.68, 0.24, 0.18)
        clothes_color = Color(0.28, 0.08, 0.07)
    elif kind == "screamer":
        skin_color = Color(0.48, 0.28, 0.68)
        clothes_color = Color(0.18, 0.10, 0.28)
    var skin := _material(skin_color)
    var clothes := _material(clothes_color)
    var dark := _material(Color(0.08, 0.09, 0.08))
    _part(BoxMesh.new(), Vector3(0, 0.93, 0), Vector3(0.68, 0.72, 0.38), clothes)
    _part(SphereMesh.new(), Vector3(0, 1.48, 0), Vector3(0.48, 0.48, 0.48), skin)
    # Ragged-looking shoulder/arm and leg pieces give each enemy a readable silhouette.
    for side in [-1.0, 1.0]:
        var arm = _part(CapsuleMesh.new(), Vector3(side * 0.43, 0.91, 0), Vector3(0.19, 0.58, 0.19), skin, Vector3(0, 0, side * -0.18))
        animated_limbs.append(arm)
        var leg = _part(BoxMesh.new(), Vector3(side * 0.20, 0.32, 0), Vector3(0.22, 0.52, 0.25), dark)
        animated_limbs.append(leg)
        _part(BoxMesh.new(), Vector3(side * 0.20, 0.08, -0.06), Vector3(0.27, 0.14, 0.42), dark)
    var eye_mat := _material(Color(1.0, 0.08, 0.025) if not is_gunner else Color(0.95, 0.75, 0.2), true)
    for side in [-1.0, 1.0]:
        _part(SphereMesh.new(), Vector3(side * 0.13, 1.52, -0.205), Vector3(0.075, 0.075, 0.045), eye_mat)
    if is_gunner:
        # Tactical helmet and a clearly visible rifle.
        _part(BoxMesh.new(), Vector3(0, 1.70, 0), Vector3(0.52, 0.16, 0.48), dark)
        _part(BoxMesh.new(), Vector3(0.38, 1.03, -0.25), Vector3(0.12, 0.13, 0.82), dark)
        _part(BoxMesh.new(), Vector3(0.38, 1.03, -0.68), Vector3(0.08, 0.08, 0.30), _material(Color(0.36, 0.38, 0.36)))
    else:
        # Torn-looking dark chest patch and a few muted wound marks.
        _part(BoxMesh.new(), Vector3(-0.12, 1.02, -0.201), Vector3(0.18, 0.24, 0.025), _material(Color(0.28, 0.06, 0.05)))
    if kind == "tank":
        scale = Vector3(1.28, 1.28, 1.28)
        _part(BoxMesh.new(), Vector3(0, 1.08, -0.25), Vector3(0.86, 0.50, 0.16), _material(Color(0.22, 0.25, 0.22)))
    elif kind == "exploder":
        var core_mat := _material(Color(1.0, 0.15, 0.03), true)
        _part(SphereMesh.new(), Vector3(0, 1.02, -0.25), Vector3(0.35, 0.35, 0.35), core_mat)
    elif kind == "spitter":
        _part(SphereMesh.new(), Vector3(0, 1.30, -0.29), Vector3(0.23, 0.18, 0.12), _material(Color(0.12, 1.0, 0.20), true))
    if kind == "charger":
        scale = Vector3(1.22, 1.22, 1.22)
        _part(BoxMesh.new(), Vector3(0, 1.36, -0.26), Vector3(0.20, 0.16, 0.30), _material(Color(0.95, 0.25, 0.08), true))
    elif kind == "screamer":
        scale = Vector3(1.15, 1.15, 1.15)
        _part(SphereMesh.new(), Vector3(0, 1.75, -0.22), Vector3(0.28, 0.28, 0.16), _material(Color(0.78, 0.18, 1.0), true))
    if is_boss:
        scale = Vector3(2.15, 2.15, 2.15) if is_abomination else Vector3(1.55, 1.55, 1.55)
        _part(BoxMesh.new(), Vector3(0, 1.05, -0.23), Vector3(0.78, 0.55, 0.18), _material(Color(0.20, 0.08, 0.07)))
        _part(BoxMesh.new(), Vector3(-0.27, 1.70, -0.03), Vector3(0.16, 0.42, 0.16), _material(Color(0.30, 0.24, 0.18)))
        _part(BoxMesh.new(), Vector3(0.27, 1.70, -0.03), Vector3(0.16, 0.42, 0.16), _material(Color(0.30, 0.24, 0.18)))
        _part(BoxMesh.new(), Vector3(0, 1.83, -0.03), Vector3(0.72, 0.20, 0.55), _material(Color(0.11, 0.12, 0.10)))
        var boss_eye := _material(Color(1.0, 0.03, 0.01) if is_abomination else Color(0.20, 0.90, 1.0), true)
        if not is_abomination:
            _part(SphereMesh.new(), Vector3(0, 1.05, -0.32), Vector3(0.30, 0.34, 0.12), _material(Color(0.15, 0.85, 1.0), true))
        _part(SphereMesh.new(), Vector3(-0.15, 1.54, -0.23), Vector3(0.11, 0.11, 0.06), boss_eye)
        _part(SphereMesh.new(), Vector3(0.15, 1.54, -0.23), Vector3(0.11, 0.11, 0.06), boss_eye)
        enrage_aura = MeshInstance3D.new()
        var aura_mesh := SphereMesh.new()
        aura_mesh.radius = 1.0
        aura_mesh.height = 2.0
        enrage_aura.mesh = aura_mesh
        enrage_aura.scale = Vector3(1.65, 1.45, 1.65)
        var aura_mat := StandardMaterial3D.new()
        aura_mat.albedo_color = Color(1.0, 0.06, 0.025, 0.18)
        aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        aura_mat.emission_enabled = true
        aura_mat.emission = Color(1.0, 0.035, 0.01)
        enrage_aura.material_override = aura_mat
        enrage_aura.position.y = 1.0
        enrage_aura.visible = false
        add_child(enrage_aura)
    if kind == "toxic_tank":
        _build_toxic_tank_model()

func _build_toxic_tank_model() -> void:
    # Replace the shared zombie/boss silhouette with a unique heavy mutant model.
    for child in get_children():
        if child is MeshInstance3D and child != enrage_aura:
            child.free()
    animated_limbs.clear()
    var hide := _material(Color(0.12, 0.13, 0.10))
    var armor := _material(Color(0.19, 0.22, 0.14))
    var skin := _material(Color(0.43, 0.48, 0.22))
    var rust := _material(Color(0.30, 0.16, 0.09))
    var acid := _material(Color(0.22, 1.0, 0.035), true)
    acid.emission_energy_multiplier = 2.0
    # Broad hunched torso, thick legs and oversized asymmetrical arms.
    _part(BoxMesh.new(), Vector3(0, 1.12, 0), Vector3(1.45, 1.15, 0.82), armor)
    _part(SphereMesh.new(), Vector3(0, 1.66, -0.04), Vector3(0.78, 0.72, 0.68), skin)
    _part(BoxMesh.new(), Vector3(0, 1.52, -0.43), Vector3(0.54, 0.24, 0.12), rust)
    _part(SphereMesh.new(), Vector3(0, 1.48, -0.52), Vector3(0.38, 0.34, 0.16), hide)
    _part(BoxMesh.new(), Vector3(0, 1.36, -0.62), Vector3(0.34, 0.08, 0.06), acid)
    for side in [-1.0, 1.0]:
        var shoulder := _part(SphereMesh.new(), Vector3(side * 0.72, 1.52, 0.0), Vector3(0.48, 0.48, 0.52), rust)
        var arm := _part(CapsuleMesh.new(), Vector3(side * 0.91, 0.91, -0.03), Vector3(0.38, 0.88, 0.42), skin, Vector3(0, 0, side * -0.20))
        animated_limbs.append(arm)
        _part(BoxMesh.new(), Vector3(side * 0.98, 0.49, -0.12), Vector3(0.42, 0.34, 0.40), hide)
        var leg := _part(BoxMesh.new(), Vector3(side * 0.34, 0.38, 0.02), Vector3(0.42, 0.70, 0.48), armor)
        animated_limbs.append(leg)
        _part(BoxMesh.new(), Vector3(side * 0.36, 0.08, -0.13), Vector3(0.52, 0.16, 0.62), hide)
        _part(SphereMesh.new(), Vector3(side * 0.15, 1.72, -0.35), Vector3(0.09, 0.10, 0.06), acid)
    # Three unmistakable chemical tanks strapped across its back.
    for i in range(3):
        var x := (float(i) - 1.0) * 0.43
        _part(CylinderMesh.new(), Vector3(x, 2.05, 0.36), Vector3(0.31, 0.72, 0.31), hide)
        _part(CylinderMesh.new(), Vector3(x, 2.08, 0.39), Vector3(0.23, 0.53, 0.23), acid)
        _part(CylinderMesh.new(), Vector3(x, 2.43, 0.36), Vector3(0.30, 0.09, 0.30), rust)
    _part(BoxMesh.new(), Vector3(0, 1.13, -0.46), Vector3(0.54, 0.38, 0.12), hide)
    _part(BoxMesh.new(), Vector3(0, 1.13, -0.54), Vector3(0.26, 0.14, 0.04), acid)

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    # Subtle pixel tiles add painted texture to skin, cloth, and armor without hiding team colors.
    var brightness := (color.r + color.g + color.b) / 3.0
    if color.g > color.r * 1.08 and color.g > color.b * 1.02 and brightness > 0.16:
        mat.albedo_texture = load("res://textures/zombie_skin_pixel.png")
    elif brightness < 0.30:
        mat.albedo_texture = load("res://textures/zombie_cloth_pixel.png")
    else:
        mat.albedo_texture = load("res://textures/metal_detail_pixel.png")
    if glow:
        mat.emission_enabled = true
        mat.emission = color
    return mat

func _part(mesh_resource: Mesh, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh_resource
    if mesh_resource is BoxMesh:
        (mesh_resource as BoxMesh).size = size
    elif mesh_resource is SphereMesh:
        var sphere := mesh_resource as SphereMesh
        sphere.radius = 0.5
        sphere.height = 1.0
        part.scale = size
    elif mesh_resource is CapsuleMesh:
        var capsule := mesh_resource as CapsuleMesh
        capsule.radius = 0.5
        capsule.height = 1.0
        part.scale = size
    elif mesh_resource is CylinderMesh:
        var cylinder := mesh_resource as CylinderMesh
        cylinder.top_radius = 0.5
        cylinder.bottom_radius = 0.5
        cylinder.height = 1.0
        part.scale = size
    part.position = pos
    part.rotation = rot
    part.material_override = mat
    add_child(part)
    return part

func _physics_process(delta: float) -> void:
    if network_proxy:
        if is_dying:
            return
        anim_time += delta
        var proxy_moving := velocity.length() > 0.4
        for i in range(animated_limbs.size()):
            var limb = animated_limbs[i]
            var phase := anim_time * (8.0 if not is_gunner else 6.0) + (PI if i % 2 == 0 else 0.0)
            if i < 2:
                limb.rotation.z = sin(phase) * (0.38 if proxy_moving else 0.08)
            else:
                limb.rotation.x = sin(phase) * (0.48 if proxy_moving else 0.04)
        return
    if burn_timer > 0.0:
        burn_timer = maxf(0.0, burn_timer - delta)
        burn_tick_timer -= delta
        if burn_tick_timer <= 0.0 and not is_dying:
            burn_tick_timer = 0.8
            take_hit(1)
    if shock_timer > 0.0:
        shock_timer = maxf(0.0, shock_timer - delta)
    if is_dying:
        return
    anim_time += delta
    if poison_timer > 0.0:
        poison_timer = maxf(0.0, poison_timer - delta)
        poison_tick_timer -= delta
        if poison_tick_timer <= 0.0 and poison_timer > 0.0:
            poison_tick_timer = 0.8
            take_hit(1)
    var moving_now := velocity.length() > 0.4
    for i in range(animated_limbs.size()):
        var limb = animated_limbs[i]
        var phase := anim_time * (8.0 if not is_gunner else 6.0) + (PI if i % 2 == 0 else 0.0)
        if i < 2:
            limb.rotation.z = sin(phase) * (0.38 if moving_now else 0.08)
        else:
            limb.rotation.x = sin(phase) * (0.48 if moving_now else 0.04)
    if not is_gunner:
        rotation.z = sin(anim_time * 5.0) * (0.035 if moving_now else 0.012)
    if not game.game_started or not is_instance_valid(game.player):
        return
    var target: Vector3 = game.player.global_position
    var target_peer_id := 1
    if game.network_active and game.network_is_host:
        var nearest_distance := global_position.distance_squared_to(target)
        for peer_key in game.network_remote_players.keys():
            var remote = game.network_remote_players[peer_key]
            if is_instance_valid(remote):
                var remote_distance: float = global_position.distance_squared_to(remote.global_position)
                if remote_distance < nearest_distance:
                    nearest_distance = remote_distance
                    target = remote.global_position
                    target_peer_id = int(peer_key)
    game.network_enemy_target_peer = target_peer_id if game.network_active and game.network_is_host else 1
    var diff := target - global_position
    diff.y = 0
    var distance := diff.length()
    if distance > (3.8 if is_boss else 1.6):
        var direction := diff.normalized()
        var move_speed: float = 0.72 if is_boss else (3.7 if enemy_kind == "runner" else (1.05 if enemy_kind == "tank" else (1.65 if enemy_kind == "spitter" else (2.1 if not is_gunner else 1.6))))
        if enemy_kind == "charger":
            charge_timer -= delta
            if charge_timer <= 0.0:
                charge_timer = randf_range(2.8, 4.2)
                game._show_message("CHARGER IS RUSHING!")
            move_speed = 6.2 if charge_timer > 2.1 else 1.9
        if enemy_kind == "screamer":
            move_speed = 1.05
        if is_boss and is_enraged:
            move_speed *= 1.65
        if not is_boss and game.special_event_active == "BLOOD MOON":
            move_speed *= 1.45
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
    else:
        velocity.x = 0
        velocity.z = 0
    # Always face the player, including when a gunner stops to shoot.
    if distance > 0.05:
        look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
    if is_boss and not is_enraged and float(hp) <= float(1150 if enemy_kind == "toxic_tank" else (1000 if is_abomination else 100)) * 0.30:
        is_enraged = true
        if is_instance_valid(enrage_aura):
            enrage_aura.visible = true
        if is_instance_valid(game):
            game._show_message("ENRAGED! THE BOSS IS FASTER!")
            game.trigger_screen_shake(0.08, 0.5)
    if enemy_kind == "screamer":
        mini_boss_attack_timer -= delta
        if mini_boss_attack_timer <= 0.0:
            mini_boss_attack_timer = randf_range(7.0, 10.0)
            if is_instance_valid(game):
                game._screamer_summon(self)
    if is_abomination:
        boss_attack_timer -= delta
        if boss_attack_timer <= 0.0:
            if boss_ground_slam:
                boss_attack_timer = 4.8 if not is_enraged else 2.8
                boss_ground_slam = false
                _boss_ground_slam()
            else:
                boss_attack_timer = (3.0 if not is_enraged else 1.8) if enemy_kind == "toxic_tank" else (3.6 if not is_enraged else 2.2)
                boss_ground_slam = true
                if enemy_kind == "toxic_tank":
                    if is_instance_valid(game):
                        game._show_message("TOXIC TANK SPITS ACID!")
                    _fire_spit_projectile()
                else:
                    _boss_fire_burst()
    if is_gunner:
        attack_timer -= delta
        if distance < 18.0 and attack_timer <= 0.0:
            attack_timer = randf_range(1.6, 2.3)
            _fire_gunner_bullet()
    elif enemy_kind == "electric_boss":
        boss_attack_timer -= delta
        if boss_attack_timer <= 0.0:
            boss_attack_timer = 3.4 if not is_enraged else 1.9
            _electric_burst()
    elif enemy_kind == "spitter":
        spitter_timer -= delta
        if distance < 13.0 and spitter_timer <= 0.0:
            spitter_timer = randf_range(2.0, 2.8)
            _fire_spit_projectile()
        if distance <= 1.6:
            attack_timer -= delta
            if attack_timer <= 0.0:
                attack_timer = 1.2
                game.damage_player(1)
    elif distance <= (3.8 if is_boss else (2.0 if enemy_kind == "exploder" else 1.6)):
        attack_timer -= delta
        if attack_timer <= 0.0:
            attack_timer = 0.9
            if enemy_kind == "exploder":
                game._show_message("EXPLODER DETONATED!")
                game.explode_barrel(global_position, 3.6, 5)
                _play_death_animation()
            else:
                game.damage_player(3 if is_abomination else (1 if enemy_kind == "electric_boss" else (2 if enemy_kind == "tank" else 1)))
                game.play_sfx("res://audio/zombie_groan.wav", -5.0 if is_boss else -8.0)
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    else:
        velocity.y = 0
    move_and_slide()


func _electric_burst() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    game._show_message("ELECTRIC BRUTE: SHOCK PULSE!")
    var bolt := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.12, 0.12, 1.0)
    bolt.mesh = mesh
    bolt.material_override = _material(Color(0.15, 0.85, 1.0), true)
    game.arena.add_child(bolt)
    var start: Vector3 = global_position + Vector3(0, 1.25, 0)
    var target: Vector3 = game.player.global_position + Vector3(0, 0.8, 0)
    bolt.global_position = start
    bolt.look_at(target, Vector3.UP)
    bolt.scale.z = maxf(0.1, start.distance_to(target))
    var tween: Tween = game.create_tween()
    tween.tween_property(bolt, "modulate:a", 0.0, 0.35)
    tween.tween_callback(bolt.queue_free)
    if game.player.global_position.distance_to(global_position) < 11.0:
        game.damage_player(1)

func _boss_ground_slam() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    game._show_message("THE ABOMINATION SLAMS THE GROUND!")
    game.trigger_screen_shake(0.18, 0.42)
    var ring := MeshInstance3D.new()
    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 0.35
    ring_mesh.bottom_radius = 0.35
    ring_mesh.height = 0.12
    ring.mesh = ring_mesh
    var ring_mat := _material(Color(1.0, 0.16, 0.025), true)
    ring.material_override = ring_mat
    ring.position = Vector3(0, 0.12, 0)
    game.arena.add_child(ring)
    ring.global_position = global_position + Vector3(0, -0.35, 0)
    var t: Tween = game.create_tween()
    t.set_parallel(true)
    t.tween_property(ring, "scale", Vector3(11.0, 1.0, 11.0), 0.65)
    t.tween_property(ring_mat, "albedo_color:a", 0.0, 0.65)
    t.set_parallel(false)
    t.tween_callback(ring.queue_free)
    if game.player.global_position.distance_to(global_position) < 7.0:
        game.damage_player(4)

func _boss_fire_burst() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    game._show_message("THE ABOMINATION SPITS FIRE!")
    for i in range(3):
        var fire := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.22
        sphere.height = 0.44
        fire.mesh = sphere
        fire.material_override = _material(Color(1.0, 0.12 + float(i) * 0.05, 0.015), true)
        game.arena.add_child(fire)
        var start: Vector3 = global_position + Vector3(0, 1.7, 0)
        var target: Vector3 = game.player.global_position + Vector3(randf_range(-1.8, 1.8), 0.5, randf_range(-1.8, 1.8))
        fire.global_position = start
        var flight: Tween = game.create_tween()
        flight.tween_property(fire, "global_position", target, 0.55 + float(i) * 0.08)
        flight.tween_callback(func():
            if is_instance_valid(game.player) and game.player.global_position.distance_to(target) < 1.9:
                game.damage_player(2)
            if is_instance_valid(fire):
                fire.queue_free()
        )

func _fire_gunner_bullet() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    game.play_sfx("res://audio/gunshot.wav", -9.0)
    # A bright orange tracer travels from the rifle toward the player's current position.
    # Damage is applied only if the player is still near the impact point when it arrives.
    var bullet := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.075
    sphere.height = 0.15
    bullet.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.25, 0.035)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.12, 0.015)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bullet.material_override = mat
    game.get_tree().current_scene.add_child(bullet)
    var start := global_position + Vector3(0, 1.03, 0) + (-global_transform.basis.z * 0.65)
    var target_node = game.player
    var impact_point: Vector3 = target_node.global_position + Vector3(0, 0.7, 0)
    bullet.global_position = start
    var flight_time: float = clampf(start.distance_to(impact_point) / 24.0, 0.12, 0.48)
    var tween: Tween = game.create_tween()
    tween.tween_property(bullet, "global_position", impact_point, flight_time)
    tween.tween_callback(func():
        if is_instance_valid(target_node) and target_node.global_position.distance_to(impact_point) < 1.25:
            game.damage_player(1)
        if is_instance_valid(bullet):
            bullet.queue_free()
    )

func _fire_spit_projectile() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    var spit := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.13
    sphere.height = 0.26
    spit.mesh = sphere
    var mat := _material(Color(0.12, 1.0, 0.22), true)
    mat.emission_energy_multiplier = 2.5
    spit.material_override = mat
    # Keep this projectile in world space, independent of arena/map transforms.
    # top_level prevents any parent transform from pulling it back toward (0, 0, 0).
    var start: Vector3 = global_transform.origin + Vector3(0, 1.2, 0)
    var target: Vector3 = game.player.global_transform.origin + Vector3(0, 0.65, 0)
    spit.top_level = true
    game.add_child(spit)
    spit.global_transform = Transform3D(Basis.IDENTITY, start)
    var impact_point: Vector3 = target
    var flight: float = clampf(start.distance_to(impact_point) / 14.0, 0.2, 0.9)
    var spit_tween: Tween = game.create_tween()
    spit_tween.tween_property(spit, "global_position", impact_point, flight)
    spit_tween.tween_callback(func():
        if is_instance_valid(game.player) and game.player.global_position.distance_to(impact_point) < 1.5:
            game.damage_player(2)
            game._show_message("ACID SPIT! -2 HEALTH")
        if is_instance_valid(spit):
            spit.queue_free()
    )

func apply_poison() -> void:
    if is_dying:
        return
    poison_timer = 4.0
    poison_tick_timer = 0.8
    # Brief green tint makes the poison effect visible.
    for child in get_children():
        if child is MeshInstance3D and child.material_override is StandardMaterial3D:
            var poison_mat := (child.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
            poison_mat.albedo_color = Color(0.45, 1.0, 0.12)
            poison_mat.emission_enabled = true
            poison_mat.emission = Color(0.18, 0.8, 0.02)
            child.material_override = poison_mat

func apply_burn() -> void:
    burn_timer = maxf(burn_timer, 3.2)
    burn_tick_timer = minf(burn_tick_timer, 0.1)

func apply_shock() -> void:
    shock_timer = maxf(shock_timer, 1.0)
    attack_timer = maxf(attack_timer, 0.8)

func take_hit(amount: int = 1) -> void:
    if is_dying:
        return
    hp -= amount
    if is_instance_valid(game):
        game.show_damage_number(self, amount, is_boss)
        if is_boss:
            if enemy_kind == "toxic_tank":
                game._show_message("TOXIC TANK: %d / 1150 HP" % maxi(0, hp))
            elif is_abomination:
                game._show_message("THE ABOMINATION: %d / 1000 HP" % maxi(0, hp))
            else:
                game._show_message("ELECTRIC BRUTE: %d / 100 HP" % maxi(0, hp))
            game._update_hud()
    # CharacterBody3D has no modulate property. Avoid changing the root scale
    # or color here; this keeps boss size stable and prevents parse errors.
    if hp <= 0:
        if is_boss and is_instance_valid(game):
            game._show_message("BOSS DEFEATED!")
            game.boss_defeated("toxic_tank" if enemy_kind == "toxic_tank" else ("abomination" if is_abomination else "electric_boss"), enemy_kind == "electric_boss" and int(get_meta("last_damage_weapon_index", -1)) == 6)
        _play_death_animation()

func _play_death_animation() -> void:
    is_dying = true
    velocity = Vector3.ZERO
    # Stop further collisions/attacks while the enemy performs a readable death fall.
    for child in get_children():
        if child is CollisionShape3D:
            child.set_deferred("disabled", true)
    var death := create_tween()
    death.set_parallel(true)
    death.tween_property(self, "rotation:z", rotation.z + deg_to_rad(78.0 if randf() > 0.5 else -78.0), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    death.tween_property(self, "position:y", position.y - 0.42, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    death.tween_property(self, "scale", Vector3(0.88, 0.88, 0.88), 0.38)
    death.set_parallel(false)
    death.tween_interval(0.28)
    death.tween_callback(func():
        if is_instance_valid(game):
            game.enemy_killed(self)
        elif is_instance_valid(self):
            queue_free()
    )
