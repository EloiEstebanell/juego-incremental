extends RefCounted
## Durable quantities. Tasks keep their input until completion; routes reserve input space.
static func fresh() -> Dictionary:
	return {"envelope_in": 0, "envelope_out": 0, "shipping_in_raw": 0, "shipping_in_enveloped": 0,
		"shipping_out_raw": 0, "shipping_out_enveloped": 0, "arrival_clock": 0.0,
		"stamp_clock": 0.0, "envelope_job": 0.0, "shipping_job": 0.0, "dispatch_clock": 0.0,
		"routes": {}, "direct_enabled": true}

static func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["envelope_in", "envelope_out", "shipping_in_raw", "shipping_in_enveloped", "shipping_out_raw", "shipping_out_enveloped"]:
		var n: Variant = data.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n != floor(n) or n < 0 or n > 100:
			return false
	for key in ["arrival_clock", "stamp_clock", "envelope_job", "shipping_job", "dispatch_clock"]:
		var n: Variant = data.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n < 0 or n > 600:
			return false
	if not data.get("direct_enabled") is bool or not data.get("routes") is Dictionary or data.routes.size() > 3:
		return false
	for key in data.routes:
		if key not in ["direct", "envelope", "shipping"]:
			return false
		var route: Variant = data.routes[key]
		if not route is Dictionary:
			return false
		for field in ["cargo", "time", "duration"]:
			var n: Variant = route.get(field)
			if not (n is float or n is int) or not is_finite(float(n)) or n < 0 or n > 600:
				return false
		if route.cargo != floor(route.cargo) or route.cargo > 30 or route.duration <= 0 or route.time > route.duration:
			return false
		if not route.get("returning") is bool or (route.returning and route.cargo != 0) or (not route.returning and route.cargo == 0):
			return false
	return true
