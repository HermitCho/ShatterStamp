class_name Shapes
extends RefCounted
## 부수기 모양 정의. 회전 없이 방향별 변형을 각각 별도 모양으로 둔다.

const LIST: Array = [
	{"id": "I2H", "cells": [Vector2i(0, 0), Vector2i(1, 0)]},
	{"id": "I2V", "cells": [Vector2i(0, 0), Vector2i(0, 1)]},
	{"id": "I3H", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	{"id": "I3V", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]},
	{"id": "I4H", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	{"id": "I4V", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]},
	{"id": "O", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "L_A", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "L_B", "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "L_C", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
	{"id": "L_D", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]},
	{"id": "T_UP", "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	{"id": "T_DOWN", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]},
	{"id": "S", "cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "Z", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
	{"id": "DIAG_A", "cells": [Vector2i(0, 0), Vector2i(1, 1)]},
	{"id": "DIAG_B", "cells": [Vector2i(1, 0), Vector2i(0, 1)]},
	{"id": "PLUS", "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]},
	{"id": "X", "cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)]},
]


## idx번 모양을 반환한다. 셀 좌표는 무게중심에 가장 가까운 셀이 (0,0)이 되도록 정렬된다.
static func get_shape(idx: int) -> Dictionary:
	var def: Dictionary = LIST[idx]
	return {"id": def["id"], "cells": centered(def["cells"])}


static func centered(cells: Array) -> Array:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	var centroid := sum / cells.size()
	var anchor: Vector2i = cells[0]
	var best := INF
	for c in cells:
		var d := Vector2(c).distance_squared_to(centroid)
		if d < best - 0.001:
			best = d
			anchor = c
	var out: Array = []
	for c in cells:
		out.append(c - anchor)
	return out
