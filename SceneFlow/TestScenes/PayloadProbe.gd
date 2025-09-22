extends Node

var last_payload: Variant = null

func receive_flow_payload(payload: Variant) -> void:
	last_payload = payload
