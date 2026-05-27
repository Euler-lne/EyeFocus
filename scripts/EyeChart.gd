extends Control
class_name EyeChart

enum Direction {UP, DOWN, LEFT, RIGHT}

var direction: int = Direction.RIGHT
var size_px: float = 100.0
var draw_color: Color = Color.WHITE

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
	var cell = s / 5.0  # 每个栅格边长（1/5 总边长）
	var color = draw_color

	match direction:
		# 开口向右（基准方向）
		Direction.RIGHT:
			# 竖线在左，三横向右，占满整个高度
			draw_rect(Rect2(0, 0, cell, s), color)
			draw_rect(Rect2(0, 0, s, cell), color)
			draw_rect(Rect2(0, cell * 2, s, cell), color)
			draw_rect(Rect2(0, s - cell, s, cell), color)

		# 开口向左
		Direction.LEFT:
			# 竖线在右，三横向左，占满整个高度
			draw_rect(Rect2(s - cell, 0, cell, s), color)
			draw_rect(Rect2(0, 0, s, cell), color)
			draw_rect(Rect2(0, cell * 2, s, cell), color)
			draw_rect(Rect2(0, s - cell, s, cell), color)

		# 开口向上
		Direction.UP:
			# 横线在下，三竖向上，占满整个宽度
			draw_rect(Rect2(0, s - cell, s, cell), color)
			draw_rect(Rect2(0, 0, cell, s), color)
			draw_rect(Rect2(cell * 2, 0, cell, s), color)
			draw_rect(Rect2(s - cell, 0, cell, s), color)

		# 开口向下
		Direction.DOWN:
			# 横线在上，三竖向下，占满整个宽度
			draw_rect(Rect2(0, 0, s, cell), color)
			draw_rect(Rect2(0, 0, cell, s), color)
			draw_rect(Rect2(cell * 2, 0, cell, s), color)
			draw_rect(Rect2(s - cell, 0, cell, s), color)
