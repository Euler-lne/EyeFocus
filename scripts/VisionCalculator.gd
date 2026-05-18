extends RefCounted
class_name VisionCalculator

var screen_diag_inch: float = 24.0
var screen_width_px: int = 1920
var screen_height_px: int = 1080
var test_distance_m: float = 5.0
var px_per_mm: float = 0.0

func set_screen_params(diag_inch: float, width_px: int, height_px: int):
	screen_diag_inch = diag_inch
	screen_width_px = width_px
	screen_height_px = height_px
	_recalc_ppmm()

func set_test_distance(dist_m: float):
	test_distance_m = max(dist_m, 0.1)

func _recalc_ppmm():
	var diag_px = sqrt(float(screen_width_px * screen_width_px
						   + screen_height_px * screen_height_px))
	var diag_mm = screen_diag_inch * 25.4
	px_per_mm = diag_px / diag_mm if diag_mm > 0 else 4.0

# 返回视标正方形边长（像素），最小 20px
# 公式：笔画宽(mm) = tan(1'/V) * distance(mm)
#       视标边长   = 5 * 笔画宽
func calculate_optotype_pixel_size(vision_value: float) -> float:
	if px_per_mm <= 0.0:
		_recalc_ppmm()
	if vision_value <= 0.0:
		return 400.0
	var angle_rad = deg_to_rad(1.0 / 60.0) # 1 分角
	var stroke_mm = tan(angle_rad) * (1.0 / vision_value) * test_distance_m * 1000.0
	var side_mm = stroke_mm * 5.0
	return max(side_mm * px_per_mm, 20.0)
