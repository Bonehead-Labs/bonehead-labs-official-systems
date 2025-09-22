extends "res://addons/gut/test.gd"

const STATIC_CHECK_SCRIPT: String = "res://scripts/ci/run_static_checks.sh"
const FORMAT_CHECK_SCRIPT: String = "res://scripts/ci/run_format_check.sh"
const GUT_RUNNER_SCRIPT: String = "res://scripts/ci/run_gut_tests.sh"
const CI_GUIDE_DOC: String = "res://docs/CI.md"
const CONTRIBUTING_DOC: String = "res://CONTRIBUTING.md"
const COMMIT_HOOK: String = "res://.githooks/commit-msg"

func test_static_check_script_exists() -> void:
	assert_true(FileAccess.file_exists(STATIC_CHECK_SCRIPT), "Static check script should exist for CI pipelines.")

func test_format_check_script_exists() -> void:
	assert_true(FileAccess.file_exists(FORMAT_CHECK_SCRIPT), "Format check script should exist for developer workflows.")

func test_gut_runner_script_exists() -> void:
	assert_true(FileAccess.file_exists(GUT_RUNNER_SCRIPT), "Headless GUT runner script must be available.")

func test_ci_doc_mentions_all_scripts() -> void:
	var doc := _read_text(CI_GUIDE_DOC)
	assert_string_contains(doc, "run_static_checks.sh")
	assert_string_contains(doc, "run_format_check.sh")
	assert_string_contains(doc, "run_gut_tests.sh")

func test_contributing_mentions_git_hook() -> void:
	var doc := _read_text(CONTRIBUTING_DOC)
	assert_string_contains(doc, "core.hooksPath .githooks")

func test_commit_hook_exists_and_is_executable() -> void:
	assert_true(FileAccess.file_exists(COMMIT_HOOK), "Commit hook template should be present.")
	var file := FileAccess.open(COMMIT_HOOK, FileAccess.READ)
	assert_true(file != null, "Commit hook should be readable.")
	if file:
		var first_line := file.get_line()
		file.close()
		assert_string_contains(first_line, "#!/usr/bin/env bash")

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "File should open successfully: %s" % path)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
