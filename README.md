# Bonehead Labs Official Systems

<div align="center">
  <img src="icon.svg" alt="BHL Systems Icon" width="64" height="64"/>
  <img src="image.png" alt="BHL Systems Image" width="64" height="64"/>
</div>

<div align="center">
<pre>
 ____  _   _ _                     ____            _                     
| __ )| | | | |                   / ___| _   _ ___| |_ ___ _ __ ___  ___ 
|  _ \| |_| | |         _____     \___ \| | | / __| __/ _ \ '_ ` _ \/ __|
| |_) |  _  | |___     |_____|     ___) | |_| \__ \ ||  __/ | | | | \__ \
|____/|_| |_|_____|               |____/ \__, |___/\__\___|_| |_| |_|___/
                                         |___/                           
</pre>
</div>

<div align="center">

**A comprehensive collection of plug-and-play game systems for Godot 4.5**

*Designed for developers of all skill levels with emphasis on human readability and reliability*

[![Godot](https://img.shields.io/badge/Godot-4.5+-blue.svg)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/Documentation-Complete-brightgreen.svg)](docs/)

</div>

---

## 🎯 Purpose

Bonehead Labs Official Systems provides a robust foundation of interconnected game systems that can be easily integrated into new or existing Godot projects. Each system is designed to be:

- **Modular**: Use only what you need, when you need it
- **Well-Documented**: Comprehensive documentation with examples
- **Tested**: Unit tests for all public functionality
- **Performant**: Optimized for real-time game performance
- **Extensible**: Easy to customize and extend for your specific needs

## 🚀 Quick Start

### For New Godot Projects

1. **Clone or Download** this repository into your project's root directory
2. **Configure Autoloads** in Project Settings → Autoload:
   ```
   EventBus → res://EventBus/EventBus.gd
   SaveService → res://SaveService/SaveService.gd
   EventTopics → res://EventBus/EventTopics.gd
   InputConfig → res://InputService/InputConfig.gd
   InputService → res://InputService/InputService.gd
   ```
3. **Start Building** - Each system is ready to use immediately!

### For Existing Godot Projects

1. **Copy Desired Systems** - Copy only the modules you need into your project
2. **Update Autoloads** - Add the required autoloads for your chosen systems
3. **Configure Integration** - Follow each system's README for specific setup instructions
4. **Test Integration** - Run the included unit tests to verify everything works

## 📦 Available Systems

### Core Services

| System | Description | README |
|--------|-------------|--------|
| **AudioService** | Comprehensive audio management with buses, pooling, and crossfade | [📖 AudioService/README.md](AudioService/README.md) |
| **EventBus** | Decoupled event communication system with topic-based routing | [📖 EventBus/README.md](EventBus/README.md) |
| **InputService** | Centralized input handling with rebinding and device management | [📖 InputService/InputServiceBreakdown.md](InputService/InputServiceBreakdown.md) |
| **SaveService** | Robust save/load system with profiles and checkpoints | [📖 SaveService/README.md](SaveService/README.md) |

### Gameplay Systems

| System | Description | README |
|--------|-------------|--------|
| **Combat** | Health, damage, hitboxes, status effects, and faction management | [📖 Combat/README.md](Combat/README.md) |
| **PlayerController** | 2D character controller with state machine and abilities | [📖 PlayerController/README.md](PlayerController/README.md) |
| **EnemyAI** | AI framework with states, attacks, and spawning systems | [📖 EnemyAI/README.md](EnemyAI/README.md) |
| **ItemsEconomy** | Inventory, crafting, shops, and economic systems | [📖 ItemsEconomy/README.md](ItemsEconomy/README.md) |

### World & Environment

| System | Description | README |
|--------|-------------|--------|
| **World** | Checkpoints, interactables, hazards, and world management | [📖 World/README.md](World/README.md) |
| **SceneFlow** | Scene management with transitions and loading screens | [📖 SceneFlow/README.md](SceneFlow/README.md) |

### User Interface

| System | Description | README |
|--------|-------------|--------|
| **UI** | Screen management, theming, widgets, and input rebinding | [📖 UI/README.md](UI/README.md) |

### Development Tools

| System | Description | README |
|--------|-------------|--------|
| **Debug** | Debug console, performance overlay, and development utilities | [📖 Debug/README.md](Debug/README.md) |
| **FSM** | Finite State Machine framework for AI and game logic | [📖 systems/fsm/README.md](systems/fsm/README.md) |

## 🔧 Integration Examples

### Basic Project Setup

```gdscript
# In your main scene's _ready() function
func _ready() -> void:
    # Configure SaveService
    SaveService.set_current_profile("player1")
    
    # Register audio
    AudioService.register_sound("click", load("res://audio/click.ogg"), AudioService.BUS_UI, "UI")
    
    # Set up input contexts
    InputService.enable_context("gameplay", true)
    
    # Initialize your game
    start_game()
```

### Event-Driven Communication

```gdscript
# Subscribe to events
EventBus.sub(EventTopics.PLAYER_DAMAGED, _on_player_damaged)
EventBus.sub(EventTopics.UI_BUTTON_CLICKED, _on_button_clicked)

# Publish events
EventBus.pub(EventTopics.PLAYER_JUMPED, {"position": player.global_position})
```

### Save/Load Integration

```gdscript
# Implement ISaveable interface
class_name MyGameData extends Node

func save_data() -> Dictionary:
    return {"score": score, "level": current_level}

func load_data(data: Dictionary) -> bool:
    score = data.get("score", 0)
    current_level = data.get("level", 1)
    return true

func _ready() -> void:
    SaveService.register_saveable(self)
```

## 🧪 Testing

All systems include comprehensive unit tests using the GUT (Godot Unit Testing) framework:

```bash
# Run all tests
godot --headless --script res://addons/gut/gut_cmdln.gd

# Run specific system tests
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_audio_service
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_save_service
```

## 📚 Documentation

- **System READMEs**: Each system has detailed documentation with examples
- **API Reference**: Comprehensive method and signal documentation
- **Integration Guides**: Step-by-step setup instructions
- **Best Practices**: Recommended usage patterns and performance tips

## 🎮 Example Projects

Check out the `Examples/` directories in each system for:
- Complete implementation examples
- Integration patterns
- Best practice demonstrations
- Common use cases

## 🤝 Contributing

We're not currently accepting contributions at this stage, but we plan to open the project for community contributions in the future. Stay tuned for updates!

## 📋 Requirements

- **Godot 4.5+** - All systems target modern Godot features
- **GDScript** - Primary language (some systems may support C#)
- **GUT Framework** - For running unit tests (included)

## 🔗 System Dependencies

Most systems are designed to work independently, but some have optional dependencies:

- **EventBus** - Used by most systems for communication
- **SaveService** - Used by systems that need persistence
- **InputService** - Used by player-facing systems
- **AudioService** - Used by systems that need sound feedback


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Godot Engine** - The amazing open-source game engine
- **GUT Framework** - Comprehensive testing framework for Godot
- **Community** - All the developers who provided feedback and contributions

---

<div align="center">

**Thanks for checking out this project, we hope it adds value to your game!**

[Get Started with AudioService](AudioService/README.md) • [Explore EventBus](EventBus/README.md) • [Try SaveService](SaveService/README.md)

</div>
