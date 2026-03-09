# ability_effect.gd
class_name AbilityEffect
extends Resource

enum EffectType { 
	DAMAGE_PLAYER,       # Нанести урон игроку
	MODIFY_GEAR_STATS,   # Изменить max_ticks/tocks (временное или постоянное)
	DRAW_CARD,           # Взять карту
	ADD_T,               # Добавить T в пул
	DESTROY_GEAR,        # Уничтожить шестерню
	ROTATE_GEAR,         # Повернуть шестерню на N тиков
	CREATE_DELAYED_EFFECT # Создать отложенный эффект
}

@export var effect_type: EffectType
@export var value: int           # Например, количество урона
@export var target_selector: String = "self" # Например, "self", "source", "target", "all_enemy_gears"
# ... другие параметры
