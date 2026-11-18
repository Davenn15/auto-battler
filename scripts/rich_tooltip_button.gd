class_name RichTooltipButton
extends Button
## A Button whose hover tooltip is rich text: its tooltip_text with keyphrases highlighted
## (stat colours and icons, see Keyphrases). Use it anywhere a description shows on hover.

## True when tooltip_text is already BBCode (it's shown as it is, not run through
## Keyphrases.format).
var bbcode_tooltip := false


func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltipButton.make_tooltip(for_text if bbcode_tooltip else Keyphrases.format(for_text), true)


## The tooltip itself, for any Control that wants one (see RichTooltipRect). `for_text` is
## plain text with keyphrases to highlight, or BBCode when `is_bbcode`.
static func make_tooltip(for_text: String, is_bbcode: bool = false) -> Control:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(260, 0)
	label.text = for_text if is_bbcode else Keyphrases.format(for_text)
	# Measure its height now: a fit-content label only knows it once it's in the tree, and
	# Godot places the tooltip by its size when it opens, so an unmeasured one is kept on
	# screen as if it were one line tall and runs off the bottom (badges low on the screen).
	var root := (Engine.get_main_loop() as SceneTree).root
	label.size = Vector2(label.custom_minimum_size.x, 0)
	root.add_child(label)
	label.custom_minimum_size.y = label.get_content_height()
	root.remove_child(label)
	return label
