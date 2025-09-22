class_name _ThemeLocalization
extends Node

## ThemeLocalization provides translation helpers with graceful fallback.
## Add as an autoload named `ThemeLocalization` to access localization tokens.

func translate(token: StringName, default_text: String = "") -> String:
    if token == StringName():
        return default_text
    var translated := TranslationServer.translate(String(token))
    if translated.is_empty():
        return default_text
    return translated

func translate_with_args(token: StringName, args: Dictionary, default_text: String = "") -> String:
    var base := translate(token, default_text)
    for key in args.keys():
        base = base.replace("%{%s}" % key, str(args[key]))
    return base
