/* gbuffers_water.vsh */

varying vec2 texcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;
varying vec3 worldPos;

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    vec4 viewSpaceOrigin = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewSpaceOrigin.xyz;
    
    // Convert to world space for waves
    worldPos = (gbufferModelViewInverse * viewSpaceOrigin).xyz; 
}
