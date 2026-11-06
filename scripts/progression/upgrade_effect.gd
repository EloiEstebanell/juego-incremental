class_name UpgradeEffect
extends Resource
## Values are recomputed from bases; definitions never contain purchased state.
enum Attribute { DOCUMENT_VALUE, STAMP_MULTIPLIER, STROKE_DURATION, PAPER_SPEED, ARRIVAL_TIME, STAMP_INPUT, STAMP_OUTPUT, ENVELOPE_INPUT, ENVELOPE_OUTPUT, SHIPPING_INPUT, SHIPPING_OUTPUT, CARRY, WALK_SPEED, ENVELOPES_UNLOCK, STAMP_WORKER, ENVELOPE_WORKER, SHIPPING_WORKER, ROUTE_DIRECT, ROUTE_ENVELOPE, ROUTE_SHIPPING, STAMP_WORK_TIME, ENVELOPE_TIME, SHIPPING_TIME, COURIER_SPEED, COURIER_CARRY }
enum Operation { ADD, MULTIPLY }
@export var attribute: Attribute = Attribute.DOCUMENT_VALUE
@export var operation: Operation = Operation.ADD
@export var amount: float = 100.0
