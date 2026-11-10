class_name Shapes
extends RefCounted
## 부수기 모양 정의. 회전 없이 방향별 변형을 각각 별도 모양으로 둔다.

## 모든 모양은 가로·세로 칸 수가 홀수(1·3·5)이고 정가운데 칸을 포함한다.
## → 마우스가 가리키는 칸이 항상 모양의 정중앙이 되어, 어디에 찍힐지 헷갈리지 않는다.
## 좌표는 정가운데를 (0,0)으로 적는다.
const LIST: Array = [
	{"id": "I3H", "cells": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]},
	{"id": "I3V", "cells": [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)]},
	{"id": "I5H", "cells": [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	{"id": "I5V", "cells": [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]},
	{"id": "DIAG_A", "cells": [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(1, 1)]},
	{"id": "DIAG_B", "cells": [Vector2i(1, -1), Vector2i(0, 0), Vector2i(-1, 1)]},
	{"id": "PLUS", "cells": [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
	{"id": "X", "cells": [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, 1)]},
	# 큰 T: 한 줄 3칸 + 가운데 기둥
	{"id": "T_DOWN", "cells": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(0, 1)]},
	{"id": "T_UP", "cells": [Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "T_RIGHT", "cells": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 0), Vector2i(1, 0)]},
	{"id": "T_LEFT", "cells": [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(-1, 0)]},
	# 3x3 안의 S / Z (세로·가로)
	{"id": "S_V", "cells": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "Z_V", "cells": [Vector2i(1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 1)]},
	{"id": "S_H", "cells": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]},
	{"id": "Z_H", "cells": [Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1)]},
]


## idx번 모양을 반환한다. 셀 좌표는 모양을 감싸는 상자의 정가운데가 (0,0)이 되도록 맞춘다.
static func get_shape(idx: int) -> Dictionary:
	var def: Dictionary = LIST[idx]
	return {"id": def["id"], "cells": centered(def["cells"])}


static func centered(cells: Array) -> Array:
	var mn: Vector2i = cells[0]
	var mx: Vector2i = cells[0]
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var center := Vector2i((mn.x + mx.x) / 2, (mn.y + mx.y) / 2)
	var out: Array = []
	for c in cells:
		out.append(c - center)
	return out
