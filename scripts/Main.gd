extends Control

# ── 节点引用 ────────────────────────────────────────────────
@onready var background_rect: ColorRect = $Background
@onready var left_panel: Panel = $HBoxContainer/LeftPanel
@onready var right_panel: Panel = $HBoxContainer/RightPanel
@onready var optotype_container: OptotypeContainer = \
	$HBoxContainer/CenterContainer/EyeChartArea/OptotypeContainer

@onready var title_label: Label = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/TitleLabel
@onready var mode_label: Label = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ModeSection/ModeLabel
@onready var control_label: Label = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/ControlLabel
@onready var theme_toggle_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/ThemeToggleBtn
@onready var left_eye_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ModeSection/ModeButtons/LeftEyeBtn
@onready var right_eye_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ModeSection/ModeButtons/RightEyeBtn
@onready var both_eye_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ModeSection/ModeButtons/BothEyeBtn
@onready var reset_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/ResetBtn
@onready var pause_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/PauseBtn
@onready var fullscreen_focus_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/FullscreenFocusBtn
@onready var calibrate_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/CalibrateBtn
@onready var result_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/ResultBtn

@onready var info_label: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/InfoLabel
@onready var left_eye_data: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/LeftEyeData
@onready var right_eye_data: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/RightEyeData
@onready var current_vision_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/CurrentVision
@onready var consecutive_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ConsecutiveInfo
@onready var distance_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/DistanceInfo
@onready var screen_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ScreenInfo
@onready var hint_label: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/HintLabel

@onready var calibration_popup: PopupPanel = $CalibrationPopup
@onready var result_popup: PopupPanel = $ResultPopup

@onready var screen_size_edit: LineEdit = $CalibrationPopup/CalibrationVBox/ScreenSizeInput/ScreenSizeEdit
@onready var width_edit: LineEdit = $CalibrationPopup/CalibrationVBox/ResolutionInput/WidthEdit
@onready var height_edit: LineEdit = $CalibrationPopup/CalibrationVBox/ResolutionInput/HeightEdit
@onready var distance_edit: LineEdit = $CalibrationPopup/CalibrationVBox/DistanceInput/DistanceEdit

@onready var up_btn: Button = $DirectionButtonBar/UpBtn
@onready var down_btn: Button = $DirectionButtonBar/DownBtn
@onready var left_btn: Button = $DirectionButtonBar/BottomButtonBar/LeftBtn
@onready var right_btn: Button = $DirectionButtonBar/BottomButtonBar/RightBtn

# 结果弹窗内的子节点
@onready var result_left_lbl: Label = $ResultPopup/ResultVBox/ResultLeftEye
@onready var result_right_lbl: Label = $ResultPopup/ResultVBox/ResultRightEye
@onready var result_title_lbl: Label = $ResultPopup/ResultVBox/ResultTitle
@onready var printer_label: Label = $ResultPopup/ResultVBox/PrinterLabel
@onready var print_btn: Button = $ResultPopup/ResultVBox/PrintBtn
@onready var print_status_lbl: Label = $ResultPopup/ResultVBox/PrintStatusLabel

@onready var calibration_screen_size_lbl: Label = $CalibrationPopup/CalibrationVBox/ScreenSizeInput/ScreenSizeLabel
@onready var calibration_resolution_lbl: Label = $CalibrationPopup/CalibrationVBox/ResolutionInput/ResolutionLabel
@onready var calibration_distance_lbl: Label = $CalibrationPopup/CalibrationVBox/DistanceInput/DistanceLabel
@onready var calibration_confirm_btn: Button = $CalibrationPopup/CalibrationVBox/CalibrationConfirm

# 打印机串口选择（弹窗内）
@onready var port_option: OptionButton = $ResultPopup/ResultVBox/PortHBox/PortOption
@onready var connect_btn: Button = $ResultPopup/ResultVBox/PortHBox/ConnectBtn
@onready var result_close_btn: Button = $ResultPopup/ResultVBox/ResultCloseBtn

# ── 管理器 ──────────────────────────────────────────────────
var vision_calc: VisionCalculator
var level_manager: VisionLevelManager
var test_controller: TestController
var printer_mgr: PrinterManager

# ── 状态 ────────────────────────────────────────────────────
var is_paused: bool = false
var current_mode: String = "left"
var is_testing_left: bool = true
var _answer_feedback_timer: float = 0.0
var current_theme: String = "dark"

# 新增标志，防止重复刷新
var _ignore_resize_refresh: bool = false

# 新增：双眼依次模式下的稳定检测
var _vision_stable_counter: int = 0          # 视力未变化的连续答题次数
var _last_vision_value: float = 0.0          # 上次的视力值
var _left_eye_completed: bool = false        # 左眼是否已完成测试
var _right_eye_completed: bool = false       # 右眼是否已完成测试

const STABLE_THRESHOLD: int = 5              # 连续5次答题视力不变则认为稳定

const DARK_THEME := {
	"background": Color(0.04, 0.04, 0.06, 1.0),
	"panel_bg": Color(0.08, 0.08, 0.10, 1.0),
	"panel_border": Color(0.22, 0.22, 0.28, 1.0),
	"popup_bg": Color(0.09, 0.09, 0.12, 1.0),
	"popup_border": Color(0.25, 0.25, 0.35, 1.0),
	"text": Color(0.88, 0.88, 0.95, 1.0),
	"muted": Color(0.66, 0.66, 0.80, 1.0),
	"accent": Color(0.55, 0.85, 0.85, 1.0),
	"success": Color(0.50, 0.90, 0.60, 1.0),
	"warning": Color(0.90, 0.80, 0.45, 1.0),
	"chart": Color.WHITE,
	"button_text": Color(0.90, 0.90, 0.95, 1.0),
	"toggle_bg": Color(0.14, 0.14, 0.20, 1.0),
	"toggle_border": Color(0.35, 0.35, 0.45, 1.0),
	"button_bg": Color(0.15, 0.15, 0.20, 1.0),
	"button_border": Color(0.35, 0.35, 0.45, 1.0),
	"button_hover": Color(0.22, 0.22, 0.28, 1.0),
	"button_pressed": Color(0.10, 0.10, 0.14, 1.0)
}

const LIGHT_THEME := {
	"background": Color(0.96, 0.97, 0.99, 1.0),
	"panel_bg": Color(0.99, 1.0, 1.0, 1.0),
	"panel_border": Color(0.78, 0.82, 0.90, 1.0),
	"popup_bg": Color(0.98, 0.99, 1.0, 1.0),
	"popup_border": Color(0.80, 0.86, 0.94, 1.0),
	"text": Color(0.10, 0.12, 0.16, 1.0),
	"muted": Color(0.42, 0.46, 0.56, 1.0),
	"accent": Color(0.08, 0.71, 0.71, 1.0),
	"success": Color(0.02, 0.58, 0.28, 1.0),
	"warning": Color(0.85, 0.58, 0.14, 1.0),
	"chart": Color.BLACK,
	"button_text": Color(0.10, 0.12, 0.16, 1.0),
	"toggle_bg": Color(0.90, 0.94, 0.98, 1.0),
	"toggle_border": Color(0.70, 0.78, 0.88, 1.0),
	"button_bg": Color(0.95, 0.97, 1.0, 1.0),
	"button_border": Color(0.70, 0.78, 0.88, 1.0),
	"button_hover": Color(0.89, 0.93, 0.98, 1.0),
	"button_pressed": Color(0.82, 0.88, 0.95, 1.0)
}

# ── 初始化 ──────────────────────────────────────────────────
func _ready():
	_setup_shortcuts()
	
	vision_calc = VisionCalculator.new()
	level_manager = VisionLevelManager.new()
	test_controller = TestController.new()
	test_controller.init(level_manager, vision_calc, optotype_container)
	
	printer_mgr = PrinterManager.new()
	
	test_controller.consecutive_updated.connect(_on_consecutive_updated)
	test_controller.vision_updated.connect(_on_vision_updated)
	test_controller.answer_processed.connect(_on_answer_processed)
	
	up_btn.pressed.connect(func(): _on_answer("up"))
	down_btn.pressed.connect(func(): _on_answer("down"))
	left_btn.pressed.connect(func(): _on_answer("left"))
	right_btn.pressed.connect(func(): _on_answer("right"))
	
	print_btn.pressed.connect(_on_print_result)
	connect_btn.pressed.connect(_on_toggle_port_connect)
	theme_toggle_btn.pressed.connect(_on_theme_toggle_pressed)
	
	get_window().size_changed.connect(_on_window_size_changed)
	
	_load_default_calibration()
	_apply_calibration()
	_apply_theme(current_theme)
	_update_ui_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func _process(delta: float):
	if _answer_feedback_timer > 0.0:
		_answer_feedback_timer -= delta
		if _answer_feedback_timer <= 0.0:
			hint_label.text = ""

# ── 获取当前窗口的实际物理像素尺寸（考虑 DPI 缩放） ─────────────
func _get_window_physical_size() -> Vector2i:
	var window = get_window()
	var logical_size = window.size
	var scale_factor = DisplayServer.screen_get_scale(window.get_current_screen())
	var physical_width = int(round(logical_size.x * scale_factor))
	var physical_height = int(round(logical_size.y * scale_factor))
	return Vector2i(max(physical_width, 1), max(physical_height, 1))

# ── 窗口大小变化时自动重新校准 ─────────────────────────────────
func _on_window_size_changed():
	if _ignore_resize_refresh:
		return
	await get_tree().process_frame
	_refresh_resolution_from_window()

func _refresh_resolution_from_window():
	var phys = _get_window_physical_size()
	width_edit.text = str(phys.x)
	height_edit.text = str(phys.y)
	_apply_calibration()
	hint_label.text = "窗口大小已改变，已自动重新校准分辨率。"
	hint_label.modulate = Color(0.9, 0.8, 0.4)
	_answer_feedback_timer = 2.0

# ── 校准 ────────────────────────────────────────────────────
func _load_default_calibration():
	var phys = _get_window_physical_size()
	screen_size_edit.text = "24.0"
	width_edit.text = str(phys.x)
	height_edit.text = str(phys.y)
	distance_edit.text = "5.0"

func _apply_calibration():
	var diag = float(screen_size_edit.text)
	var w = int(width_edit.text)
	var h = int(height_edit.text)
	var dist = float(distance_edit.text)
	vision_calc.set_screen_params(diag, w, h)
	vision_calc.set_test_distance(dist)
	screen_lbl.text = "屏幕: %.1f\" %dx%d" % [diag, w, h]
	distance_lbl.text = "距离: %.2f 米" % dist
	test_controller.force_refresh()
	
	print("\n======== 校准参数 ========")
	print("屏幕尺寸: %.1f 英寸" % diag)
	print("分辨率: %d x %d" % [w, h])
	print("测试距离: %.2f 米" % dist)
	print("px_per_mm: %.3f" % vision_calc.get_px_per_mm())
	var cur_vision = level_manager.get_current_vision()
	var px = vision_calc.calculate_optotype_pixel_size(cur_vision)
	var mm = px / vision_calc.get_px_per_mm()
	print("当前视力: %.2f" % cur_vision)
	print("理论像素边长: %.1f px" % px)
	print("理论物理边长: %.2f mm" % mm)
	print("==========================\n")

# ── UI 更新 ─────────────────────────────────────────────────
func _update_ui_display():
	left_eye_data.text = "左眼视力: %.2f" % level_manager.get_eye_vision("left")
	right_eye_data.text = "右眼视力: %.2f" % level_manager.get_eye_vision("right")
	var cur = level_manager.get_current_vision()
	match current_mode:
		"left": current_vision_lbl.text = "当前视力: %.2f（左眼）" % cur
		"right": current_vision_lbl.text = "当前视力: %.2f（右眼）" % cur
		"both":
			var n = "左眼" if is_testing_left else "右眼"
			current_vision_lbl.text = "当前视力: %.2f（%s）" % [cur, n]

func _apply_theme(theme_name: String):
	current_theme = theme_name
	var palette = LIGHT_THEME if theme_name == "light" else DARK_THEME

	background_rect.color = palette["background"]
	left_panel.get_theme_stylebox("panel").bg_color = palette["panel_bg"]
	left_panel.get_theme_stylebox("panel").border_color = palette["panel_border"]
	right_panel.get_theme_stylebox("panel").bg_color = palette["panel_bg"]
	right_panel.get_theme_stylebox("panel").border_color = palette["panel_border"]

	_set_label_color(title_label, palette["text"])
	_set_label_color(mode_label, palette["text"])
	_set_label_color(control_label, palette["text"])
	_set_label_color(info_label, palette["text"])
	_set_label_color(left_eye_data, palette["text"])
	_set_label_color(right_eye_data, palette["text"])
	_set_label_color(current_vision_lbl, palette["success"])
	_set_label_color(consecutive_lbl, palette["muted"])
	_set_label_color(distance_lbl, palette["muted"])
	_set_label_color(screen_lbl, palette["muted"])
	_set_label_color(hint_label, palette["warning"])
	_set_label_color(result_title_lbl, palette["text"])
	_set_label_color(result_left_lbl, palette["text"])
	_set_label_color(result_right_lbl, palette["text"])
	_set_label_color(printer_label, palette["muted"])
	_set_label_color(print_status_lbl, palette["success"])
	_set_label_color(calibration_screen_size_lbl, palette["text"])
	_set_label_color(calibration_resolution_lbl, palette["text"])
	_set_label_color(calibration_distance_lbl, palette["text"])

	_set_button_text_color(left_eye_btn, palette["button_text"])
	_set_button_text_color(right_eye_btn, palette["button_text"])
	_set_button_text_color(both_eye_btn, palette["button_text"])
	_set_button_text_color(reset_btn, palette["button_text"])
	_set_button_text_color(pause_btn, palette["button_text"])
	_set_button_text_color(fullscreen_focus_btn, palette["button_text"])
	_set_button_text_color(calibrate_btn, palette["button_text"])
	_set_button_text_color(result_btn, palette["button_text"])
	_set_button_text_color(theme_toggle_btn, palette["button_text"])
	_set_button_text_color(print_btn, palette["button_text"])
	_set_button_text_color(connect_btn, palette["button_text"])
	_set_button_text_color(calibration_confirm_btn, palette["button_text"])
	_set_button_text_color(result_close_btn, palette["button_text"])

	var theme_btn_style = _build_button_style(palette["toggle_bg"], palette["toggle_border"], 999)
	var theme_hover_style = _build_button_style(palette["toggle_bg"], palette["toggle_border"], 999)
	var theme_pressed_style = _build_button_style(palette["toggle_bg"], palette["toggle_border"], 999)
	theme_btn_style.bg_color = palette["toggle_bg"]
	theme_hover_style.bg_color = palette["toggle_bg"]
	theme_pressed_style.bg_color = palette["toggle_bg"]
	theme_toggle_btn.add_theme_stylebox_override("normal", theme_btn_style)
	theme_toggle_btn.add_theme_stylebox_override("hover", theme_hover_style)
	theme_toggle_btn.add_theme_stylebox_override("pressed", theme_pressed_style)
	theme_toggle_btn.text = "白天模式" if theme_name == "dark" else "深色模式"

	var norm_btn_style = _build_button_style(palette["button_bg"], palette["button_border"], 8)
	var hover_btn_style = _build_button_style(palette["button_hover"], palette["button_border"], 8)
	var pressed_btn_style = _build_button_style(palette["button_pressed"], palette["button_border"], 8)
	for button in [left_eye_btn, right_eye_btn, both_eye_btn, reset_btn, pause_btn, fullscreen_focus_btn, calibrate_btn, result_btn, print_btn, connect_btn, calibration_confirm_btn, result_close_btn]:
		button.add_theme_stylebox_override("normal", norm_btn_style)
		button.add_theme_stylebox_override("hover", hover_btn_style)
		button.add_theme_stylebox_override("pressed", pressed_btn_style)
		_set_button_text_color(button, palette["button_text"])

	var direction_style = _build_button_style(palette["button_bg"], palette["button_border"], 8)
	var direction_hover_style = _build_button_style(palette["button_hover"], palette["button_border"], 8)
	var direction_pressed_style = _build_button_style(palette["button_pressed"], palette["button_border"], 8)
	for button in [up_btn, down_btn, left_btn, right_btn]:
		button.add_theme_stylebox_override("normal", direction_style)
		button.add_theme_stylebox_override("hover", direction_hover_style)
		button.add_theme_stylebox_override("pressed", direction_pressed_style)
		_set_button_text_color(button, palette["button_text"])

	var popup_style = _build_panel_style(palette["popup_bg"], palette["popup_border"], 12)
	popup_style.content_margin_left = 12
	popup_style.content_margin_right = 12
	popup_style.content_margin_top = 12
	popup_style.content_margin_bottom = 12
	calibration_popup.add_theme_stylebox_override("panel", popup_style)
	result_popup.add_theme_stylebox_override("panel", popup_style)

	_apply_input_theme(palette)
	optotype_container.set_theme_color(palette["chart"])
	optotype_container.queue_redraw()

func _on_theme_toggle_pressed():
	_apply_theme("light" if current_theme == "dark" else "dark")

func _build_button_style(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _build_panel_style(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _set_label_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)

func _set_button_text_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)

func _apply_input_theme(palette: Dictionary) -> void:
	for edit in [screen_size_edit, width_edit, height_edit, distance_edit]:
		edit.add_theme_color_override("font_color", palette["text"])
		edit.add_theme_color_override("font_selected_color", palette["text"])
		edit.add_theme_color_override("selection_color", palette["accent"].darkened(0.4))
		edit.add_theme_color_override("caret_color", palette["text"])
		edit.add_theme_stylebox_override("normal", _build_input_style(palette["panel_bg"], palette["panel_border"]))
		edit.add_theme_stylebox_override("focus", _build_input_style(palette["panel_bg"], palette["accent"]))

	port_option.add_theme_color_override("font_color", palette["text"])
	port_option.add_theme_color_override("font_selected_color", palette["text"])
	port_option.add_theme_color_override("font_hover_color", palette["text"])
	port_option.add_theme_color_override("font_pressed_color", palette["text"])
	port_option.add_theme_color_override("font_disabled_color", palette["muted"])

func _build_input_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _on_vision_updated(new_vision: float):
	print("视力已更新为: ", new_vision)
	_update_ui_display()
	
	# 只在双眼依次模式下进行稳定检测
	if current_mode == "both":
		# 检查视力值是否变化
		if abs(new_vision - _last_vision_value) < 0.01:
			_vision_stable_counter += 1
		else:
			_vision_stable_counter = 0
		_last_vision_value = new_vision
		
		# 达到稳定阈值，认为当前眼测试完成
		if _vision_stable_counter >= STABLE_THRESHOLD:
			_vision_stable_counter = 0
			_switch_to_next_eye()

func _switch_to_next_eye():
	if is_testing_left:
		# 左眼测试完成，记录最终视力
		level_manager.save_eye_final_vision("left", level_manager.get_current_vision())
		_left_eye_completed = true
		print("左眼测试完成，最终视力: %.2f" % level_manager.get_eye_vision("left"))
		print("请切换至右眼，测试将重置为 1.0")
		# 切换到右眼，重置视力为 1.0
		level_manager.switch_eye("right")
		level_manager.reset_current_eye()   # 重置右眼为 1.0
		is_testing_left = false
		_update_ui_display()
		hint_label.text = "左眼测试完成！请遮挡左眼，开始测试右眼（视力已重置为 1.0）"
		hint_label.modulate = Color(0.9, 0.8, 0.4)
		_answer_feedback_timer = 3.0
	else:
		# 右眼测试完成
		level_manager.save_eye_final_vision("right", level_manager.get_current_vision())
		_right_eye_completed = true
		print("右眼测试完成，最终视力: %.2f" % level_manager.get_eye_vision("right"))
		print("双眼测试全部完成，自动显示结果")
		# 双眼测试完成，自动弹出结果窗口
		_on_show_result()

func _on_consecutive_updated(correct: int, wrong: int):
	consecutive_lbl.text = "连续正确: %d  连续错误: %d" % [correct, wrong]

func _on_answer_processed(is_correct: bool):
	hint_label.text = "✓ 正确" if is_correct else "✗ 错误"
	hint_label.modulate = Color(0.4, 1.0, 0.4) if is_correct else Color(1.0, 0.4, 0.4)
	_answer_feedback_timer = 0.7

# ── 快捷键 ──────────────────────────────────────────────────
func _setup_shortcuts():
	_bind_key("answer_up", [KEY_W, KEY_UP])
	_bind_key("answer_down", [KEY_S, KEY_DOWN])
	_bind_key("answer_left", [KEY_A, KEY_LEFT])
	_bind_key("answer_right", [KEY_D, KEY_RIGHT])

func _bind_key(action: String, keys: Array):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e = InputEventKey.new()
		e.keycode = k
		InputMap.action_add_event(action, e)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if not $HBoxContainer/LeftPanel.visible:
			_on_fullscreen_focus()
		return
	if is_paused:
		return
	if Input.is_action_just_pressed("answer_up"): _on_answer("up")
	elif Input.is_action_just_pressed("answer_down"): _on_answer("down")
	elif Input.is_action_just_pressed("answer_left"): _on_answer("left")
	elif Input.is_action_just_pressed("answer_right"): _on_answer("right")

func _on_answer(dir: String):
	if is_paused:
		return
	test_controller.process_answer(dir)
	_update_ui_display()

# ── 模式切换 ────────────────────────────────────────────────
func _on_mode_left():
	current_mode = "left"
	level_manager.switch_eye("left")
	# 重置左眼视力为 1.0（确保每次独立测试）
	level_manager.reset_current_eye()
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("请遮挡右眼，测试左眼")
	# 重置稳定检测相关变量
	_vision_stable_counter = 0
	_last_vision_value = 0.0
	_left_eye_completed = false
	_right_eye_completed = false

func _on_mode_right():
	current_mode = "right"
	level_manager.switch_eye("right")
	# 重置右眼视力为 1.0
	level_manager.reset_current_eye()
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("请遮挡左眼，测试右眼")
	_vision_stable_counter = 0
	_last_vision_value = 0.0
	_left_eye_completed = false
	_right_eye_completed = false

func _on_mode_both():
	current_mode = "both"
	is_testing_left = true
	level_manager.switch_eye("left")
	# 重置左眼视力为 1.0
	level_manager.reset_current_eye()
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("双眼依次：请先遮挡右眼，测试左眼（左眼将从 1.0 开始）")
	# 重置稳定检测
	_vision_stable_counter = 0
	_last_vision_value = 0.0
	_left_eye_completed = false
	_right_eye_completed = false

func _set_hint(msg: String):
	hint_label.text = msg
	hint_label.modulate = Color(0.9, 0.8, 0.4)
	_answer_feedback_timer = 3.0

# ── 控制按钮 ────────────────────────────────────────────────
func _on_reset_test():
	level_manager.reset_current_eye()
	test_controller.force_refresh()
	_update_ui_display()
	consecutive_lbl.text = "连续正确: 0  连续错误: 0"

func _on_pause_test():
	is_paused = !is_paused
	pause_btn.text = "继续测试" if is_paused else "暂停测试"

func _on_fullscreen_focus():
	var panels = [$HBoxContainer/LeftPanel, $HBoxContainer/RightPanel, $DirectionButtonBar]
	var going_focus = $HBoxContainer/LeftPanel.visible
	for node in panels:
		node.visible = !going_focus
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if going_focus else Input.MOUSE_MODE_VISIBLE)

func _on_open_calibration():
	calibration_popup.popup_centered()

func _on_calibration_confirm():
	_ignore_resize_refresh = true
	_apply_calibration()
	calibration_popup.hide()
	await get_tree().process_frame
	_ignore_resize_refresh = false

# ── 结果弹窗 ────────────────────────────────────────────────
func _on_show_result():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")

	result_left_lbl.text = "左眼视力: %.2f" % lv
	result_right_lbl.text = "右眼视力: %.2f" % rv

	_refresh_port_list()
	_update_connect_btn_text()
	print_status_lbl.text = ""

	result_popup.popup_centered()

func _refresh_port_list():
	port_option.clear()
	var ports = printer_mgr.list_ports()
	if ports.is_empty():
		port_option.add_item("无可用串口")
	else:
		for p in ports:
			port_option.add_item(str(p))

func _update_connect_btn_text():
	if printer_mgr.is_printer_connected():
		connect_btn.text = "断开"
	else:
		connect_btn.text = "连接"

func _on_toggle_port_connect():
	if printer_mgr.is_printer_connected():
		printer_mgr.disconnect_port()
		print_status_lbl.text = "已断开串口"
	else:
		var port_name = port_option.get_item_text(port_option.selected)
		if port_name == "无可用串口":
			print_status_lbl.text = "无可用串口，请检查连接"
			return
		var ok = printer_mgr.connect_port(port_name)
		if ok:
			print_status_lbl.text = "已连接: " + port_name
		else:
			print_status_lbl.text = "连接失败，请检查串口"
	_update_connect_btn_text()

func _on_print_result():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")

	print_status_lbl.text = "正在打印..."
	print_btn.disabled = true

	printer_mgr.print_result(lv, rv)

	print_status_lbl.text = "打印完成 ✓" if printer_mgr.is_printer_connected() else "模拟打印完成（终端已输出）✓"
	print_btn.disabled = false
