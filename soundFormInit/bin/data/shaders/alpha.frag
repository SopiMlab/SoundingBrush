
precision highp float;

uniform float alpha;

void main()
{
	gl_FragColor = vec4(r, g, b, alpha);
}
