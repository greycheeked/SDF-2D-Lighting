shader_type canvas_item;
render_mode unshaded, blend_mul;

const int LIGHT_N = 100;
const int STEP_MAX = 32;
const float HARDNESS = 20.0;

// SOFT_LIMIT and HARD_LIMIT refer to the distance between a light and
// an occluder. If the distance is greater than SOFT_LIMIT, the shadows
// are drawn softly. If it is smaller than HARD_LIMIT, they are drawn hard.
// In between the two states are blended.
const float SOFT_LIMIT = 10.0;
const float HARD_LIMIT = 5.0;

// Light fans get a soft shadow edge.
// ANG_EDGE is the width of the edge in radians.
const float ANG_EDGE = 0.1;

// Width of the light edge on the walls
const float WALL_EDGE = 8.0;

// Number of currently active lights
uniform int light_n = 0;
// Global positions of the lights 
uniform vec2 light_pos[LIGHT_N];
uniform vec4 light_col[LIGHT_N];
// Range of the lights
uniform float light_rng[LIGHT_N];
// Direction of the light. Only useful for light fans.
uniform float light_ang[LIGHT_N];
// Angle of the light fan to the left and right in radians.
// Value greater than PI: no fan.
uniform float light_fan_ang[LIGHT_N];

// Camera zoom and angle
uniform float zoom;
uniform float rotation;
// Transform2D from level to viewport.
// (level.get_global_transform_with_canvas())
uniform mat4 comp_mat;

// Position of the pixel (see vertex shader)
varying vec2 pos;


void vertex() {
	pos = VERTEX;
}


float difference(float src, float dst) {
	// Difference of two angles from -PI to +PI
	return mod(dst - src + TAU + PI, TAU) - PI;
 }


void fragment() {
	
	float wall_edge = WALL_EDGE * zoom;
	float soft_limit = SOFT_LIMIT * zoom;
	float hard_limit = HARD_LIMIT * zoom;
	
	vec3 col_accum = vec3(0.0, 0.0, 0.0);
	vec2 at = screen_uv_to_sdf(SCREEN_UV);
	
	int l = 0;
	while(l < light_n) {
		
		// light range
		float max_dist = light_rng[l] * zoom;
		
		// light position
		vec2 l_pos = light_pos[l];
		l_pos = (comp_mat * vec4(l_pos, 0.0, 1.0)).xy;
		
		// Signed Distance Value at light position
		float l_d = texture_sdf(l_pos);
		
		// Lights are ignored if they fall below this distance to the next occluder
		if (l_d > zoom) {
			
			// distance from pixel to light
			vec2 diff = l_pos - pos;
			float dist = length(diff);
			
			// pixel is irgnored if it is out of light range
			if (dist <= max_dist) {
				
				vec2 dir = normalize(diff);
				float ang = light_ang[l];
				float ang_fan = light_fan_ang[l];
				float diff_ang = PI;
				if (ang_fan < PI - 0.001) {
					float dir_ang = atan(dir.y, dir.x);
					diff_ang = ang_fan - abs(difference(dir_ang, ang - rotation));
				}
				// pixel is ignored if it lies outside the light fan
				if (diff_ang >= 0.0) {
					
					float soft = 1.0;
					float work_dist = 0.0001;
					float remain_dist = dist;

					// uncertain if ray is in occluder
					int inside = -1;
					float indepth = 0.0;
					for (int i = 0; i < STEP_MAX; i ++) {
						
						// ray has reached light
						if (work_dist >= dist) {
							
							// light intensity decreases quadratically with distance
							float fade = 1.0 - min(1.0, dist / max_dist);
							fade = pow(fade, 2.0);
							
							// soft light fan edge
							float ang_soft = 1.0;
							if (diff_ang <= ANG_EDGE) {
								ang_soft = (max_dist / ANG_EDGE) * diff_ang / max_dist;
								ang_soft = min(1.0, ang_soft);
							}
							
							float wall_soft = 1.0;
							// ray started in occluder; was not deep in it
							if (inside == 1) {
								// soft shadow on wall
								float wall_soft = indepth / wall_edge;
								wall_soft = 1.0 - wall_soft;
								wall_soft = min(1.0, wall_soft * 2.0);
								
								// extra light on wall
								col_accum += light_col[l].rgb * fade * wall_soft;
							}
							
							// special case:
							// light is at most soft_limit pixels away from occluders
							// fade in hard shadow
							if (l_d < soft_limit) {
								if (soft < ang_soft) {
									// anything closer than hard_limit is hard shadow
									float temp_l_d = max(0.0, l_d - hard_limit);
									// soft shadow is faded in between hard_limit and soft_limit
									float hard_blend = temp_l_d / (soft_limit - hard_limit);
									hard_blend = 1.0 - hard_blend;
									float counter_soft = (1.0 - soft) * hard_blend;
									col_accum += light_col[l].rgb * fade * (soft + counter_soft);
								} else {
									col_accum += light_col[l].rgb * fade * ang_soft;
								}
							// default:
							// Light is soft_limit or more pixels away from occluders
							// soft shadow
							} else {
								soft = min(soft, ang_soft);
								col_accum += light_col[l].rgb * fade * soft;
							}
							
							// ready, out
							break;
						}

						// signed distance value at current position on ray
						vec2 cur_at = at + work_dist * dir;
						float d = texture_sdf(cur_at);
						float d_orig = d;
						
						// Each camera change alters the Signed Distance Field.
						// That's why the angles jitter a bit.
						// To compensate, we take an average of the surrounding area.
						float off = 1.0 * zoom;
						float d_u_1 = texture_sdf(cur_at + vec2(-off, -off));
						float d_d_1 = texture_sdf(cur_at + vec2(off, -off));
						float d_l_1 = texture_sdf(cur_at + vec2(-off, off));
						float d_r_1 = texture_sdf(cur_at + vec2(off, off));

						float d_u_2 = texture_sdf(cur_at + vec2(0.0, -off));
						float d_d_2 = texture_sdf(cur_at + vec2(0.0, off));
						float d_l_2 = texture_sdf(cur_at + vec2(-off, 0.0));
						float d_r_2 = texture_sdf(cur_at + vec2(off, 0.0));

						d = d + d_u_1 + d_d_1 + d_l_1 + d_r_1;
						d = d + d_u_2 + d_d_2 + d_l_2 + d_r_2;
						d /= 9.0;
						
						// To have light on the walls (i.e. on the occluders),
						// we need to follow the path of a ray through the occluders:
						// ray is in occluder
						if (d_orig < 0.01) {
							// ray was not yet in any occluder
							if (inside == -1) {
								float p_d = texture_sdf(pos);
								// ray has just started in occluder
								if (p_d < 0.01) {
									inside = 0;
									// ray makes jump out of occluder
									// or is deeper inside than wall_edge
									d = wall_edge;
								// here shadow
								} else {
									break;
								}
							// ray was already or is still in occluder
							} else {
								break;
							}
						// ray is outside of occluder
						} else {
							// ray just comes out of occluder where it started
							if (inside == 0) {
								// marking: ray was already in occluder
								inside = 1;
								indepth = wall_edge - d;
							}
						}
						
						soft = min(soft, HARDNESS * d / work_dist);
						
						// The remaining distance between beam and light
						// is smaller than the SDF value of one of the two
						// and can therefore be skipped
						float max_d = max(d, l_d);
						if (max_d >= remain_dist) {
							d = max_d;
						}
						work_dist += d;
						remain_dist -= d;
					} // for
				} // if diff_ang >= 0.0
			} // if dist <= max_dist
		} // if l_d > zoom

		// next light
		l += 1;

	} // while

	// blend_mode is blend_mul,
	// so target pixel is multiplied by COLOR
	// (you can also change the blend_mode to blend_add)
	COLOR = vec4(col_accum, 1.0);
}