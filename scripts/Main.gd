extends Control

# ── 节点引用 ────────────────────────────────────────────────
@onready var optotype_container: OptotypeContainer = \
	$HBoxContainer/CenterContainer/EyeChartArea/OptotypeContainer

@onready var left_eye_data: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/LeftEyeData
@onready var right_eye_data: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/RightEyeData
@onready var current_vision_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/CurrentVision
@onready var consecutive_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ConsecutiveInfo
@onready var distance_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/DistanceInfo
@onready var screen_lbl: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/ScreenInfo
@onready var hint_label: Label = $HBoxContainer/RightPanel/RightPanelMargin/VBoxContainer/HintLabel
@onready var pause_btn: Button = $HBoxContainer/LeftPanel/LeftPanelMargin/VBoxContainer/ControlSection/PauseBtn

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
@onready var print_btn: Button = $ResultPopup/ResultVBox/PrintBtn
@onready var print_status_lbl: Label = $ResultPopup/ResultVBox/PrintStatusLabel

# 打印机串口选择（弹窗内）
@onready var port_option: OptionButton = $ResultPopup/ResultVBox/PortHBox/PortOption
@onready var connect_btn: Button = $ResultPopup/ResultVBox/PortHBox/ConnectBtn

# ── 管理器 ──────────────────────────────────────────────────
var vision_calc: VisionCalculator
var level_manager: VisionLevelManager
var test_controller: TestController
var printer_mgr: PrinterManager # ← 新增

# ── 状态 ────────────────────────────────────────────────────
var is_paused: bool = false
var current_mode: String = "left"
var is_testing_left: bool = true
var _answer_feedback_timer: float = 0.0

# ── 初始化 ──────────────────────────────────────────────────
func _ready():
	# 快捷键必须最先注册，否则首帧 _input() 触发时 action 不存在
	_setup_shortcuts()

	vision_calc = VisionCalculator.new()
	level_manager = VisionLevelManager.new()
	test_controller = TestController.new()
	test_controller.init(level_manager, vision_calc, optotype_container)

	# 创建打印机管理器
	printer_mgr = PrinterManager.new()

	# 信号连接
	test_controller.consecutive_updated.connect(_on_consecutive_updated)
	test_controller.vision_updated.connect(_on_vision_updated)
	test_controller.answer_processed.connect(_on_answer_processed)

	# 答题按钮绑定
	up_btn.pressed.connect(func(): _on_answer("up"))
	down_btn.pressed.connect(func(): _on_answer("down"))
	left_btn.pressed.connect(func(): _on_answer("left"))
	right_btn.pressed.connect(func(): _on_answer("right"))

	# 打印相关按钮
	print_btn.pressed.connect(_on_print_result)
	connect_btn.pressed.connect(_on_toggle_port_connect)

	_load_default_calibration()
	_apply_calibration()
	_update_ui_display()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float):
	if _answer_feedback_timer > 0.0:
		_answer_feedback_timer -= delta
		if _answer_feedback_timer <= 0.0:
			hint_label.text = ""

# ── 校准 ────────────────────────────────────────────────────
func _load_default_calibration():
	var s = DisplayServer.screen_get_size()
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

func _on_vision_updated(_v: float):
	_update_ui_display()

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
	_apply_calibration()
	calibration_popup.hide()

# ── 结果弹窗 ────────────────────────────────────────────────
func _on_show_result():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")

	result_left_lbl.text = "左眼视力: %.2f" % lv
	result_right_lbl.text = "右眼视力: %.2f" % rv

	# 刷新可用串口列表
	_refresh_port_list()

	# 更新连接按钮状态
	_update_connect_btn_text()

	# 清空上次打印状态
	print_status_lbl.text = ""

	result_popup.popup_centered()

func _refresh_port_list():
	port_option.clear()
	var ports = printer_mgr.list_ports()
	if ports.is_empty():
		port_option.add_item("无可用串口")
	else:
		for p in ports:
			port_option.add_item(str(p)) # 强制转 String，防止插件返回 int

func _update_connect_btn_text():
	if printer_mgr.is_printer_connected():
		connect_btn.text = "断开"
	else:
		connect_btn.text = "连接"

# 连接 / 断开串口
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

# 执行打印
func _on_print_result():
	var lv = level_manager.get_eye_vision("left")
	var rv = level_manager.get_eye_vision("right")

	print_status_lbl.text = "正在打印..."
	print_btn.disabled = true

	printer_mgr.print_result(lv, rv)

	print_status_lbl.text = "打印完成 ✓" if printer_mgr.is_printer_connected() else "模拟打印完成（终端已输出）✓"
	print_btn.disabled = false
