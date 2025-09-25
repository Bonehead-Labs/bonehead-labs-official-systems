extends "res://addons/gut/test.gd"

## Test health system consolidation and EventBus integration

var health_component: HealthComponent
var damage_info: DamageInfo
var event_bus: Node

class EventBusStub extends Node:
    var published_events: Array[Dictionary] = []
    
    func pub(topic: StringName, payload: Dictionary) -> void:
        published_events.append({"topic": topic, "payload": payload})

func before_each() -> void:
    health_component = HealthComponent.new()
    health_component.name = "TestHealthComponent"
    damage_info = DamageInfo.new()
    event_bus = EventBusStub.new()
    event_bus.name = "EventBus"
    
    get_tree().root.add_child(health_component)
    get_tree().root.add_child(event_bus)
    
    # Set up damage info
    damage_info.amount = 25.0
    damage_info.type = DamageInfo.DamageType.PHYSICAL

func after_each() -> void:
    if is_instance_valid(event_bus):
        event_bus.queue_free()
    if is_instance_valid(health_component):
        health_component.queue_free()

func test_damage_emits_combat_hit_event() -> void:
    """Test that damage emits COMBAT_HIT event to EventBus."""
    health_component.take_damage(damage_info)
    
    # Check that EventBus received the event
    var combat_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HIT)
    assert_eq(combat_events.size(), 1, "Should emit one COMBAT_HIT event")
    
    var event_payload = combat_events[0].payload
    assert_eq(event_payload["amount"], 25.0, "Event should contain correct damage amount")
    assert_eq(event_payload["target"], health_component.get_parent(), "Event should contain target entity")
    assert_eq(event_payload["type"], "PHYSICAL", "Event should contain damage type")

func test_heal_emits_combat_heal_event() -> void:
    """Test that healing emits COMBAT_HEAL event to EventBus."""
    var heal_info = DamageInfo.create_healing(15.0)
    health_component.heal(heal_info)
    
    # Check that EventBus received the event
    var heal_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HEAL)
    assert_eq(heal_events.size(), 1, "Should emit one COMBAT_HEAL event")
    
    var event_payload = heal_events[0].payload
    assert_eq(event_payload["amount"], 15.0, "Event should contain correct heal amount")
    assert_eq(event_payload["target"], health_component.get_parent(), "Event should contain target entity")

func test_death_emits_combat_entity_death_event() -> void:
    """Test that death emits COMBAT_ENTITY_DEATH event to EventBus."""
    # Deal enough damage to kill the entity
    damage_info.amount = 150.0
    health_component.take_damage(damage_info)
    
    # Check that EventBus received the death event
    var death_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_ENTITY_DEATH)
    assert_eq(death_events.size(), 1, "Should emit one COMBAT_ENTITY_DEATH event")
    
    var event_payload = death_events[0].payload
    assert_eq(event_payload["target"], health_component.get_parent(), "Event should contain target entity")
    assert_eq(event_payload["amount"], 0.0, "Death event should have zero amount")

func test_invulnerability_blocks_damage_but_emits_event() -> void:
    """Test that invulnerability blocks damage but still emits event."""
    health_component.set_invulnerable(true, 1.0)
    
    var initial_health = health_component.get_health()
    health_component.take_damage(damage_info)
    
    # Health should not change
    assert_eq(health_component.get_health(), initial_health, "Health should not change when invulnerable")
    
    # But event should still be emitted
    var combat_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HIT)
    assert_eq(combat_events.size(), 1, "Should still emit COMBAT_HIT event even when invulnerable")

func test_true_damage_bypasses_invulnerability() -> void:
    """Test that TRUE damage type bypasses invulnerability."""
    health_component.set_invulnerable(true, 1.0)
    damage_info.type = DamageInfo.DamageType.TRUE
    
    var initial_health = health_component.get_health()
    health_component.take_damage(damage_info)
    
    # Health should change even when invulnerable
    assert_lt(health_component.get_health(), initial_health, "TRUE damage should bypass invulnerability")
    
    # Event should be emitted
    var combat_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HIT)
    assert_eq(combat_events.size(), 1, "Should emit COMBAT_HIT event for TRUE damage")

func test_event_payload_contains_entity_info() -> void:
    """Test that event payloads contain proper entity information."""
    health_component.take_damage(damage_info)
    
    var combat_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HIT)
    var event_payload = combat_events[0].payload
    
    # Check entity information
    assert_not_null(event_payload["target"], "Event should contain target entity")
    assert_has(event_payload, "entity_name", "Event should contain entity name")
    assert_has(event_payload, "entity_type", "Event should contain entity type")
    assert_has(event_payload, "position", "Event should contain entity position")
    assert_has(event_payload, "timestamp_ms", "Event should contain timestamp")

func test_multiple_damage_events() -> void:
    """Test that multiple damage events are properly emitted."""
    health_component.take_damage(damage_info)
    
    var second_damage = DamageInfo.new()
    second_damage.amount = 10.0
    second_damage.type = DamageInfo.DamageType.FIRE
    health_component.take_damage(second_damage)
    
    # Should have two COMBAT_HIT events
    var combat_events = event_bus.published_events.filter(func(e): return e.topic == EventTopics.COMBAT_HIT)
    assert_eq(combat_events.size(), 2, "Should emit two COMBAT_HIT events")
    
    # Check that events have different damage types
    var types = combat_events.map(func(e): return e.payload["type"])
    assert_has(types, "PHYSICAL", "Should have PHYSICAL damage event")
    assert_has(types, "FIRE", "Should have FIRE damage event")
