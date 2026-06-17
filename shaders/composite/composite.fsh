#version 120
/* composite.fsh - Post-processing pass */

uniform sampler2D gcolor;
varying vec2 texcoord;

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    gl_FragColor = color;
}
