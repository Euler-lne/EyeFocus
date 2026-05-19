extends Control

# ── 节点引用 ───────────────────────────────────────────────
@onready var optotype_container: OptotypeContainer = \
	$HBoxContainer/CenterContainer/EyeChartArea/OptotypeContainer

@onready var left_eye_data: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/LeftEyeData
@onready var right_eye_data: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/RightEyeData
@onready var current_vision_lbl: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/CurrentVision
@onready var consecutive_lbl: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ConsecutiveInfo
@onready var distance_lbl: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/DistanceInfo
@onready var screen_lbl: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ScreenInfo

@onready var pause_btn: Button = \
	$HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/PauseBtn

@onready var calibration_popup: PopupPanel = $CalibrationPopup
@onready var result_popup: PopupPanel = $ResultPopup

@onready var screen_size_edit: LineEdit = \
	$CalibrationPopup/CalibrationVBox/ScreenSizeInput/ScreenSizeEdit
@onready var width_edit: LineEdit = \
	$CalibrationPopup/CalibrationVBox/ResolutionInput/WidthEdit
@onready var height_edit: LineEdit = \
	$CalibrationPopup/CalibrationVBox/ResolutionInput/HeightEdit
@onready var distance_edit: LineEdit = \
	$CalibrationPopup/CalibrationVBox/DistanceInput/DistanceEdit

@onready var up_btn: Button = $DirectionButtonBar/UpBtn
@onready var down_btn: Button = $DirectionButtonBar/DownBtn
@onready var left_btn: Button = $DirectionButtonBar/BottomButtonBar/LeftBtn
@onready var right_btn: Button = $DirectionButtonBar/BottomButtonBar/RightBtn

@onready var hint_label: Label = \
	$HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/HintLabel

# ── 管理器 ────────────────────────────────────────────────
var vision_calc: VisionCalculator
var level_manager: VisionLevelManager
var test_controller: TestController

# ── 状态 ─────────────────────────────────────────────────
var is_paused: bool = false
var current_mode: String = "left" # left | right | both
var is_testing_left: bool = true # 双眼依次时用
var _answer_feedback_timer: float = 0.0 # 短暂显示对错反馈

# ── 初始化 ────────────────────────────────────────────────
func _ready():
	vision_calc = VisionCalculator.new()
	level_manager = VisionLevelManager.new()
	test_controller = TestController.new()
	test_controller.init(level_manager, vision_calc, optotype_container)

	# 信号
	test_controller.consecutive_updated.connect(_on_consecutive_updated)
	test_controller.vision_updated.connect(_on_vision_updated)
	test_controller.answer_processed.connect(_on_answer_processed)

	# 底部答题按钮（场景里无 connection，此处代码绑定）
	up_btn.pressed.connect(func(): _on_answer("up"))
	down_btn.pressed.connect(func(): _on_answer("down"))
	left_btn.pressed.connect(func(): _on_answer("left"))
	right_btn.pressed.connect(func(): _on_answer("right"))

	_setup_shortcuts()
	_load_default_calibration()
	_apply_calibration()
	_update_ui_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float):
	if _answer_feedback_timer > 0.0:
		_answer_feedback_timer -= delta
		if _answer_feedback_timer <= 0.0:
			hint_label.text = ""

# ── 校准 ─────────────────────────────────────────────────
func _load_default_calibration():
	var s = DisplayServer.screen_get_size()
	vision_calc.set_screen_params(24.0, s.x, s.y)
	vision_calc.set_test_distance(5.0)
	screen_size_edit.text = "24.0"
	width_edit.text = str(s.x)
	height_edit.text = str(s.y)
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

# ── UI 更新 ───────────────────────────────────────────────
func _update_ui_display():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")
	left_eye_data.text = "左眼视力: %.2f" % lv
	right_eye_data.text = "右眼视力: %.2f" % rv

	var cur = level_manager.get_current_vision()
	match current_mode:
		"left":
			current_vision_lbl.text = "当前视力: %.2f（左眼）" % cur
		"right":
			current_vision_lbl.text = "当前视力: %.2f（右眼）" % cur
		"both":
			var eye_name = "左眼" if is_testing_left else "右眼"
			current_vision_lbl.text = "当前视力: %.2f（%s）" % [cur, eye_name]

func _on_vision_updated(_v: float):
	_update_ui_display()

func _on_consecutive_updated(correct: int, wrong: int):
	consecutive_lbl.text = "连续正确: %d  连续错误: %d" % [correct, wrong]

func _on_answer_processed(is_correct: bool):
	hint_label.text = "✓ 正确" if is_correct else "✗ 错误"
	hint_label.modulate = Color(0.4, 1.0, 0.4) if is_correct else Color(1.0, 0.4, 0.4)
	_answer_feedback_timer = 0.6

# ── 快捷键 ───────────────────────────────────────────────
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
	# ESC 退出专注模式
	if event.is_action_pressed("ui_cancel"):
		if not $HBoxContainer/LeftPanel.visible:
			_on_fullscreen_focus()
		return
	if is_paused:
		return
	if Input.is_action_just_pressed("answer_up"):
		_on_answer("up")
	elif Input.is_action_just_pressed("answer_down"):
		_on_answer("down")
	elif Input.is_action_just_pressed("answer_left"):
		_on_answer("left")
	elif Input.is_action_just_pressed("answer_right"):
		_on_answer("right")

func _on_answer(dir: String):
	if is_paused:
		return
	test_controller.process_answer(dir)
	_update_ui_display()

# ── 模式切换 ──────────────────────────────────────────────
func _on_mode_left():
	current_mode = "left"
	level_manager.switch_eye("left")
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("请遮挡右眼，测试左眼")

func _on_mode_right():
	current_mode = "right"
	level_manager.switch_eye("right")
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("请遮挡左眼，测试右眼")

func _on_mode_both():
	current_mode = "both"
	is_testing_left = true
	level_manager.switch_eye("left")
	test_controller.force_refresh()
	_update_ui_display()
	_set_hint("双眼依次：请先遮挡右眼，测试左眼")

func _set_hint(msg: String):
	hint_label.text = msg
	hint_label.modulate = Color(0.9, 0.8, 0.4)
	_answer_feedback_timer = 3.0

# ── 控制按钮 ──────────────────────────────────────────────
func _on_reset_test():
	level_manager.reset_current_eye()
	test_controller.force_refresh()
	_update_ui_display()
	consecutive_lbl.text = "连续正确: 0  连续错误: 0"

func _on_pause_test():
	is_paused = !is_paused
	pause_btn.text = "继续测试" if is_paused else "暂停测试"

func _on_fullscreen_focus():
	var panels = [
		$HBoxContainer/LeftPanel,
		$HBoxContainer/RightPanel,
		$BottomButtonBar
	]
	var going_focus = $HBoxContainer/LeftPanel.visible
	for node in panels:
		node.visible = !going_focus
	Input.set_mouse_mode(
		Input.MOUSE_MODE_HIDDEN if going_focus else Input.MOUSE_MODE_VISIBLE
	)

func _on_open_calibration():
	calibration_popup.popup_centered()

func _on_calibration_confirm():
	_apply_calibration()
	calibration_popup.hide()

func _on_show_result():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")
	$ResultPopup/ResultVBox/ResultLeftEye.text = "左眼视力: %.2f" % lv
	$ResultPopup/ResultVBox/ResultRightEye.text = "右眼视力: %.2f" % rv
	result_popup.popup_centered()
