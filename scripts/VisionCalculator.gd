extends RefCounted
class_name VisionCalculator

var screen_diag_inch : float = 24.0
var screen_width_px  : int   = 1920
var screen_height_px : int   = 1080
var test_distance_m  : float = 5.0
var px_per_mm        : float = 0.0

func set_screen_params(diag_inch: float, width_px: int, height_px: int):
	screen_diag_inch = max(diag_inch, 1.0)
	screen_width_px  = width_px
	screen_height_px = height_px
	_recalc_ppmm()

func set_test_distance(dist_m: float):
	test_distance_m = max(dist_m, 0.1)

func _recalc_ppmm():
	var diag_px = sqrt(float(screen_width_px * screen_width_px + screen_height_px * screen_height_px))
	var diag_mm = screen_diag_inch * 25.4
	px_per_mm = diag_px / diag_mm if diag_mm > 0.0 else 4.0

func get_px_per_mm() -> float:
	if px_per_mm <= 0.0:
		_recalc_ppmm()
	return px_per_mm

# 视力值 → 视标像素边长（严格符合 GB 11533）
func calculate_optotype_pixel_size(vision_value: float) -> float:
	if px_per_mm <= 0.0:
		_recalc_ppmm()
	if vision_value <= 0.0:
		return 400.0

	var angle_rad = deg_to_rad(1.0 / 60.0)
	var stroke_mm = tan(angle_rad) / vision_value * test_distance_m * 1000.0
	var side_mm   = stroke_mm * 5.0
	var side_px   = side_mm * px_per_mm
	var result    = max(side_px, 8.0)
	if side_px < 8.0:
		print("计算出的像素太小了")

	# 🧪 调试打印
	print("VisionCalc: vision=%.2f, side_mm=%.3f, px_per_mm=%.3f, side_px=%.1f -> result=%.1f" % [vision_value, side_mm, px_per_mm, side_px, result])
	return result

# 像素边长反推视力值（调试用）
func pixel_size_to_vision(side_px: float) -> float:
	if px_per_mm <= 0.0 or side_px <= 0.0:
		return 0.0
	var stroke_mm = (side_px / px_per_mm) / 5.0
	return tan(deg_to_rad(1.0 / 60.0)) * test_distance_m * 1000.0 / stroke_mm
