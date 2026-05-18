extends RefCounted
class_name TestController

signal answer_processed(is_correct: bool)
signal consecutive_updated(correct: int, wrong: int)
signal vision_updated(new_vision: float)

var level_manager: VisionLevelManager
var vision_calc: VisionCalculator
var container: OptotypeContainer

func init(mgr: VisionLevelManager, calc: VisionCalculator, cont: OptotypeContainer):
	level_manager = mgr
	vision_calc = calc
	container = cont

func process_answer(dir_str: String):
	# 先读目标方向（build 已在上一帧完成，此时值正确）
	var answer_dir = _str_to_dir(dir_str)
	var is_correct = (answer_dir == container.target_direction)

	if is_correct:
		level_manager.record_correct()
	else:
		level_manager.record_wrong()

	answer_processed.emit(is_correct)
	consecutive_updated.emit(level_manager.correct_streak, level_manager.wrong_streak)
	vision_updated.emit(level_manager.get_current_vision())

	# 答完后刷新视标（延迟到下一帧执行，见 OptotypeContainer._pending_build）
	_refresh()

func force_refresh():
	_refresh()

func _refresh():
	var px = vision_calc.calculate_optotype_pixel_size(level_manager.get_current_vision())
	container.refresh(px)

func _str_to_dir(s: String) -> int:
	match s:
		"up": return EyeChart.Direction.UP
		"down": return EyeChart.Direction.DOWN
		"left": return EyeChart.Direction.LEFT
		"right": return EyeChart.Direction.RIGHT
	return EyeChart.Direction.RIGHT
