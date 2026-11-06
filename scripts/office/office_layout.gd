extends RefCounted
## Office coordinates are metres; desk interaction uses its original close-up coordinates.
const DESK_SCALE := 0.2
const DESK_ORIGIN := Vector3(0, -0.30, 0)
const SPAWN := Vector3(0, -1.04, 1.45)
const ANCHORS := {"desk": Vector3(-0.25, 0, 1.1), "pickup": Vector3(0.75, 0, 1.1), "envelopes": Vector3(3, 0, -1.7), "shipping": Vector3(-3, 0, -1.7)}
const PICKUP := Vector3(0.75, -1.04, 1.15)
const ENVELOPES := Vector3(3, -1.04, -1.7)
const SHIPPING := Vector3(-3, -1.04, -1.7)
