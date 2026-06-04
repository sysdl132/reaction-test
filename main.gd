extends Node2D

# 全局数据（最高分、分数、速度、游戏状态）
var high_score = 0
var score = 0
var max_speed = 0.0
var game_running = false
var start_time = 0.0
var correct_presses = 0

# 引用界面节点
@onready var start_menu = $StartMenu
@onready var game_ui = $GameUI
@onready var game_over_ui = $GameOverUI
@onready var game_area = $GameUI/GameArea

# 方块队列（最多存6个：当前1个 + 预览5个）
var block_queue = []
const QUEUE_LENGTH = 6
# 掉落速度
const FALL_SPEED = 120.0

# 方向映射：键名 → 显示字符
const DIR_MAP = {
	"up": "↑",
	"down": "↓",
	"left": "←",
	"right": "→"
}

func _ready():
	# 启动时加载本地存储的最高分
	load_high_score()
	update_start_ui()
	# 预先生成方块队列
	fill_block_queue()


# ====================== 界面切换 ======================
func start_game():
	# 重置游戏数据
	score = 0
	max_speed = 0.0
	correct_presses = 0
	game_running = true
	start_time = Time.get_ticks_msec() / 1000.0
	
	# 清空旧方块
	clear_all_blocks()
	fill_block_queue()
	
	# 切换界面
	start_menu.visible = false
	game_ui.visible = true
	game_over_ui.visible = false
	update_game_ui()


func game_over():
	game_running = false
	# 计算最终速度
	var game_time = Time.get_ticks_msec() / 1000.0 - start_time
	if game_time > 0 and correct_presses > 0:
		max_speed = correct_presses / game_time
	
	# 更新最高分
	var is_new_record = false
	if score > high_score:
		high_score = score
		save_high_score()
		is_new_record = true
	
	# 显示结束界面
	game_over_ui.get_node("FinalScore").text = "得分：%d" % score
	game_over_ui.get_node("FinalSpeed").text = "最快速度：%.2f 次/秒" % max_speed
	game_over_ui.get_node("BestScore").text = "历史最高分：%d" % high_score
	game_over_ui.get_node("NewRecord").visible = is_new_record
	
	game_ui.visible = false
	game_over_ui.visible = true


func back_to_menu():
	# 返回主页
	game_over_ui.visible = false
	start_menu.visible = true
	update_start_ui()


# ====================== 方块系统 ======================
func fill_block_queue():
	# 填满队列（保证始终有 1个掉落 + 5个预览）
	while block_queue.size() < QUEUE_LENGTH:
		var dirs = ["up", "down", "left", "right"]
		var random_dir = dirs[randi() % 4]
		block_queue.append(random_dir)
	update_block_positions()


func update_block_positions():
	# 清空旧方块
	clear_all_blocks()
	var area_w = game_area.size.x
	var area_h = game_area.size.y
	var block_w = 80
	var block_h = 80
	var start_x = (area_w - block_w) / 2
	
	# 生成所有方块
	for i in range(block_queue.size()):
		var dir = block_queue[i]
		# 创建方块
		var block = ColorRect.new()
		block.name = "Block"
		block.size = Vector2(block_w, block_h)
		block.position = Vector2(start_x, 10 + i * 100)
		block.color = Color(0.2, 0.6, 1)
		game_area.add_child(block)
		
		# 添加方向文字
		var label = Label.new()
		label.text = DIR_MAP[dir]
		label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(block_w, block_h)
		label.add_theme_font_size_override("font_size", 48)
		block.add_child(label)


func clear_all_blocks():
	# 删除所有方块
	for child in game_area.get_children():
		child.queue_free()


func move_blocks_down(delta):
	# 方块整体下落
	if not game_running or block_queue.size() == 0:
		return
	
	var children = game_area.get_children()
	if children.size() == 0:
		return
	
	# 修复：直接取数组第一个，不用 get_child_or_null
	var first_block = children[0]
	if first_block.position.y + FALL_SPEED * delta < -150:
		game_over()
		return
	
	# 方块下落
	for child in children:
		child.position.y -= FALL_SPEED * delta


# ====================== 输入检测 ======================
func _input(event):
	if not game_running:
		return
	
	# 只处理方向键按下
	if not event is InputEventKey or !event.pressed or event.is_echo():
		return
	
	var key = null
	if event.keycode == KEY_UP:
		key = "up"
	elif event.keycode == KEY_DOWN:
		key = "down"
	elif event.keycode == KEY_LEFT:
		key = "left"
	elif event.keycode == KEY_RIGHT:
		key = "right"
	
	if not key:
		return
	
	# 判断按键是否正确
	var correct_dir = block_queue[0]
	print(block_queue)
	print(key)
	if key == correct_dir:
		# 正确：加分、刷新速度、刷新队列
		score += 1
		correct_presses += 1
		var game_time = Time.get_ticks_msec() / 1000.0 - start_time
		if game_time > 0:
			var current_speed = correct_presses / game_time
			if current_speed > max_speed:
				max_speed = current_speed
		
		# 移除第一个方块，刷新队列
		block_queue.remove_at(0)
		fill_block_queue()
		update_game_ui()
	else:
		# 错误：游戏结束
		game_over()


# ====================== UI 更新 ======================
func update_game_ui():
	game_ui.get_node("ScoreLabel").text = "分数：%d" % score
	game_ui.get_node("SpeedLabel").text = "速度：%.2f 次/秒" % max_speed

func update_start_ui():
	start_menu.get_node("HighScoreLabel").text = "历史最高分：%d" % high_score


# ====================== 数据存储 ======================
func save_high_score():
	var file = FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()

func load_high_score():
	if FileAccess.file_exists("user://highscore.dat"):
		var file = FileAccess.open("user://highscore.dat", FileAccess.READ)
		high_score = file.get_32()
		file.close()
	else:
		high_score = 0


# ====================== 游戏循环 ======================
func _process(delta):
	move_blocks_down(delta)


func _on_start_button_pressed() -> void:
	#pass # Replace with function body.
	start_game()


func _on_back_button_pressed() -> void:
	#pass # Replace with function body.
	back_to_menu()
