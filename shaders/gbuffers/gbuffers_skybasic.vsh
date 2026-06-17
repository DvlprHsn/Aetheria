/* gbuffers_skybasic.vsh */

varying vec3 viewPos;
varying vec4 color;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    
    vec4 viewSpaceOrigin = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewSpaceOrigin.xyz;
    color = gl_Color;
    
    gl_FogFragCoord = gl_Position.z;
}
