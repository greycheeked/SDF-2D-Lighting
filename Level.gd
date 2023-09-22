extends Node2D

# The shader is set to a maximum of 100 lights
const LIGHT_N: int = 100

# The parameters of the light sources are each passed to the shader as an array
var light_pos: Array[Vector2]
var light_col: Array[Color]
var light_range: Array[float]
var light_ang: Array[float]
var light_fan_ang: Array[float]

# For the sake of simplicity, I'll create a few lights as dictionaries
var lights: Array[Dictionary]

# For some animation only
var time: float

@onready var camera_2d = $Camera2D
@onready var light_and_shadow = $CanvasLayer/LightAndShadow


func _ready():
	# 3 lights are defined
	lights = [
		{
			"pos" : Vector2(250.0, 250.0),
			"range" : 800.0,
			"col" : Color.AQUA,
			"ang" : PI,
			"fan_ang" : PI * 0.25
		},
		{
			"pos" : Vector2(0.0, 0.0),
			"range" : 800.0,
			"col" : Color.RED,
			"ang" : 0.0,
			"fan_ang" : TAU
		},
		{
			"pos" : Vector2(600.0, 600.0),
			"range" : 800.0,
			"col" : Color.BEIGE,
			"ang" : 0.0,
			"fan_ang" : PI * 0.125
		}
	]
	
	# The parameter arrays will be resized to the necessary size
	# once and for all
	light_pos.resize(LIGHT_N)
	light_range.resize(LIGHT_N)
	light_col.resize(LIGHT_N)
	light_ang.resize(LIGHT_N)
	light_fan_ang.resize(LIGHT_N)


func _physics_process(delta):
	# 2 of the lights are animated a bit
	time += delta
	lights[1]["pos"] = Vector2(800.0, fmod(time * 100, 720.0))
	lights[2]["ang"] = fmod(time, TAU)
	
	# The current states of the lights are entered into the parameter arrays
	for i in range(lights.size()):
		light_pos[i] = lights[i]["pos"]
		light_col[i] = lights[i]["col"]
		light_range[i] = lights[i]["range"]
		light_ang[i] = lights[i]["ang"]
		light_fan_ang[i] = lights[i]["fan_ang"]
	
	# The shader parameters are passed updated
	light_and_shadow.material.set_shader_parameter("light_n", lights.size())
	light_and_shadow.material.set_shader_parameter("light_pos", light_pos)
	light_and_shadow.material.set_shader_parameter("light_col", light_col)
	light_and_shadow.material.set_shader_parameter("light_rng", light_range)
	light_and_shadow.material.set_shader_parameter("light_ang", light_ang)
	light_and_shadow.material.set_shader_parameter("light_fan_ang", light_fan_ang)
	
	# The camera is not changed in this demo,
	# but if someone wants to mess around with the camera,
	# these lines make sure the shader knows about it
	var trans_comp: Transform2D = get_global_transform_with_canvas()
	light_and_shadow.material.set_shader_parameter("comp_mat", trans_comp)
	light_and_shadow.material.set_shader_parameter("zoom", camera_2d.zoom.x)
	light_and_shadow.material.set_shader_parameter("rotation", camera_2d.global_rotation)
