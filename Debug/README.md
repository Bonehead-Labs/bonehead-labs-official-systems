# Debug & QA Tools

Comprehensive debugging and quality assurance toolkit that integrates seamlessly with all other game systems.

## Components

### Core Tools
- **PerformanceOverlay** (`PerformanceOverlay.gd`): Real-time performance monitoring with FPS, memory, and custom metrics
- **LogWindow** (`LogWindow.gd`): EventBus-powered logging window with filtering and search
- **DebugManager** (`DebugManager.gd`): Central coordinator for all debug tools with InputService integration
- **DebugConsole** (`DebugConsole.gd`): Feature-rich console with command registry and security levels

### Advanced Tools
- **EventBusInspector** (`EventBusInspector.gd`): Visual EventBus topic and payload inspector
- **SceneTester** (`SceneTester.gd`): Scene loading utility with mock services for isolated testing
- **CrashReporter** (`CrashReporter.gd`): Comprehensive crash logging and reporting system
- **ConfigAccess** (`ConfigAccess.gd`): Multi-user access control system for debug features

## Quick Start

### Basic Setup
```gdscript
# Add to your main scene
var debug_manager = DebugManager.new()
add_child(debug_manager)

# Configure tool visibility
debug_manager.performance_overlay_scene = preload("res://Debug/PerformanceOverlay.tscn")
debug_manager.log_window_scene = preload("res://Debug/LogWindow.tscn")
```

### Debug Keybindings
- **F1**: Toggle Performance Overlay
- **F2**: Toggle Log Window
- **F3**: Toggle Debug Console
- **F4**: Toggle EventBus Inspector
- **F12**: Take Screenshot

### Performance Monitoring
```gdscript
# Add custom metrics to performance overlay
DebugManager.add_custom_metric("Enemies Alive", enemy_count)
DebugManager.add_custom_metric("Items Collected", item_count)

# Log debug messages
DebugManager.log_debug_message("Player reached checkpoint", "INFO")
DebugManager.log_debug_message("Enemy AI failed pathfinding", "WARNING")
```

### Console Commands
```gdscript
# Access console via F3 or debug menu
# Built-in commands:
help                    # Show all commands
fps                     # Show FPS and frame time
memory                  # Show memory usage
scene                   # Show current scene info
screenshot              # Take screenshot
clear                   # Clear console output

# Security levels: 1 (basic), 2 (advanced), 3 (admin)
god                     # Toggle god mode (level 2)
give item_id quantity   # Give items (level 2)
spawn enemy x y         # Spawn enemies (level 3)
```

### EventBus Inspector
```gdscript
# Automatically tracks all EventBus events
# Select topics to view detailed payloads
# Real-time event monitoring with filtering

# Access via F4 or debug menu
```

### Scene Testing
```gdscript
# Load scenes with mock services for testing
var tester = SceneTester.new()
add_child(tester)

# Load a test scene
tester.load_scene("res://test_scenes/ui_test.tscn")

# Run automated tests
var test_results = tester.run_tests()
```

### Crash Reporting
```gdscript
# Enable crash reporting
var crash_reporter = CrashReporter.new()
crash_reporter.enabled = true
add_child(crash_reporter)

# Simulate crash for testing
crash_reporter.simulate_crash()

# View crash logs
var crash_logs = crash_reporter.get_crash_logs_list()
```

### Security & Access Control
```gdscript
# Set up user authentication
var config_access = ConfigAccess.new()
config_access.authenticate("developer", "dev123")

# Control feature access by security level
config_access.set_feature_enabled("debug_console", false)  # Disable console
config_access.set_feature_enabled("crash_reporter", true)  # Enable crash reporting

# Create new users
config_access.add_user("qa_tester", "test123", 1, ["192.168.1.100"])
```

## Integration with Other Systems

### InputService Integration
- All debug tools use InputService for keybindings
- Configurable action mappings
- Context-aware input handling

### EventBus Integration
- **LogWindow**: Subscribes to all EventBus events
- **EventBusInspector**: Visualizes EventBus topics and payloads
- **CrashReporter**: Emits crash events via EventBus
- **DebugManager**: Coordinates tool events

### UI System Integration
- All tools extend Control and integrate with existing UI
- Theme support and customization
- Modal and overlay modes

### SceneFlow Integration
- **SceneTester**: Uses LevelLoader for scene transitions
- **Portal testing**: Mock portal functionality
- **FlowManager diagnostics**: Track scene loading events

### World System Integration
- **CrashReporter**: Captures world state in crash logs
- **PerformanceOverlay**: Shows world metrics (active objects, etc.)
- **DebugConsole**: Commands for world manipulation

### Items & Economy Integration
- **DebugConsole**: Commands for item spawning and manipulation
- **SceneTester**: Mock inventory and wallet services
- **PerformanceOverlay**: Track item/economy metrics

### Combat System Integration
- **DebugConsole**: Commands for health manipulation and combat testing
- **SceneTester**: Mock health components and damage systems
- **PerformanceOverlay**: Monitor combat-related metrics

### Enemy AI Integration
- **DebugConsole**: Commands for enemy spawning and behavior testing
- **SceneTester**: Mock AI services for isolated testing
- **PerformanceOverlay**: Track AI performance metrics

## Security Features

### Multi-Level Access Control
- **Level 1 (Basic)**: Performance monitoring, logging, basic commands
- **Level 2 (Advanced)**: Console access, item spawning, scene testing
- **Level 3 (Admin)**: Full system access, user management, configuration

### Authentication System
```gdscript
# Built-in users:
# admin/admin123 (level 3)
# developer/dev123 (level 2)
# tester/test123 (level 1)

config_access.authenticate("developer", "dev123", "127.0.0.1")
```

### Audit Logging
- All security events are logged
- Failed authentication attempts tracked
- Feature access monitored and logged
- Configurable log retention

### IP Restrictions
- Per-user IP allowlists
- Network-based access control
- Automatic lockout on failed attempts

## Configuration

### Environment Detection
```gdscript
# Tools automatically enable based on:
# - Engine.is_editor_hint() (running in editor)
# - OS.has_feature("debug") (debug builds)
# - Custom environment variables
```

### Feature Toggles
```gdscript
# Enable/disable specific features
config_access.set_feature_enabled("performance_overlay", true)
config_access.set_feature_enabled("debug_console", false)
```

### Custom Metrics
```gdscript
# Add game-specific metrics
DebugManager.add_custom_metric("Player Health", player_health)
DebugManager.add_custom_metric("Current Level", current_level)
DebugManager.add_custom_metric("Active Quests", quest_count)
```

## EventBus Events

All debug tools emit comprehensive events:

### Performance Events
- `debug/fps_updated`: FPS changes
- `debug/memory_updated`: Memory usage changes
- `debug/metric_updated`: Custom metric changes

### Logging Events
- `debug/log`: Debug messages
- `debug/warning`: Warning messages
- `debug/error`: Error messages

### Console Events
- `debug/command_executed`: Command execution results
- `debug/console_toggled`: Console visibility changes

### Inspector Events
- `debug/inspector_refreshed`: Inspector updates
- `debug/topic_selected`: EventBus topic selection
- `debug/event_selected`: Event selection

### Crash Events
- `debug/crash_detected`: Crash occurrence
- `debug/crash_log_saved`: Crash log creation

### Security Events
- `debug/authentication_succeeded`: Successful login
- `debug/authentication_failed`: Failed login
- `debug/access_denied`: Feature access denied
- `debug/security_violation`: Security violations

## Advanced Usage

### Custom Commands
```gdscript
# Register custom console commands
DebugConsole.register_command("heal", _cmd_heal_player, "Heal player to full health", 2)

func _cmd_heal_player(args: Array) -> String:
    player_health = player_max_health
    return "Player healed to full health"
```

### Mock Services
```gdscript
# Create custom mock services for testing
var mock_achievement_service = {
    "unlock_achievement": func(achievement_id: String):
        print("Mock: Unlocked achievement " + achievement_id)
}

SceneTester.add_mock_service("AchievementService", mock_achievement_service)
```

### Custom Crash Handlers
```gdscript
# Add custom crash data
CrashReporter.add_custom_data("game_mode", current_game_mode)
CrashReporter.add_custom_data("player_level", player_level)

# Handle crashes programmatically
CrashReporter.crash_detected.connect(func(crash_data):
    send_crash_to_analytics(crash_data)
)
```

## Production Considerations

### Build Configuration
```gdscript
# Disable debug tools in release builds
if OS.has_feature("release"):
    debug_manager.enabled = false
    crash_reporter.enabled = false
```

### Security Hardening
```gdscript
# Require authentication in production
config_access.require_authentication = true

# Restrict to specific IPs
config_access.add_user("prod_debugger", "secure_pass", 2, ["10.0.0.100"])

# Enable audit logging
config_access.audit_log_enabled = true
```

### Performance Impact
- Debug tools add minimal overhead when disabled
- EventBusInspector has the highest impact due to event tracking
- Use feature toggles to enable only needed tools in development

## Extension Points

### Custom Tools
```gdscript
# Create custom debug tools
class_name CustomDebugTool
extends Control

func _ready():
    DebugManager.register_tool(self)

func toggle_visibility():
    visible = not visible
```

### Enhanced Metrics
```gdscript
# Add detailed performance metrics
class_name AdvancedMetrics
extends Node

func _process(delta):
    DebugManager.add_custom_metric("Delta Time", delta * 1000.0)
    DebugManager.add_custom_metric("Draw Calls", Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME))
```

### Integration Testing
```gdscript
# Automated testing framework
class_name DebugTestRunner
extends Node

func run_all_tests():
    var scene_tester = SceneTester.new()
    var results = scene_tester.run_tests()
    DebugManager.log_debug_message("Tests completed: " + str(results), "INFO")
```

This Debug & QA Tools system provides comprehensive development and testing capabilities while maintaining security and performance considerations for production environments.
