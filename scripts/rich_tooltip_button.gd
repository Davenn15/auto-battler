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
	return label
