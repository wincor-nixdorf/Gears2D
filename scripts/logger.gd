# logger.gd
extends Node

enum LogLevel { DEBUG, INFO, WARNING, ERROR, PROMPT }  # Добавлен PROMPT

signal message_logged(level: LogLevel, message: String, timestamp: Dictionary)

var log_file: FileAccess
var log_file_path: String = "user://game.log"
var min_level: LogLevel = LogLevel.DEBUG

func _ready():
	if FileAccess.file_exists(log_file_path):
		log_file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
		if log_file:
			log_file.seek_end()
	else:
		log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not log_file:
		push_error("GameLogger: cannot open log file")

func _exit_tree():
	if log_file:
		log_file.close()

func debug(message: String):
	_log(LogLevel.DEBUG, message)

func info(message: String):
	_log(LogLevel.INFO, message)

func warning(message: String):
	_log(LogLevel.WARNING, message)

func error(message: String):
	_log(LogLevel.ERROR, message)

# Новый метод для подсказок
func prompt(message: String):
	_log(LogLevel.PROMPT, message)

func _log(level: LogLevel, message: String):
	if level < min_level:
		return
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp_str = "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	var level_str = LogLevel.keys()[level]
	var formatted = "[%s] [%s] %s" % [timestamp_str, level_str, message]
	print(formatted)
	if log_file:
		log_file.store_line(formatted)
		log_file.flush()
	message_logged.emit(level, message, datetime)
