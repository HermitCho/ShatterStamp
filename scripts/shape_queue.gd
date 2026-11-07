class_name ShapeQueue
extends RefCounted
## "주머니 섞기"(bag) 방식 모양 큐.
## 모든 모양을 한 주머니에 넣고 섞어서 하나씩 꺼낸다. 주머니가 비면 다시 채운다.
## 같은 모양이 지나치게 반복되거나 오래 안 나오는 불운을 막는다.

var rng := RandomNumberGenerator.new()
var _bag: Array = []
var _queue: Array = []


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func peek(count: int) -> Array:
	while _queue.size() < count:
		_queue.append(_draw_one())
	return _queue.slice(0, count)


func pop() -> Dictionary:
	peek(1)
	return _queue.pop_front()


func _draw_one() -> Dictionary:
	if _bag.is_empty():
		_refill_bag()
	return Shapes.get_shape(_bag.pop_back())


func _refill_bag() -> void:
	_bag = range(Shapes.LIST.size())
	# Fisher-Yates (시드 재현을 위해 전용 rng 사용)
	for i in range(_bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = tmp
