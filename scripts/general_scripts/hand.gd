extends CharacterBody3D

func _enter_tree():
	var id: int = str(name).substr(0, str(name).find('H')).to_int()
	set_multiplayer_authority(id)
	$MultiplayerSynchronizer.set_multiplayer_authority(id)
