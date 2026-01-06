extends CharacterBody2D

var player_id: String
var is_local_player := false
var is_frozen:= false

const SPEED = 50.0
var last_direction := Vector2.DOWN

var knockback_amount = 0
var KNOCKBACK_OFFSET = 10

const DASH_SPEED = 100.0
const DASH_TIME = 0.2     
var dash_timer = 0.0
var can_dash = true
var dash_cooldown = 0.5     
var dash_cooldown_timer = 0.0

var HURT_TIME = 0.5

var hurt_timer = 0.0

enum PlayerState {
	IDLE,
	RUN,
	ATTACK,
	HURT,
	DASH,
	DEATH
}

var state: PlayerState = PlayerState.IDLE

@onready var animated_sprite := $AnimatedSprite2D
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var knockback_amount_text: Label = $KnockBackAmount
@onready var player_name: Label = $PlayerName
@onready var character_collider: CollisionShape2D = $CharacterCollider


var attack_offsets = {
	Vector2.UP: Vector2(0, -25),
	Vector2.DOWN: Vector2(0, 5),
	Vector2.LEFT: Vector2(-16, -10),
	Vector2.RIGHT: Vector2(16, -10)
}

func _ready():
	sword_hitbox.monitoring = false
	sword_hitbox.monitorable = false
	knockback_amount_text.text = "0" + "%"
	
func send_state_to_server():
	
	if state == PlayerState.DEATH:
		return
		
	Network.send_json({
		"type": "player_state",
		"id": player_id,
		"pos": global_position,
		"vel": velocity,
		"state": state,
		"dir": last_direction
	})

func apply_visual_identity():
	if is_local_player:
		player_name.modulate = Color(0, 1, 0)
	else:
		player_name.modulate = Color(1, 1, 1) 

func apply_network_state(data):
	if is_local_player: return
	
	if state in [PlayerState.HURT, PlayerState.DEATH]:
		return
	
	var new_state = int(data.state) as PlayerState
	
	if new_state == PlayerState.DEATH:
		if state != PlayerState.DEATH: 
			state = PlayerState.DEATH
			velocity = Vector2.ZERO
			global_position = _string_to_vector2(data.pos)
			update_death_anim(last_direction)
			return
	
	global_position = _string_to_vector2(data.pos)
	velocity = _string_to_vector2(data.vel)
	
	if data.has("dir"):
		last_direction = _string_to_vector2(data.dir)
		
	state = new_state
	
	if state == PlayerState.ATTACK:
		if not animated_sprite.animation.contains("attack"):
			_update_attack_anim(last_direction)
	elif state == PlayerState.HURT:
		_update_hurt_anim(last_direction)
	else:
		_update_anim(velocity if velocity != Vector2.ZERO else Vector2.ZERO)

func _physics_process(delta):
	
	if is_frozen:
		return
		
	if state == PlayerState.HURT:
		update_hurt_time(delta)
		move_and_slide()
		return
	
	if not is_local_player:
		if state != PlayerState.DEATH:
			move_and_slide()
		return
	
	if state != PlayerState.DEATH:

		var dir = Vector2(
			Input.get_axis("Left", "Right"),
			Input.get_axis("Up", "Down")
		)
		
		update_hitbox()
		
		if dir != Vector2.ZERO:
			last_direction = dir.normalized()
		if state in [PlayerState.IDLE, PlayerState.RUN]:
			if dir != Vector2.ZERO:
				state = PlayerState.RUN
			else:
				state = PlayerState.IDLE
			velocity = dir.normalized() * SPEED

		if state not in [PlayerState.HURT, PlayerState.DEATH, PlayerState.ATTACK]:
			_update_anim(dir)
			
		if state == PlayerState.DASH and state != PlayerState.HURT:
			update_dash(delta)
		
		update_dash_cooldown(delta)

		if Input.is_action_just_pressed("Attack"):
			start_attack()
		
		if Input.is_action_just_pressed("Dash") and can_dash and state != PlayerState.HURT:
			start_dash()
			
		move_and_slide()
		
	if is_local_player:
		send_state_to_server()

func update_hitbox():
		
		var d = Vector2(sign(last_direction.x), sign(last_direction.y))
		
		if d not in attack_offsets:
			if abs(d.x) > abs(d.y):
				d = Vector2(sign(d.x),0)
			else:
				d = Vector2(0,sign(d.y))

		if d == Vector2.ZERO:
			d = Vector2.DOWN
			
		sword_hitbox.position = attack_offsets[d]
		
		if d == Vector2.UP:
			sword_hitbox.rotation_degrees = 0
		elif d == Vector2.DOWN:
			sword_hitbox.rotation_degrees = 180
		elif d == Vector2.LEFT:
			sword_hitbox.rotation_degrees = -90
		elif d == Vector2.RIGHT:
			sword_hitbox.rotation_degrees = 90


func _update_anim(dir):
	if dir.y != 0:
		if dir.y < 0:
			animated_sprite.play("run_up")
		else:
			animated_sprite.play("run_down")
	elif dir.x != 0:
		if dir.x > 0:
			animated_sprite.play("run_right")
		else:
			animated_sprite.play("run_left")
	else:
		animated_sprite.play("idle")


func start_attack():
	if state != PlayerState.IDLE and state != PlayerState.RUN:
		return
		
	state = PlayerState.ATTACK
	sword_hitbox.monitoring = true
	var d = velocity if velocity != Vector2.ZERO else last_direction
	_update_attack_anim(d)


func _update_attack_anim(d : Vector2):
	
	if abs(d.x) > abs(d.y):
		if d.x > 0:
			animated_sprite.play("attack_right")
		else:
			animated_sprite.play("attack_left")
	else:
		if d.y < 0:
			animated_sprite.play("attack_up")
		else:
			animated_sprite.play("attack_down")
	
	
	
	if not animated_sprite.animation_finished.is_connected(_on_attack_finished):
		animated_sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
	
	
	
func _on_attack_finished():
	sword_hitbox.monitoring = false
	if state != PlayerState.DEATH:
		state = PlayerState.IDLE
	
	
	
func apply_hit(attacker_pos: Vector2, new_knockback_amount):
	
	if state in [PlayerState.HURT, PlayerState.DEATH]:
		return
		
	sword_hitbox.monitoring = false
	
	if knockback_amount <= 100:
		knockback_amount = new_knockback_amount
		
	if knockback_amount > 20 and knockback_amount < 50:
		knockback_amount_text.modulate = Color(1.0, 0.53, 0.205, 1.0)
	elif knockback_amount > 50:
		knockback_amount_text.modulate = Color(1.0, 0.0, 0.0, 1.0)
		
	knockback_amount_text.text = str(knockback_amount) + "%"
	
	var knockback_dir = (global_position - attacker_pos).normalized()
	velocity = knockback_dir * (knockback_amount * 2)
	
	var diff = attacker_pos - global_position
	
	state = PlayerState.HURT
	hurt_timer = HURT_TIME
	_update_hurt_anim(diff)
	
func _update_hurt_anim(d : Vector2):
	if abs(d.x) > abs(d.y):
		if d.x > 0:
			animated_sprite.play("hurt_right")
		else:
			animated_sprite.play("hurt_left")
	else:
		if d.y < 0:
			animated_sprite.play("hurt_up")
		else:
			animated_sprite.play("hurt_down")
	

func start_dash():
	state = PlayerState.DASH
	dash_timer = DASH_TIME
	can_dash = false
	dash_cooldown_timer = dash_cooldown

	if last_direction == Vector2.ZERO:
		last_direction = Vector2.DOWN

	velocity = last_direction.normalized() * DASH_SPEED
	sword_hitbox.monitoring = false
	
	
func update_dash(delta):
	if state == PlayerState.DASH:
		dash_timer -= delta
		
	if dash_timer <= 0:
		state = PlayerState.IDLE
		velocity = Vector2.ZERO
		
func update_hurt_time(delta):
	hurt_timer -= delta
	if hurt_timer <= 0:
		state = PlayerState.IDLE
		velocity = Vector2.ZERO
	
func update_dash_cooldown(delta):
	if not can_dash:
		dash_cooldown_timer -= delta
	if dash_cooldown_timer <= 0:
		can_dash = true
		
		
func death():
	state = PlayerState.DEATH	
	player_name.text = ""
	knockback_amount_text.text = ""
	character_collider.set_deferred("disabled", true)
	var d = last_direction
	
	if is_local_player: 
		Network.send_json({"type": "player_died"})
	
	update_death_anim(d)
		
func update_death_anim(d : Vector2):
	
	if abs(d.x) > abs(d.y):
		if d.x > 0:
			animated_sprite.play("death_right")
		else:
			animated_sprite.play("death_left")
	else:
		if d.y < 0:
			animated_sprite.play("death_up")
		else:
			animated_sprite.play("death_down")
			

func _string_to_vector2(string_val: String) -> Vector2:
	if string_val == "": return Vector2.ZERO
	# Klammern entfernen
	var clean = string_val.replace("(", "").replace(")", "")
	# Am Komma trennen
	var parts = clean.split(",")
	if parts.size() >= 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO
	
func freeze_player():
	is_frozen = true
	velocity = Vector2.ZERO
	state = PlayerState.IDLE
	
