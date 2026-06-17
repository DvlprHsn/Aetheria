#version 120
/* shadow.fsh */
uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 color;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    if(albedo.a < 0.1) discard;
    
    gl_FragColor = vec4(1.0);
}
