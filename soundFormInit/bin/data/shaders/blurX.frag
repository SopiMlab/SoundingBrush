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

float offset[3];
float weight[3];

void main()
{
	offset[0] = 0.0;
	offset[1] = 1.3846153846;
	offset[2] = 3.2307692308;

	weight[0] = 0.2270270270;
	weight[1] = 0.3162162162;
	weight[2] = 0.0702702703;

	// float offset[3] = float[3]( 0.0, 1.3846153846, 3.2307692308 );
	// float weight[3] = float[3]( 0.2270270270, 0.3162162162, 0.0702702703 );

  vec4 tc = vec4(1.0, 0.0, 0.0, 0.0);

	float a = (texture2D(tex0, texCoordVarying)).z;

  if (texCoordVarying.x<(bAmount-0.01))
  {
    vec2 texCoordVarying = texCoordVarying.xy;
    tc = texture2D(tex0, texCoordVarying).rgba * weight[0];
    for (int i=1; i<3; i++)
    {
      tc += texture2D(tex0, texCoordVarying + vec2(offset[i])/resolution.x, 0.0).rgba \
              * weight[i];
      tc += texture2D(tex0, texCoordVarying - vec2(offset[i])/resolution.x, 0.0).rgba \
              * weight[i];
    }
  }
  else if (texCoordVarying.x>=(bAmount+0.01))
  {
    tc = texture2D(tex0, texCoordVarying.xy).rgba;
  }
  gl_FragColor = vec4(tc);
}
