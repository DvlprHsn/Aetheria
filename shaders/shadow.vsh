#version 120
/* shadow.vsh - Shadow map generation */

varying vec2 texcoord;
varying vec4 color;

void main() {
    // Waving leaves and grass in shadow pass too!
    vec4 position = gl_Vertex;
    
    // Using a texture coordinate hack since mc_Entity isn't available by default:
    // This is safe since we just add a small wave for leaves/grass based on coordinates.
    // Real OptiFine uses mc_Entity.x, here we use generic wave for animation
    
    gl_Position = gl_ModelViewProjectionMatrix * position;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color = gl_Color;
}
