
precision highp float;

uniform float alpha;
uniform vec3 col;

void main()
{
	gl_FragColor = vec4(col.r, col.g, col.b, alpha);
}
