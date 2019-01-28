precision highp float;

uniform sampler2D tex0;
uniform float useTexture;
uniform float useColors;
uniform vec4 globalColor;

varying float depth;
varying vec4 colorVarying;
varying vec2 texCoordVarying;

uniform vec4 c;
uniform vec2 screenResolution;
uniform vec2 area;
uniform float length;
uniform float time;
// uniform float alpha;

#define PI 3.14159265359

float hash(float n) { return fract(sin(n) * 1e4); }
float hash(vec2 p) { return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	// Simple 2D lerp using smoothstep envelope between the values.
	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
	//			smoothstep(0.0, 1.0, f.y)));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// YUV to RGB matrix
mat3 yuv2rgb = mat3(1.0, 0.0, 1.13983,
                    1.0, -0.39465, -0.58060,
                    1.0, 2.03211, 0.0);

// RGB to YUV matrix
mat3 rgb2yuv = mat3(0.2126, 0.7152, 0.0722,
                    -0.09991, -0.33609, 0.43600,
                    0.615, -0.5586, -0.05639);

mat2 rotate2d(float _angle){
	return mat2(cos(_angle), -sin(_angle),
							sin(_angle), cos(_angle));
}

void main() {
vec2 st = gl_FragCoord.xy/(screenResolution.xy);

// move space from the center to the vec2(0.0)
	 // st -= vec2(0.5);
	 // // rotate the space
	 // st = rotate2d( sin(time) ) * st;
	 // // move it back to the original place
	 // st += vec2(0.5);

st += area;

// UV values goes from -1 to 1
// So we need to remap st (0.0 to 1.0)
// st -= 0.5;  // becomes -0.5 to 0.5
// st *= 2.0;  // becomes -1.0 to 1.0

vec4 color = c;

color.rgb += (yuv2rgb * vec3(st.x, st.y, time)) * 0.1;
//do other stuff here!
// color.rgb -= max((gl_FragCoord.x/resolution.x * gl_FragCoord.y/resolution.y), .33);
// color.a = noise(length);

gl_FragColor = color;
}
