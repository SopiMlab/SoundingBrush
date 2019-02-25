attribute vec4 position;
attribute vec4 color;
attribute vec4 normal;
attribute vec2 texcoord;
attribute vec2 myCustomAttribute;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

varying vec4 colorVarying;
varying vec2 texCoordVarying;

uniform vec4 c;
uniform vec2 screenResolution;
uniform vec2 area;
uniform float length;
uniform float time;
uniform float seed;
uniform float width;

float _Speed = 100.;
float _Amount = 5.;
float _Distance = 100.;

void main() {
	colorVarying = color;
	texCoordVarying = texcoord;

	// vec4 modifiedPosition = position;
	//
	// modifiedPosition.x += sin( time * _Speed + position.y * _Amount ) * _Distance;

	float displacementY;
	float displacementHeight = 100.0;
	float displaceWeight = width * .25;
	//displacementY = sin(time + (position.x / 100.0));

	float amplitude = 1.;
	float frequency = 1.;
	// displacementY = sin(position.x * frequency);

	vec2 displacement;
	if(area.x>area.y) displacement = vec2(0, sin(position.y * frequency)) * displaceWeight;
	if(area.y>area.x) displacement = vec2(sin(position.x * frequency), 0) * displaceWeight;

	float t = 0.01*(time*130.0);
	displacementY += sin(position.x*frequency*.1 + t)*4.5;
	displacementY += sin(position.x*frequency*1.72 + t*1.121)*4.0;
	displacementY += sin(position.x*frequency*2.221 + t*0.437)*5.0;
	displacementY += sin(position.x*frequency*3.1122+ t*4.269)*2.5;
	displacementY *= amplitude*0.06;

	vec4 modifiedPosition = projectionMatrix * modelViewMatrix * position;
	modifiedPosition.xy += displacement * (1. - myCustomAttribute.x);

  gl_Position = modifiedPosition;
}
