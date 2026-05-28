extends RefCounted
class_name VisionLevelManager

signal vision_level_changed(new_vision: float)

# 标准对数视力表（从小到大：0.10最小，2.0最大）
const VISION_LEVELS: Array[float] = [
	0.10, 0.12, 0.15, 0.20, 0.25, 0.30,
	0.40, 0.50, 0.60, 0.80,
	1.00, 1.20, 1.50, 2.00
]
const DEFAULT_INDEX = 10 # 1.0

# 当前活跃眼
var current_eye: String = "left"
var current_index: int = DEFAULT_INDEX
var correct_streak: int = 0
var wrong_streak: int = 0

# 左右眼独立存储
var _left = {"index": DEFAULT_INDEX, "correct": 0, "wrong": 0}
var _right = {"index": DEFAULT_INDEX, "correct": 0, "wrong": 0}

# ---------- 公开方法 ----------

func switch_eye(eye: String):
	_save()
	current_eye = eye
	_load()
	
# 在 VisionLevelManager.gd 中添加
func save_eye_final_vision(eye: String, vision: float):
	if eye == "left":
		_left["final"] = vision
	else:
		_right["final"] = vision

func get_eye_final_vision(eye: String) -> float:
	return _left["final"] if eye == "left" else _right["final"]

func get_current_vision() -> float:
	return VISION_LEVELS[current_index]

func get_eye_vision(eye: String) -> float:
	if eye == "left":
		return VISION_LEVELS[_left["index"]]
	return VISION_LEVELS[_right["index"]]

func record_correct():
	wrong_streak = 0
	correct_streak += 1
	if correct_streak >= 3:
		correct_streak = 0
		# 正确：提升视力等级（视力值变大，视标变小）
		if current_index < VISION_LEVELS.size() - 1:
			current_index += 1
		_save()
		vision_level_changed.emit(get_current_vision())
	else:
		_save()

func record_wrong():
	correct_streak = 0
	wrong_streak += 1
	if wrong_streak >= 2:
		wrong_streak = 0
		# 错误：降低视力等级（视力值变小，视标变大）
		if current_index > 0:
			current_index -= 1
		_save()
		vision_level_changed.emit(get_current_vision())
	else:
		_save()

func reset_current_eye():
	current_index = DEFAULT_INDEX
	correct_streak = 0
	wrong_streak = 0
	_save()
	vision_level_changed.emit(get_current_vision())

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
	_save()
	vision_level_changed.emit(get_current_vision())

# ---------- 私有 ----------

func _save():
	var store = _left if current_eye == "left" else _right
	store["index"] = current_index
	store["correct"] = correct_streak
	store["wrong"] = wrong_streak

func _load():
	var store = _left if current_eye == "left" else _right
	current_index = store["index"]
	correct_streak = store["correct"]
	wrong_streak = store["wrong"]
