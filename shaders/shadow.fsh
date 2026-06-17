#version 120
/* shadow.fsh - Shadow map generation */

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 color;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    if(albedo.a < 0.1) discard; // Support semi-transparent shadows (leaves)
    
    gl_FragColor = vec4(albedo.rgb, 1.0);
}
