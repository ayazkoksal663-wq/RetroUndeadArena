extends Control

var game: Node
var joystick_vector: Vector2 = Vector2.ZERO

func _draw() -> void:
    if not OS.has_feature("mobile"):
        return
    var s: Vector2 = size
    var center := Vector2(112.0, s.y - 122.0)
    draw_circle(center, 72.0, Color(0.05, 0.08, 0.10, 0.50))
    draw_arc(center, 72.0, 0.0, TAU, 48, Color(0.65, 0.92, 0.82, 0.78), 3.0)
    draw_circle(center + joystick_vector * 43.0, 29.0, Color(0.55, 0.95, 0.77, 0.50))
    var fire_center := Vector2(s.x - 102.0, s.y - 110.0)
    draw_circle(fire_center, 56.0, Color(0.92, 0.36, 0.08, 0.62))
    draw_arc(fire_center, 56.0, 0.0, TAU, 48, Color(1.0, 0.76, 0.25, 1.0), 4.0)
    draw_string(ThemeDB.fallback_font, fire_center + Vector2(-30.0, 7.0), "FIRE", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 19, Color.WHITE)
