/*
 * gbuffers_terrain.vsh
 * Main geometry pass for blocks
 */

varying vec2 texcoord;
varying vec4 color;
varying vec3 normal;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    gl_FogFragCoord = length((gl_ModelViewMatrix * gl_Vertex).xyz);
}
