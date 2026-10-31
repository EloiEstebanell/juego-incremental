class_name UpgradeEffect
extends Resource
## Values are recomputed from bases; definitions never contain purchased state.
enum Attribute { DOCUMENT_VALUE, STAMP_MULTIPLIER, STROKE_DURATION, PAPER_SPEED }
enum Operation { ADD, MULTIPLY }
@export var attribute: Attribute = Attribute.DOCUMENT_VALUE
@export var operation: Operation = Operation.ADD
@export var amount: float = 100.0
