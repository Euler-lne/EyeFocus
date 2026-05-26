extends Control
class_name OptotypeContainer

# ── 外部读取：当前目标视标方向 ──────────────────────────────
var target_direction: int = EyeChart.Direction.RIGHT
var chart_color: Color = Color.WHITE

# ── 内部状态 ────────────────────────────────────────────────
var _charts: Array = [] # Array[EyeChart]
var _positions: Array = [] # Array[Vector2] 每个视标的左上角坐标
var _target_idx: int = 0
var _optotype_size: float = 100.0
var _pending_build: bool = false

# 红圈呼吸动画
var _breath_t: float = 0.0
const BREATH_AMP: float = 3.0
const BREATH_SPD: float = 2.5

# 布局参数
const MIN_MARGIN_PX: float = 15.0 # 最小边缘留白（像素）
const DESIRED_MARGIN_RATIO: float = 0.03 # 期望留白占容器短边的比例（用于动态计算间距）
const MIN_SPACING_PX: float = 30.0 # 最小间距（像素）

# ── 公开接口 ────────────────────────────────────────────────

func refresh(optotype_px: float):
	_optotype_size = max(optotype_px, 20.0)
	_pending_build = true

func set_theme_color(color: Color):
	chart_color = color
	for chart in _charts:
		if is_instance_valid(chart):
			chart.draw_color = chart_color
			chart.queue_redraw()
	queue_redraw()

# ── Godot 回调 ──────────────────────────────────────────────

func _ready():
	resized.connect(_on_resized)
	_pending_build = true

func _process(delta: float):
	_breath_t += delta * 2.5
	if _pending_build:
		_pending_build = false
		_build()
	if not _charts.is_empty():
		queue_redraw()

func _draw():
	if _charts.is_empty() or _positions.is_empty():
		return
	var s = _optotype_size
	var breath = sin(_breath_t) * BREATH_AMP
	var r = s * 0.5 + 12.0 + breath # 基础偏移从 6 增加到 12
	var pos = _positions[_target_idx]
	var center = pos + Vector2(s * 0.5, s * 0.5)
	draw_arc(center, r, 0.0, TAU, 64, Color(1.0, 0.0, 0.0, 1.0), 10.0) # 纯红，线宽 5

func _on_resized():
	if _optotype_size > 0.0:
		_pending_build = true

# ── 内部构建（动态间距宽布局）────────────────────────────────
func _build():
	var center = get_parent().get_parent()
	if not center:
		print("无法获取 CenterContainer")
		return

	var center_rect = center.get_global_rect()
	var container_w = center_rect.size.x
	var container_h = center_rect.size.y
	var s = _optotype_size

	if container_w < 10.0 or container_h < 10.0:
		_pending_build = true
		return

	# 清除旧视标
	for c in _charts:
		if is_instance_valid(c):
			c.queue_free()
	_charts.clear()
	_positions.clear()

	# 1. 理论最大行列数（基于最小间距和最小边距）
	var max_cols = floor((container_w - 2 * MIN_MARGIN_PX + MIN_SPACING_PX) / (s + MIN_SPACING_PX))
	var max_rows = floor((container_h - 2 * MIN_MARGIN_PX + MIN_SPACING_PX) / (s + MIN_SPACING_PX))
	max_cols = max(1, max_cols)
	max_rows = max(1, max_rows)

	# 2. 从大到小尝试，找到能完全容纳的行列数，并动态计算实际间距
	var best_cols = 1
	var best_rows = 1
	var best_spacing = MIN_SPACING_PX
	var found = false

	# 优先尝试较大的总视标数（行列数乘积），但为了视觉平衡，可以按行数优先或按乘积
	for try_cols in range(max_cols, 0, -1):
		for try_rows in range(max_rows, 0, -1):
			# 计算在给定行列数下，最大允许间距（使总宽度不超过容器有效宽度）
			var max_spacing_w = (container_w - 2 * MIN_MARGIN_PX - try_cols * s) / (try_cols - 1) if try_cols > 1 else INF
			var max_spacing_h = (container_h - 2 * MIN_MARGIN_PX - try_rows * s) / (try_rows - 1) if try_rows > 1 else INF
			var possible_spacing = min(max_spacing_w, max_spacing_h)
			if possible_spacing < MIN_SPACING_PX:
				continue # 即使最小间距也放不下
			# 实际间距取最大可能间距与最小间距之间，使用最大间距以充分利用空间
			var actual_spacing = possible_spacing
			# 验证实际宽高是否真的不超出
			var actual_w = try_cols * s + (try_cols - 1) * actual_spacing
			var actual_h = try_rows * s + (try_rows - 1) * actual_spacing
			if actual_w <= container_w - 2 * MIN_MARGIN_PX + 0.1 and actual_h <= container_h - 2 * MIN_MARGIN_PX + 0.1:
				best_cols = try_cols
				best_rows = try_rows
				best_spacing = actual_spacing
				found = true
				break
		if found:
			break

	if not found:
		# 极端情况：至少显示一个
		best_cols = 1
		best_rows = 1
		best_spacing = 0

	var target_cols = best_cols
	var target_rows = best_rows
	var spacing = best_spacing

	# 计算实际网格总宽高
	var total_width = target_cols * s + (target_cols - 1) * spacing
	var total_height = target_rows * s + (target_rows - 1) * spacing

	# 计算起始边距（居中，但保证不小于最小边距）
	var margin_left = max(MIN_MARGIN_PX, (container_w - total_width) / 2.0)
	var margin_top = max(MIN_MARGIN_PX, (container_h - total_height) / 2.0)

	# 最终安全校验：防止浮点误差导致超出
	if margin_left + total_width > container_w - MIN_MARGIN_PX:
		margin_left = max(0.0, container_w - total_width - MIN_MARGIN_PX)
	if margin_top + total_height > container_h - MIN_MARGIN_PX:
		margin_top = max(0.0, container_h - total_height - MIN_MARGIN_PX)

	# 全局起始坐标转局部坐标
	var start_global = center_rect.position + Vector2(margin_left, margin_top)
	var offset = start_global - get_global_position()
	var cell_step = s + spacing

	var dirs = [
		EyeChart.Direction.UP,
		EyeChart.Direction.DOWN,
		EyeChart.Direction.LEFT,
		EyeChart.Direction.RIGHT
	]

	for row in range(target_rows):
		for col in range(target_cols):
			var pos_x = offset.x + col * cell_step
			var pos_y = offset.y + row * cell_step
			var pos = Vector2(pos_x, pos_y)
			var chart = EyeChart.new()
			add_child(chart)
			chart.set_size_px(s)
			chart.position = pos
			chart.draw_color = chart_color
			var random_dir = dirs[randi() % dirs.size()]
			chart.set_direction(random_dir)
			_charts.append(chart)
			_positions.append(pos)

	if _charts.size() > 0:
		_target_idx = randi() % _charts.size()
		target_direction = _charts[_target_idx].direction
	else:
		_target_idx = -1
		target_direction = EyeChart.Direction.UP

	queue_redraw()
