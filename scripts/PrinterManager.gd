extends RefCounted
class_name PrinterManager

# ── EM5820H 热敏打印机串口管理器 ────────────────────────────
# 依赖：GdSerial 插件（已导入项目）
# 无实物 / 无插件时：自动切换模拟模式，结果输出到终端

const BAUD_RATE = 9600

# ── ESC/POS 指令（PackedByteArray，避免字符串转义问题）────────
static func _esc_init() -> PackedByteArray: return PackedByteArray([0x1B, 0x40])
static func _esc_feed(n: int) -> PackedByteArray: return PackedByteArray([0x1B, 0x64, n])
static func _esc_align(a: int) -> PackedByteArray: return PackedByteArray([0x1B, 0x61, a]) # 0=左 1=居中 2=右
static func _esc_bold(on: bool) -> PackedByteArray: return PackedByteArray([0x1B, 0x45, 1 if on else 0])
static func _esc_size(mode: int) -> PackedByteArray: return PackedByteArray([0x1D, 0x21, mode])
# size mode: 0x00=正常  0x01=双倍高  0x11=双倍宽+高
static func _esc_cut() -> PackedByteArray: return PackedByteArray([0x1D, 0x56, 0x00])
static func _lf() -> PackedByteArray: return PackedByteArray([0x0A])

# ── 内部状态 ────────────────────────────────────────────────
var _serial = null
var _port: String = ""
var _connected: bool = false
var _sim_mode: bool = false

func _init():
	if ClassDB.class_exists("GDSerial"):
		_serial = ClassDB.instantiate("GDSerial")
		print("[PrinterManager] GdSerial 已加载")
	else:
		_sim_mode = true
		print("[PrinterManager] 未找到 GdSerial，启用模拟打印模式")

# ── 公开接口 ────────────────────────────────────────────────

func list_ports() -> Array:
	if _sim_mode or _serial == null:
		return ["SIM_COM1", "SIM_COM2"]
	return _serial.get_ports()

func connect_port(port_name: String) -> bool:
	if _sim_mode:
		_port = port_name
		_connected = true
		print("[PrinterManager] 模拟连接: %s" % port_name)
		return true
	if _serial == null:
		return false
	var ok = _serial.open(port_name, BAUD_RATE)
	if ok:
		_port = port_name
		_connected = true
		_send(_esc_init())
		print("[PrinterManager] 已连接: %s" % port_name)
	else:
		push_error("[PrinterManager] 连接失败: %s" % port_name)
	return ok

func disconnect_port():
	if not _sim_mode and _serial != null and _connected:
		_serial.close()
	_connected = false
	_port = ""
	print("[PrinterManager] 已断开")

func is_printer_connected() -> bool:
	return _connected

# ── 核心：打印视力结果 ──────────────────────────────────────
func print_result(left_vision: float, right_vision: float):
	var left_str = "%.2f" % left_vision if left_vision > 0 else "--"
	var right_str = "%.2f" % right_vision if right_vision > 0 else "--"
	var now = Time.get_datetime_string_from_system(false, true)

	# 无实物 / 未连接 → 终端模拟
	if _sim_mode or not _connected:
		_simulate_print(left_str, right_str, now)
		return

	# ── 真实打印 ────────────────────────────────────────────
	_send(_esc_init())
	_send(_esc_feed(1))

	# 标题
	_send(_esc_align(1)) # 居中
	_send(_esc_size(0x11)) # 双倍宽高
	_send(_esc_bold(true))
	_send_text("EyeFocus")
	_send(_lf())
	_send(_esc_size(0x00))
	_send(_esc_bold(false))
	_send_text("专业视力自测报告")
	_send(_lf())
	_send(_esc_feed(1))

	# 分割线
	_send(_esc_align(0))
	_send_text("================================")
	_send(_lf())

	# 时间与标准
	_send_text("测试时间: " + now)
	_send(_lf())
	_send_text("测试标准: GB 11533  距离: 5m")
	_send(_lf())
	_send_text("================================")
	_send(_lf())
	_send(_esc_feed(1))

	# 视力数据
	_send(_esc_align(1))
	_send(_esc_size(0x01)) # 双倍高
	_send(_esc_bold(true))
	_send_text("左眼视力")
	_send(_lf())
	_send(_esc_size(0x11))
	_send_text(left_str)
	_send(_lf())
	_send(_esc_size(0x01))
	_send_text("右眼视力")
	_send(_lf())
	_send(_esc_size(0x11))
	_send_text(right_str)
	_send(_lf())
	_send(_esc_size(0x00))
	_send(_esc_bold(false))
	_send(_esc_feed(1))

	# 参考区间
	_send(_esc_align(0))
	_send_text("================================")
	_send(_lf())
	_send_text("参考区间  正常视力 >= 1.0")
	_send(_lf())
	for line in _get_advice(left_vision, right_vision):
		_send_text(line)
		_send(_lf())
	_send_text("================================")
	_send(_lf())
	_send(_esc_feed(1))

	# 免责声明
	_send(_esc_align(1))
	_send_text("本报告仅供参考，如有异常请就诊")
	_send(_lf())
	_send(_esc_feed(3))
	_send(_esc_cut())

	print("[PrinterManager] 打印完成")

# ── 私有：终端模拟打印 ───────────────────────────────────────

func _simulate_print(left_str: String, right_str: String, now: String):
	var advice = _get_advice(
		float(left_str) if left_str != "--" else -1.0,
		float(right_str) if right_str != "--" else -1.0
	)
	print("")
	print("╔══════════════════════════════════╗")
	print("║           EyeFocus               ")
	print("║        专业视力自测报告           ")
	print("║  ================================ ")
	print("║  测试时间: " + now)
	print("║  测试标准: GB 11533  距离: 5m    ")
	print("║  ================================ ")
	print("║                                   ")
	print("║    左眼视力          右眼视力     ")
	print("║      %s              %s" % [left_str, right_str])
	print("║                                   ")
	print("║  ================================ ")
	print("║  参考区间  正常视力 >= 1.0        ")
	for line in advice:
		print("║  " + line)
	print("║  ================================ ")
	print("║      本报告仅供参考               ")
	print("║    如有异常请到医院就诊            ")
	print("╚══════════════════════════════════╝")
	print("")

func _get_advice(lv: float, rv: float) -> Array:
	var worst = 9.9
	if lv > 0: worst = min(worst, lv)
	if rv > 0: worst = min(worst, rv)
	if worst >= 9.9:
		return ["暂无足够数据"]
	elif worst >= 1.0:
		return ["视力正常，建议定期复查"]
	elif worst >= 0.6:
		return ["视力轻度下降，建议关注"]
	elif worst >= 0.3:
		return ["视力中度下降，建议及时就诊"]
	else:
		return ["视力明显下降，请尽快到医院就诊"]

# ── 私有：串口发送 ───────────────────────────────────────────

func _send(data: PackedByteArray):
	if _serial == null or not _connected:
		return
	_serial.put_data(data)

func _send_text(text: String):
	if _serial == null or not _connected:
		return
	# EM5820H 支持 UTF-8；若乱码请在此处做 GBK 转码
	_serial.put_data(text.to_utf8_buffer())
	_serial.put_data(_lf())
