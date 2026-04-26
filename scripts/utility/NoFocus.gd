# NoFocus.gd (autoload)
extends Node

var _empty_focus := StyleBoxEmpty.new()

func _ready() -> void:
	_apply_recursive(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	_apply_recursive(n)

func _apply_recursive(n: Node) -> void:
	if n is Control:
		# Hide focus visuals globally (harmless if a type doesn't use these)
		n.add_theme_stylebox_override("focus", _empty_focus)
		n.add_theme_stylebox_override("focus_hover", _empty_focus)

		# Allow per-node opt-in via "allow_focus" group
		if not n.is_in_group("allow_focus"):
			# Text inputs keep click-to-focus so carets work
			if n is LineEdit or n is TextEdit or n is CodeEdit:
				n.focus_mode = Control.FOCUS_CLICK
			# RichTextLabel: allow focus only when it supports selection, so Ctrl+C works
			elif n is RichTextLabel:
				var rtl := n as RichTextLabel
				if rtl.selection_enabled:
					n.focus_mode = Control.FOCUS_CLICK
					# Convenience: enable context menu for Copy
					rtl.context_menu_enabled = true
				else:
					n.focus_mode = Control.FOCUS_NONE
			else:
				# Everything else stays non-focusable
				n.focus_mode = Control.FOCUS_NONE

	for c in n.get_children():
		_apply_recursive(c)
