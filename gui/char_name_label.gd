extends Label


func _on_ready() -> void:
	self.text = "Name: " + PlayerStats.playerName
