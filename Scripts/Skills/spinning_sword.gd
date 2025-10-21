# Scripts/Skills/spinning_sword.gd
extends Area2D

# O sinal agora envia o 'target' (o Inimigo) e não o 'body'
signal sword_hit(target: Node, sword_node: Area2D)

# --- CORREÇÃO AQUI ---
# A função foi renomeada para '_on_area_entered' e o parâmetro mudou para 'area: Area2D'
func _on_area_entered(area: Area2D):
	# O 'area' é o Hurtbox. 'area.get_owner()' é o Inimigo.
	var target = area.get_owner()
	
	# Emite o sinal com o 'target' (o Inimigo) em vez do 'area' (o Hurtbox)
	emit_signal("sword_hit", target, self)
