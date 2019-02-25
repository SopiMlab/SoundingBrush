attribute vec4 position;
attribute vec4 color;
attribute vec4 normal;
attribute vec2 myCustomAttribute;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

varying vec4 colorVarying;

uniform vec4 c;
uniform vec2 screenResolution;
uniform vec2 area;
uniform float length;
uniform float time;
uniform float seed;

float _Speed = 100.;
float _Amount = 5.;
float _Distance = 100.;

void main() {
	colorVarying = color;
	// texCoordVarying = texcoord;

  gl_Position = projectionMatrix * modelViewMatrix * position;
}
