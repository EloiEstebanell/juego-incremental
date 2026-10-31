class_name UpgradeDefinition
extends Resource
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var icon: Texture2D
@export var effects: Array[UpgradeEffect] = []
@export_range(1, 100000000) var initial_cost: int = 300
@export_range(1.0, 10.0) var cost_growth: float = 1.8
@export_range(1, 20) var max_level: int = 5
@export var prerequisite: StringName
@export_range(0, 20) var prerequisite_level: int = 0
