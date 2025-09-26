# res://scripts/uuid.gd
static func v4() -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in range(16): b[i] = randi_range(0, 255)
	b[6] = (b[6] & 0x0F) | 0x40   # variant 10x
	b[8] = (b[8] & 0x3F) | 0x80   # version 4
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]
