#pragma include "headerVert.glsl"

	uniform mat4 projectionMatrix;
	uniform mat4 modelViewMatrix;
	uniform mat4 textureMatrix;
	uniform mat4 modelViewProjectionMatrix;

	attribute vec4 position

	void main()
	{
		v_color = color;
		v_texCoord = texcoord;
		gl_Position = modelViewProjectionMatrix * position;
	}
