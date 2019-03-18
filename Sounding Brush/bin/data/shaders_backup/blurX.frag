precision highp float;

uniform sampler2D tex0;
uniform float useTexture;
uniform float useColors;
uniform vec4 globalColor;

varying float depth;
varying vec4 colorVarying;
varying vec2 texCoordVarying;

uniform float bAmount;
uniform vec2 resolution;

void main()
{
	vec2 st = texCoordVarying;
	vec4 color = texture2D(tex0, texCoordVarying);
	color += 0.00004 * 1.0 * texture2D(tex0, st + vec2(bAmount * -4.0, 0.0));
	color += 0.0004 * 2.0 * texture2D(tex0, st + vec2(bAmount * -3.0, 0.0));
	color += 0.004 * 3.0 * texture2D(tex0, st + vec2(bAmount * -2.0, 0.0));
	color += 0.04 * 4.0 * texture2D(tex0, st + vec2(bAmount * -1.0, 0.0));
	// color += 0.4 * 5.0 * texture2D(tex0, st + vec2(bAmount, 0.0));
	color += 0.04 * 4.0 * texture2D(tex0, st + vec2(bAmount * 1.0, 0.0));
	color += 0.004 * 3.0 * texture2D(tex0, st + vec2(bAmount * 2.0, 0.0));
	color += 0.0004 * 2.0 * texture2D(tex0, st + vec2(bAmount * 3.0, 0.0));
	color += 0.00004 * 1.0 * texture2D(tex0, st + vec2(bAmount * 4.0, 0.0));
	//color /= 25.0;
  gl_FragColor = vec4(color);
}
