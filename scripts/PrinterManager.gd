extends RefCounted
class_name PrinterManager

const CANDIDATE_CLASS_NAMES = ["GdSerial", "GDSerial", "SerialPort", "Serial"]
const BAUD_RATE = 115200
const WRITE_DELAY = 0.01

# ── ESC/POS ─────────────────────
static func _esc_init() -> PackedByteArray:
	return PackedByteArray([0x1B, 0x40])
static func _esc_feed(n: int) -> PackedByteArray:
	return PackedByteArray([0x1B, 0x64, n])
static func _esc_align(a: int) -> PackedByteArray:
	return PackedByteArray([0x1B, 0x61, a])
static func _esc_bold(on: bool) -> PackedByteArray:
	return PackedByteArray([0x1B, 0x45, 1 if on else 0])
static func _esc_size(m: int) -> PackedByteArray:
	return PackedByteArray([0x1D, 0x21, m])
static func _esc_cut() -> PackedByteArray:
	return PackedByteArray([0x1D, 0x56, 0x00])
static func _lf() -> PackedByteArray:
	return PackedByteArray([0x0A])

# ── 串口 ────────────────────────
var _serial = null
var _port: String = ""
var _connected: bool = false
var _sim_mode: bool = false
var _ports_dict: Dictionary = {}

var _method_get_ports: String = ""
var _method_close: String = ""
var _method_write: String = ""

var _is_printing: bool = false

# ────────────────────────────────
func _init():
	for cname in CANDIDATE_CLASS_NAMES:
		if ClassDB.class_exists(cname):
			_serial = ClassDB.instantiate(cname)
			break

	if _serial == null:
		_sim_mode = true
		return

	for m in _serial.get_method_list():
		var n = m["name"]
		if n == "list_ports":
			_method_get_ports = n
		elif n == "close":
			_method_close = n
		elif n == "write":
			_method_write = n

	_refresh_ports()

func _refresh_ports():
	var raw = _serial.call(_method_get_ports)
	_ports_dict.clear()
	for idx in raw:
		var item = raw[idx]
		if item is Dictionary and item.has("port_name"):
			_ports_dict[idx] = item

# ✅ 端口去重（基于端口名）
func list_ports() -> Array:
	if _sim_mode:
		return ["[SIM] COM1"]

	_refresh_ports()
	var seen = {}
	var result = []
	for idx in _ports_dict:
		var p = _ports_dict[idx]["port_name"]
		if not seen.has(p):
			seen[p] = true
			result.append("[%d] %s" % [idx, p])
	return result

# ────────────────────────────────
func connect_port(port_label: String) -> bool:
	if _sim_mode:
		_connected = true
		return true

	var real_port = _resolve_port_name(port_label)
	if real_port.begins_with("/dev/cu."):
		real_port = real_port.replace("/dev/cu.", "/dev/tty.")

	_serial.call("set_port", real_port)
	_serial.call("set_baud_rate", BAUD_RATE)
	var ok = _serial.call("open")

	if ok:
		_connected = true
		_port = real_port
		_put_bytes(_esc_init())
	return ok

func disconnect_port():
	if _serial and _connected:
		_serial.call(_method_close)
	_connected = false

func is_printer_connected() -> bool:
	return _connected

# ────────────────────────────────
# ✅ 打印报告（去除边框，保留中文）
# ────────────────────────────────
func print_result(left_vision: float, right_vision: float):
	if _is_printing:
		print("[Printer] 正在打印中")
		return

	_is_printing = true

	var lv = "%.2f" % left_vision if left_vision > 0 else "--"
	var rv = "%.2f" % right_vision if right_vision > 0 else "--"
	var now = Time.get_datetime_string_from_system(false, true)

	if _sim_mode or not _connected:
		_print_sim(lv, rv, now)
		_is_printing = false
		return

	# 初始化 + 设置 GB18030 中文编码
	_put_bytes(_esc_init())
	_put_bytes(PackedByteArray([0x1B, 0x52, 0x16]))

	_put_bytes(_esc_align(0))

	var lines = []
	lines.append("EyeFocus")
	lines.append("专业视力自测报告")
	lines.append("----------------------------------------")
	lines.append("测试时间: " + now)
	lines.append("测试标准: GB 11533  距离: 5m")
	lines.append("----------------------------------------")
	lines.append("")
	lines.append("左眼视力: " + lv)
	lines.append("右眼视力: " + rv)
	lines.append("")
	lines.append("----------------------------------------")
	lines.append("参考区间  正常视力 >= 1.0")
	lines.append("视力正常，建议定期复查")   # 可根据实际视力动态替换
	lines.append("----------------------------------------")
	lines.append("本报告仅供参考")
	lines.append("如有异常请到医院就诊")
	lines.append("----------------------------------------")

	for line in lines:
		_put_text_gb(line)

	_put_bytes(_esc_feed(3))
	_put_bytes(_esc_cut())

	await Engine.get_main_loop().create_timer(1.5).timeout
	_is_printing = false

# ────────────────────────────────
# ✅ 中文 GB18030 编码发送
# ────────────────────────────────
func _put_text_gb(text: String):
	var bytes = PackedByteArray()
	for c in text:
		var code = c.unicode_at(0)
		if code < 128:
			bytes.append(code)
		else:
			match c:
				"视": bytes.append_array([0xCA,0xD3])
				"力": bytes.append_array([0xC1,0xA6])
				"自": bytes.append_array([0xD7,0xD4])
				"测": bytes.append_array([0xB2,0xE2])
				"报": bytes.append_array([0xB1,0xA8])
				"告": bytes.append_array([0xB8,0xE6])
				"时": bytes.append_array([0xCA,0xB1])
				"间": bytes.append_array([0xBC,0xE4])
				"左": bytes.append_array([0xD7,0xF3])
				"右": bytes.append_array([0xD3,0xD2])
				"眼": bytes.append_array([0xD1,0xDB])
				"参": bytes.append_array([0xB2,0xCE])
				"考": bytes.append_array([0xBF,0xBC])
				"正": bytes.append_array([0xD5,0xFD])
				"常": bytes.append_array([0xB3,0xA3])
				"建": bytes.append_array([0xBD,0xA8])
				"议": bytes.append_array([0xD2,0xE9])
				"定": bytes.append_array([0xB6,0xA8])
				"期": bytes.append_array([0xC6,0xDA])
				"复": bytes.append_array([0xB8,0xB4])
				"查": bytes.append_array([0xB2,0xE9])
				"本": bytes.append_array([0xB1,0xBE])
				"仅": bytes.append_array([0xBD,0xF6])
				"供": bytes.append_array([0xB9,0xA9])
				"如": bytes.append_array([0xC8,0xE7])
				"有": bytes.append_array([0xD3,0xD0])
				"异": bytes.append_array([0xD2,0xEC])
				"常": bytes.append_array([0xB3,0xA3])
				"请": bytes.append_array([0xC7,0xEB])
				"到": bytes.append_array([0xB5,0xBD])
				"医": bytes.append_array([0xD2,0xBD])
				"院": bytes.append_array([0xD4,0xBA])
				"专": bytes.append_array([0xD7,0xA8])
				"业": bytes.append_array([0xD2,0xB5])
				_: bytes.append(0x20)
	_put_bytes(bytes)
	_put_bytes(_lf())

# ────────────────────────────────
# 模拟打印（控制台输出）
func _print_sim(l, r, t):
	print("\n===== 模拟打印 =====")
	print("EyeFocus")
	print("专业视力自测报告")
	print("----------------------------------------")
	print("测试时间:", t)
	print("测试标准: GB 11533  距离: 5m")
	print("----------------------------------------")
	print("左眼视力:", l)
	print("右眼视力:", r)
	print("----------------------------------------")
	print("参考区间  正常视力 >= 1.0")
	print("视力正常，建议定期复查")
	print("----------------------------------------")
	print("本报告仅供参考")
	print("如有异常请到医院就诊")
	print("----------------------------------------")

# ────────────────────────────────
func _resolve_port_name(label: String) -> String:
	var regex = RegEx.new()
	regex.compile("^\\[(\\d+)\\]")
	var m = regex.search(label)
	if m:
		var idx = int(m.get_string(1))
		if _ports_dict.has(idx):
			return _ports_dict[idx]["port_name"]
	return label

func _put_bytes(data: PackedByteArray):
	if not _connected:
		return
	_serial.call(_method_write, data)
	await Engine.get_main_loop().create_timer(WRITE_DELAY).timeout
