extends Control
class_name EyeChart

enum Direction {UP, DOWN, LEFT, RIGHT}

var direction: int = Direction.RIGHT
var size_px: float = 100.0

func set_direction(dir: int):
	direction = dir
	queue_redraw()

func set_size_px(s: float):
	size_px = max(s, 20.0)
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	queue_redraw()

func _draw():
	var s = size_px
	var center = Vector2(s * 0.5, s * 0.5)
	var stroke = s / 5.0
	var half = s * 0.5

	# 根据方向旋转角度：基准是"开口朝右"
	var angle = 0.0
	match direction:
		Direction.RIGHT: angle = 0.0
		Direction.LEFT: angle = PI
		Direction.UP: angle = - PI * 0.5
		Direction.DOWN: angle = PI * 0.5

	draw_set_transform(center, angle, Vector2.ONE)

	var c = Color.WHITE
	var ox = - half
	var oy = - half

	# 竖笔（左侧）
	draw_rect(Rect2(ox, oy, stroke, s), c)
	# 上横臂
	draw_rect(Rect2(ox, oy, s, stroke), c)
	# 中横臂
	draw_rect(Rect2(ox, oy + half - stroke * 0.5, s, stroke), c)
	# 下横臂
	draw_rect(Rect2(ox, oy + s - stroke, s, stroke), c)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
