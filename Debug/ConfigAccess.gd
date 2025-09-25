extends Node
class_name ConfigAccess

## Configuration access control for enabling debug features.

@export var config_file_path: String = "user://debug_config.json"
@export var default_security_level: int = 1  # 0 = disabled, 1 = basic, 2 = advanced, 3 = admin
@export var require_authentication: bool = false
@export var max_failed_attempts: int = 5
@export var lockout_duration: float = 300.0  # 5 minutes

var _config_data: Dictionary = {}
var _failed_attempts: int = 0
var _lockout_until: float = 0.0
var _is_authenticated: bool = false
var _current_user: String = ""

signal config_loaded(config: Dictionary)
signal config_saved(config: Dictionary)
signal authentication_succeeded(user: String)
signal authentication_failed(user: String, reason: String)
signal access_denied(feature: String, required_level: int, current_level: int)
# signal security_violation_attempted(action: String, details: Dictionary)  # TODO: Implement security violation detection

func _ready() -> void:
    _load_config()

func _load_config() -> void:
    if not FileAccess.file_exists(config_file_path):
        _config_data = _get_default_config()
        _save_config()
        return

    var file = FileAccess.open(config_file_path, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()

        var json = JSON.new()
        var result = json.parse(content)
        if result == OK:
            _config_data = json.get_data()
        else:
            push_error("Failed to parse config file: " + config_file_path)
            _config_data = _get_default_config()
    else:
        _config_data = _get_default_config()

    config_loaded.emit(_config_data)

func _save_config() -> void:
    var file = FileAccess.open(config_file_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(_config_data, "  "))
        file.close()
        config_saved.emit(_config_data)
    else:
        push_error("Failed to save config file: " + config_file_path)

func _get_default_config() -> Dictionary:
    return {
        "security_level": default_security_level,
        "features": {
            "performance_overlay": true,
            "log_window": true,
            "debug_console": false,
            "event_bus_inspector": false,
            "scene_tester": false,
            "crash_reporter": true
        },
        "users": {
            "admin": {
                "password_hash": "admin123",  # In real implementation, use proper hashing
                "level": 3,
                "allowed_ips": ["127.0.0.1", "localhost"]
            },
            "developer": {
                "password_hash": "dev123",
                "level": 2,
                "allowed_ips": ["127.0.0.1", "localhost"]
            },
            "tester": {
                "password_hash": "test123",
                "level": 1,
                "allowed_ips": ["127.0.0.1", "localhost"]
            }
        },
        "audit_log": [],
        "last_login": {},
        "failed_attempts": 0,
        "lockout_until": 0
    }

func authenticate(user: String, password: String, ip_address: String = "127.0.0.1") -> bool:
    # Check if account is locked out
    if _is_locked_out():
        authentication_failed.emit(user, "Account locked out until %s" % _lockout_until)
        _log_security_event("authentication_failed", {
            "user": user,
            "reason": "account_locked",
            "ip": ip_address
        })
        return false

    # Check if user exists
    if not _config_data.get("users", {}).has(user):
        _failed_attempts += 1
        authentication_failed.emit(user, "User not found")
        _log_security_event("authentication_failed", {
            "user": user,
            "reason": "user_not_found",
            "ip": ip_address
        })
        _check_lockout()
        return false

    var user_data = _config_data["users"][user]
    var stored_password = user_data.get("password_hash", "")

    # Check IP restrictions
    var allowed_ips = user_data.get("allowed_ips", [])
    if not allowed_ips.is_empty() and not allowed_ips.has(ip_address):
        _failed_attempts += 1
        authentication_failed.emit(user, "Access denied from IP: " + ip_address)
        _log_security_event("authentication_failed", {
            "user": user,
            "reason": "ip_not_allowed",
            "ip": ip_address
        })
        _check_lockout()
        return false

    # Verify password (simplified - in real implementation use proper hashing)
    if password != stored_password:
        _failed_attempts += 1
        authentication_failed.emit(user, "Invalid password")
        _log_security_event("authentication_failed", {
            "user": user,
            "reason": "invalid_password",
            "ip": ip_address
        })
        _check_lockout()
        return false

    # Authentication successful
    _is_authenticated = true
    _current_user = user
    _failed_attempts = 0
    _lockout_until = 0.0

    # Update config
    _config_data["last_login"][user] = Time.get_ticks_msec()
    _config_data["failed_attempts"] = 0
    _save_config()

    authentication_succeeded.emit(user)
    _log_security_event("authentication_succeeded", {
        "user": user,
        "ip": ip_address,
        "level": user_data.get("level", 1)
    })

    return true

func logout() -> void:
    _is_authenticated = false
    _current_user = ""
    _log_security_event("logout", {"user": _current_user})

func can_access_feature(feature: String) -> bool:
    if not _is_authenticated and require_authentication:
        return false

    var user_level = _get_current_user_level()
    var required_level = _get_feature_required_level(feature)

    if user_level < required_level:
        access_denied.emit(feature, required_level, user_level)
        _log_security_event("access_denied", {
            "feature": feature,
            "required_level": required_level,
            "user_level": user_level,
            "user": _current_user
        })
        return false

    return true

func set_feature_enabled(feature: String, enabled: bool) -> bool:
    if not can_access_feature("config_edit"):
        return false

    if not _config_data.get("features", {}).has(feature):
        return false

    _config_data["features"][feature] = enabled
    _save_config()

    _log_security_event("feature_toggled", {
        "feature": feature,
        "enabled": enabled,
        "user": _current_user
    })

    return true

func get_feature_enabled(feature: String) -> bool:
    return _config_data.get("features", {}).get(feature, false)

func set_user_level(user: String, level: int) -> bool:
    if not can_access_feature("user_management"):
        return false

    if not _config_data.get("users", {}).has(user):
        return false

    _config_data["users"][user]["level"] = clamp(level, 0, 3)
    _save_config()

    _log_security_event("user_level_changed", {
        "user": user,
        "new_level": level,
        "admin": _current_user
    })

    return true

func add_user(user: String, password: String, level: int, allowed_ips: Array[String] = []) -> bool:
    if not can_access_feature("user_management"):
        return false

    if _config_data.get("users", {}).has(user):
        return false

    _config_data["users"][user] = {
        "password_hash": password,  # In real implementation, hash this
        "level": clamp(level, 0, 3),
        "allowed_ips": allowed_ips,
        "created_by": _current_user,
        "created_at": Time.get_ticks_msec()
    }

    _save_config()

    _log_security_event("user_added", {
        "new_user": user,
        "level": level,
        "admin": _current_user
    })

    return true

func remove_user(user: String) -> bool:
    if not can_access_feature("user_management"):
        return false

    if not _config_data.get("users", {}).has(user):
        return false

    if user == _current_user:
        return false  # Can't remove yourself

    _config_data["users"].erase(user)
    _save_config()

    _log_security_event("user_removed", {
        "removed_user": user,
        "admin": _current_user
    })

    return true

func _is_locked_out() -> bool:
    return _lockout_until > Time.get_ticks_msec() / 1000.0

func _check_lockout() -> void:
    if _failed_attempts >= max_failed_attempts:
        _lockout_until = Time.get_ticks_msec() / 1000.0 + lockout_duration
        _config_data["lockout_until"] = _lockout_until
        _save_config()

        _log_security_event("account_locked", {
            "failed_attempts": _failed_attempts,
            "lockout_duration": lockout_duration
        })

func _get_current_user_level() -> int:
    if not _is_authenticated:
        return 0

    var user_data = _config_data.get("users", {}).get(_current_user, {})
    return user_data.get("level", 0)

func _get_feature_required_level(feature: String) -> int:
    var feature_levels = {
        "performance_overlay": 1,
        "log_window": 1,
        "debug_console": 2,
        "event_bus_inspector": 2,
        "scene_tester": 2,
        "crash_reporter": 1,
        "config_edit": 3,
        "user_management": 3,
        "system_access": 3
    }

    return feature_levels.get(feature, 1)

func _log_security_event(event_type: String, details: Dictionary) -> void:
    var audit_entry = {
        "timestamp": Time.get_ticks_msec(),
        "event_type": event_type,
        "user": _current_user,
        "ip": "127.0.0.1",  # Would get from network
        "details": details
    }

    var audit_log = _config_data.get("audit_log", [])
    audit_log.append(audit_entry)

    # Keep only recent entries (last 1000)
    if audit_log.size() > 1000:
        audit_log = audit_log.slice(-1000)

    _config_data["audit_log"] = audit_log

    # Save periodically, not on every event
    if audit_log.size() % 10 == 0:
        _save_config()

func is_authenticated() -> bool:
    return _is_authenticated

func get_current_user() -> String:
    return _current_user

func get_security_level() -> int:
    return _get_current_user_level()

func get_config() -> Dictionary:
    return _config_data.duplicate(true)

func set_config_value(key: String, value: Variant) -> bool:
    if not can_access_feature("config_edit"):
        return false

    _config_data[key] = value
    _save_config()

    _log_security_event("config_changed", {
        "key": key,
        "value_type": str(typeof(value))
    })

    return true

func get_audit_log() -> Array[Dictionary]:
    return _config_data.get("audit_log", []).duplicate(true)

func clear_audit_log() -> bool:
    if not can_access_feature("system_access"):
        return false

    _config_data["audit_log"] = []
    _save_config()

    _log_security_event("audit_log_cleared", {})
    return true

func reset_to_defaults() -> bool:
    if not can_access_feature("system_access"):
        return false

    _config_data = _get_default_config()
    _save_config()

    _log_security_event("config_reset", {})
    return true

func get_feature_status() -> Dictionary:
    var features = _config_data.get("features", {})
    var status = {}

    for feature in features:
        status[feature] = {
            "enabled": features[feature],
            "can_access": can_access_feature(feature),
            "required_level": _get_feature_required_level(feature),
            "current_level": _get_current_user_level()
        }

    return status

func get_user_list() -> Array[String]:
    return _config_data.get("users", {}).keys()

func get_user_info(user: String) -> Dictionary:
    return _config_data.get("users", {}).get(user, {}).duplicate(true)
