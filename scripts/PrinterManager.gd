extends RefCounted
class_name PrinterManager

const CANDIDATE_CLASS_NAMES = ["GdSerial", "GDSerial", "SerialPort", "Serial"]
const BAUD_RATE = 115200

# 每次写入后的等待时间（秒）
# 如果仍然截断，适当增大；如果打印正常可以减小
const CHUNK_DELAY = 0.04

# ── ESC/POS 指令 ────────────────────────────────────────────
static func _esc_init()        -> PackedByteArray: return PackedByteArray([0x1B, 0x40])
static func _esc_feed(n: int)  -> PackedByteArray: return PackedByteArray([0x1B, 0x64, n])
static func _esc_align(a: int) -> PackedByteArray: return PackedByteArray([0x1B, 0x61, a])
static func _esc_bold(on:bool) -> PackedByteArray: return PackedByteArray([0x1B, 0x45, 1 if on else 0])
static func _esc_size(m: int)  -> PackedByteArray: return PackedByteArray([0x1D, 0x21, m])
static func _esc_cut()         -> PackedByteArray: return PackedByteArray([0x1D, 0x56, 0x00])
static func _lf()              -> PackedByteArray: return PackedByteArray([0x0A])
static func _esc_density(n1:int,n2:int,n3:int) -> PackedByteArray:
	return PackedByteArray([0x1B, 0x37, n1, n2, n3])

# ── 串口状态 ────────────────────────────────────────────────
var _serial           = null
var _port             : String     = ""
var _connected        : bool       = false
var _sim_mode         : bool       = false
var _ports_dict       : Dictionary = {}
var _method_get_ports : String     = ""
var _method_close     : String     = ""
var _method_write     : String     = ""

# 防止重复打印（协程版，用布尔标志而不是 await 来控制）
var _is_printing      : bool       = false

# ── 初始化 ──────────────────────────────────────────────────
func _init():
	for cname in CANDIDATE_CLASS_NAMES:
		if ClassDB.class_exists(cname):
			_serial = ClassDB.instantiate(cname)
			print("[Printer] 插件加载: %s" % cname)
			break
	if _serial == null:
		_sim_mode = true
		print("[Printer] 模拟模式")
		return
	for m in _serial.get_method_list():
		match m["name"]:
			"list_ports": _method_get_ports = "list_ports"
			"close":      _method_close     = "close"
			"write":      _method_write     = "write"
	_refresh_ports()

func _refresh_ports():
	if _method_get_ports.is_empty(): return
	var raw = _serial.call(_method_get_ports)
	_ports_dict.clear()
	for idx in raw:
		var item = raw[idx]
		if item is Dictionary and item.has("port_name"):
			_ports_dict[idx] = item

func list_ports() -> Array:
	if _sim_mode: return ["[SIM] COM1"]
	_refresh_ports()
	var result: Array = []
	for idx in _ports_dict:
		var p = _ports_dict[idx]["port_name"]
		if p.begins_with("/dev/tty."):
			result.append("[%d] %s" % [idx, p])
	if result.is_empty():
		for idx in _ports_dict:
			result.append("[%d] %s" % [idx, _ports_dict[idx]["port_name"]])
	return result

func connect_port(port_label: String) -> bool:
	if _sim_mode:
		_connected = true
		return true
	var real_port = _resolve_port_name(port_label)
	if real_port.begins_with("/dev/cu."):
		real_port = real_port.replace("/dev/cu.", "/dev/tty.")
	_serial.call("set_port",      real_port)
	_serial.call("set_baud_rate", BAUD_RATE)
	var ok = _serial.call("open")
	if ok:
		_connected = true
		_port = real_port
		_serial.call(_method_write, _esc_init())
		_serial.call(_method_write, PackedByteArray([0x1B, 0x52, 0x16]))
		_serial.call(_method_write, _esc_density(140, 160, 30))
		print("[Printer] 已连接: %s" % real_port)
	else:
		push_error("[Printer] 连接失败: %s" % real_port)
	return ok

func disconnect_port():
	if _serial and _connected and not _method_close.is_empty():
		_serial.call(_method_close)
	_connected = false
	_port = ""
	_is_printing = false
	print("[Printer] 已断开")

func is_printer_connected() -> bool:
	return _connected

# ── 核心打印（协程，用 await 节流，防止缓冲区溢出）───────────
# 调用方式：printer_mgr.print_result(lv, rv)
# 因为内部有 await，调用处如果需要等待完成用：
#   await printer_mgr.print_result(lv, rv)
func print_result(left_vision: float, right_vision: float):
	if _is_printing:
		print("[Printer] 上次打印未完成，请稍候")
		return
	_is_printing = true

	var lv  = "%.2f" % left_vision  if left_vision  > 0 else "--"
	var rv  = "%.2f" % right_vision if right_vision > 0 else "--"
	var now = Time.get_datetime_string_from_system(false, true)

	if _sim_mode or not _connected:
		_print_sim(lv, rv, now)
		_is_printing = false
		return

	var div = "================"

	# ── 把所有打印内容合并为一个大的 PackedByteArray ───────────
	# 关键优化：不是每行单独发送，而是按"块"分组发送
	# 每块之间 await 一下，让打印机缓冲区有时间消化
	# 块的划分依据：每个视觉区域为一块

	# 块0：初始化
	var b0 = PackedByteArray()
	b0.append_array(_esc_init())
	b0.append_array(PackedByteArray([0x1B, 0x52, 0x16]))
	b0.append_array(_esc_density(140, 160, 30))
	await _send_chunk(b0)

	# 块1：标题区
	var b1 = PackedByteArray()
	b1.append_array(_esc_align(1))
	b1.append_array(_esc_feed(1))
	b1.append_array(_esc_bold(true))
	b1.append_array(_esc_size(0x11))
	b1.append_array(_text_gb("EyeFocus"))
	b1.append_array(_lf())
	b1.append_array(_esc_size(0x00))
	b1.append_array(_esc_bold(false))
	b1.append_array(_esc_feed(1))
	b1.append_array(_text_gb("专业视力自测报告"))
	b1.append_array(_lf())
	b1.append_array(_esc_feed(1))
	await _send_chunk(b1)

	# 块2：信息区
	var b2 = PackedByteArray()
	b2.append_array(_esc_align(0))
	b2.append_array(_text_gb(div));          b2.append_array(_lf())
	b2.append_array(_text_gb("时间: " + now.substr(0, 16)));  b2.append_array(_lf())
	b2.append_array(_text_gb("标准: GB11533  距离:5m"));       b2.append_array(_lf())
	b2.append_array(_text_gb(div));          b2.append_array(_lf())
	b2.append_array(_esc_feed(1))
	await _send_chunk(b2)

	# 块3：左眼视力
	var b3 = PackedByteArray()
	b3.append_array(_esc_align(1))
	b3.append_array(_esc_bold(true))
	b3.append_array(_esc_size(0x01))
	b3.append_array(_text_gb("左眼视力")); b3.append_array(_lf())
	b3.append_array(_esc_size(0x11))
	b3.append_array(_text_gb(lv));         b3.append_array(_lf())
	await _send_chunk(b3)

	# 块4：右眼视力
	var b4 = PackedByteArray()
	b4.append_array(_esc_size(0x01))
	b4.append_array(_text_gb("右眼视力")); b4.append_array(_lf())
	b4.append_array(_esc_size(0x11))
	b4.append_array(_text_gb(rv));         b4.append_array(_lf())
	b4.append_array(_esc_size(0x00))
	b4.append_array(_esc_bold(false))
	b4.append_array(_esc_feed(1))
	await _send_chunk(b4)

	# 块5：参考区间 + 免责
	var b5 = PackedByteArray()
	b5.append_array(_esc_align(0))
	b5.append_array(_text_gb(div));        b5.append_array(_lf())
	b5.append_array(_text_gb("正常视力 >= 1.0")); b5.append_array(_lf())
	b5.append_array(_text_gb(_advice_text(left_vision, right_vision))); b5.append_array(_lf())
	b5.append_array(_text_gb(div));        b5.append_array(_lf())
	b5.append_array(_esc_feed(1))
	b5.append_array(_esc_align(1))
	b5.append_array(_text_gb("仅供参考")); b5.append_array(_lf())
	b5.append_array(_text_gb("如有异常请就医")); b5.append_array(_lf())
	await _send_chunk(b5)

	# 块6：走纸 + 切纸
	var b6 = PackedByteArray()
	b6.append_array(_esc_feed(3))
	b6.append_array(_esc_cut())
	await _send_chunk(b6)

	print("[Printer] 打印完成")
	_is_printing = false

# ── 发送一个数据块，然后等待 CHUNK_DELAY 秒 ─────────────────
# 这是解决缓冲区溢出的核心函数
func _send_chunk(data: PackedByteArray):
	if not _connected or _method_write.is_empty():
		return
	_serial.call(_method_write, data)
	await Engine.get_main_loop().create_timer(CHUNK_DELAY).timeout

# ── 建议文本 ────────────────────────────────────────────────
func _advice_text(lv: float, rv: float) -> String:
	var worst = 9.9
	if lv > 0: worst = min(worst, lv)
	if rv > 0: worst = min(worst, rv)
	if worst >= 9.9:   return "数据不足"
	elif worst >= 1.0: return "视力正常 定期复查"
	elif worst >= 0.6: return "轻度下降 注意用眼"
	elif worst >= 0.3: return "中度下降 建议就诊"
	else:              return "明显下降 尽快就医"

# ── 模拟打印 ────────────────────────────────────────────────
func _print_sim(lv: String, rv: String, now: String):
	print("")
	print("        EyeFocus")
	print("     专业视力自测报告")
	print("================")
	print("时间: " + now.substr(0, 16))
	print("标准: GB11533  距离:5m")
	print("================")
	print("左眼视力: " + lv)
	print("右眼视力: " + rv)
	print("================")
	print("正常视力 >= 1.0")
	print("================")
	print("     仅供参考")
	print("  如有异常请就医")
	print("")

# ── GBK 编码（返回字节数组，不自动加换行）───────────────────
func _text_gb(text: String) -> PackedByteArray:
	const GBK = {
		"视":[0xCA,0xD3],"力":[0xC1,0xA6],"自":[0xD7,0xD4],
		"测":[0xB2,0xE2],"报":[0xB1,0xA8],"告":[0xB8,0xE6],
		"时":[0xCA,0xB1],"间":[0xBC,0xE4],"左":[0xD7,0xF3],
		"右":[0xD3,0xD2],"眼":[0xD1,0xDB],"参":[0xB2,0xCE],
		"考":[0xBF,0xBC],"正":[0xD5,0xFD],"常":[0xB3,0xA3],
		"建":[0xBD,0xA8],"议":[0xD2,0xE9],"定":[0xB6,0xA8],
		"期":[0xC6,0xDA],"复":[0xB8,0xB4],"查":[0xB2,0xE9],
		"本":[0xB1,0xBE],"仅":[0xBD,0xF6],"供":[0xB9,0xA9],
		"如":[0xC8,0xE7],"有":[0xD3,0xD0],"异":[0xD2,0xEC],
		"请":[0xC7,0xEB],"到":[0xB5,0xBD],"医":[0xD2,0xBD],
		"院":[0xD4,0xBA],"专":[0xD7,0xA8],"业":[0xD2,0xB5],
		"格":[0xB8,0xF1],"标":[0xB1,0xEA],"准":[0xD7,0xBC],
		"距":[0xBE,0xE0],"离":[0xC0,0xEB],
		"试":[0xCA,0xD4],"轻":[0xC7,0xE1],"度":[0xB6,0xC8],
		"下":[0xCF,0xC2],"降":[0xBD,0xB5],"注":[0xD7,0xA2],
		"意":[0xD2,0xE2],"用":[0xD3,0xC3],"中":[0xD6,0xD0],
		"足":[0xD7,0xE3],"数":[0xCA,0xFD],"据":[0xBE,0xDD],
		"不":[0xB2,0xBB],"明":[0xC3,0xF7],"显":[0xCF,0xD4],
		"快":[0xBF,0xEC],"就":[0xBE,0xCD],"尽":[0xBD,0xC9],
		"需":[0xD0,0xE8],
	}
	var bytes = PackedByteArray()
	for c in text:
		var code = c.unicode_at(0)
		if code < 128:
			bytes.append(code)
		elif GBK.has(c):
			bytes.append_array(GBK[c])
		else:
			bytes.append(0x3F)
	return bytes

func _resolve_port_name(label: String) -> String:
	var regex = RegEx.new()
	regex.compile("^\\[(\\d+)\\]")
	var m = regex.search(label)
	if m:
		var idx = int(m.get_string(1))
		if _ports_dict.has(idx):
			return _ports_dict[idx]["port_name"]
	return label
