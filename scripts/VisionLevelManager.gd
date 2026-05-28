extends RefCounted
class_name VisionLevelManager

signal vision_level_changed(new_vision: float)
signal eye_final_vision_determined(eye: String, final_vision: float)  # 新增信号

const VISION_LEVELS: Array[float] = [
	0.10, 0.12, 0.15, 0.20, 0.25, 0.30,
	0.40, 0.50, 0.60, 0.80,
	1.00, 1.20, 1.50, 2.00
]
const DEFAULT_INDEX = 10
const CORRECT_THRESHOLD = 10
const UP_STREAK = 3
const DOWN_STREAK = 2

# 当前活跃眼
var current_eye: String = "left"
var current_index: int = DEFAULT_INDEX
var correct_streak: int = 0
var wrong_streak: int = 0

# 左右眼各自独立的等级累计正确计数器
var left_level_counts: Array = []
var right_level_counts: Array = []

# 存储左右眼各自的当前等级索引和连续计数（用于切换时保存/恢复）
var _left_state = {"index": DEFAULT_INDEX, "correct": 0, "wrong": 0}
var _right_state = {"index": DEFAULT_INDEX, "correct": 0, "wrong": 0}

func _init():
	for i in range(VISION_LEVELS.size()):
		left_level_counts.append(0)
		right_level_counts.append(0)

# 切换眼睛时保存当前眼状态，加载新眼睛状态
func switch_eye(eye: String):
	# 保存当前眼状态
	if current_eye == "left":
		_left_state["index"] = current_index
		_left_state["correct"] = correct_streak
		_left_state["wrong"] = wrong_streak
	else:
		_right_state["index"] = current_index
		_right_state["correct"] = correct_streak
		_right_state["wrong"] = wrong_streak
	
	current_eye = eye
	# 加载新眼睛状态
	if eye == "left":
		current_index = _left_state["index"]
		correct_streak = _left_state["correct"]
		wrong_streak = _left_state["wrong"]
	else:
		current_index = _right_state["index"]
		correct_streak = _right_state["correct"]
		wrong_streak = _right_state["wrong"]
	
	vision_level_changed.emit(get_current_vision())

func get_current_vision() -> float:
	return VISION_LEVELS[current_index]

# 获取某只眼睛的最终视力（取达到阈值且最高的等级）
func get_eye_vision(eye: String) -> float:
	var counts = left_level_counts if eye == "left" else right_level_counts
	for i in range(VISION_LEVELS.size() - 1, -1, -1):
		if counts[i] >= CORRECT_THRESHOLD:
			return VISION_LEVELS[i]
	return VISION_LEVELS[DEFAULT_INDEX]  # 未达标则返回1.0

func save_eye_final_vision(eye: String, vision: float):
	print("[VisionLevelManager] 保存最终视力: %s = %.2f" % [eye, vision])

func get_eye_final_vision(eye: String) -> float:
	return get_eye_vision(eye)

func record_correct():
	wrong_streak = 0
	correct_streak += 1
	
	var counts = left_level_counts if current_eye == "left" else right_level_counts
	counts[current_index] += 1
	print("等级 %s 累计正确: %d" % [VISION_LEVELS[current_index], counts[current_index]])
	
	# 检查是否达到阈值
	if counts[current_index] >= CORRECT_THRESHOLD:
		eye_final_vision_determined.emit(current_eye, VISION_LEVELS[current_index])
		return
	
	# 升级逻辑
	if correct_streak >= UP_STREAK:
		correct_streak = 0
		if current_index < VISION_LEVELS.size() - 1:
			current_index += 1
			vision_level_changed.emit(get_current_vision())
	
	# 保存当前眼状态（更新存储）
	_save_current_state()

func record_wrong():
	correct_streak = 0
	wrong_streak += 1
	if wrong_streak >= DOWN_STREAK:
		wrong_streak = 0
		if current_index > 0:
			current_index -= 1
			vision_level_changed.emit(get_current_vision())
	
	_save_current_state()

func reset_current_eye():
	var counts = left_level_counts if current_eye == "left" else right_level_counts
	for i in range(counts.size()):
		counts[i] = 0
	current_index = DEFAULT_INDEX
	correct_streak = 0
	wrong_streak = 0
	_save_current_state()
	vision_level_changed.emit(get_current_vision())

func reset_eye(eye: String):
	var counts = left_level_counts if eye == "left" else right_level_counts
	for i in range(counts.size()):
		counts[i] = 0
	if current_eye == eye:
		current_index = DEFAULT_INDEX
		correct_streak = 0
		wrong_streak = 0
		_save_current_state()
		vision_level_changed.emit(get_current_vision())
	else:
		# 如果重置的不是当前眼睛，也要更新对应的存储状态
		if eye == "left":
			_left_state["index"] = DEFAULT_INDEX
			_left_state["correct"] = 0
			_left_state["wrong"] = 0
		else:
			_right_state["index"] = DEFAULT_INDEX
			_right_state["correct"] = 0
			_right_state["wrong"] = 0

func set_vision_force(v: float):
	var best = 0
	var best_diff = abs(VISION_LEVELS[0] - v)
	for i in range(VISION_LEVELS.size()):
		var d = abs(VISION_LEVELS[i] - v)
		if d < best_diff:
			best_diff = d
			best = i
	current_index = best
	correct_streak = 0
	wrong_streak = 0
	_save_current_state()
	vision_level_changed.emit(get_current_vision())

func _save_current_state():
	if current_eye == "left":
		_left_state["index"] = current_index
		_left_state["correct"] = correct_streak
		_left_state["wrong"] = wrong_streak
	else:
		_right_state["index"] = current_index
		_right_state["correct"] = correct_streak
		_right_state["wrong"] = wrong_streak
