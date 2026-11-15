class_name RichTooltipRect
extends TextureRect
## A TextureRect with a rich-text hover tooltip, like RichTooltipButton.

func _make_custom_tooltip(for_text: String) -> Object:
	return RichTooltipButton.make_tooltip(for_text)
