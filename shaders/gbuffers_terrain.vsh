#version 120
/*
 * gbuffers_terrain.vsh
 * Main geometry pass for blocks
 */
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;

void main() {
    vec4 position = gl_Vertex;
    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    
    // Waving leaves, vines, and grass!
    // Using color alpha or specific texcoords or green tint to guess foliage
    // Optifine's standard way without passing block ID is to use color
    if (color.r < color.g && color.b < color.g && normal.y > 0.5) {
        // Simple wind simulation
        vec4 worldPos = gbufferModelViewInverse * gl_ModelViewMatrix * position;
        float wave = sin(frameTimeCounter * 2.0 + worldPos.x + worldPos.z) * 0.05;
        position.x += wave;
        position.z += wave * 0.5;
    }
    
    gl_Position = gl_ModelViewProjectionMatrix * position;
    
    vec4 viewSpaceOrigin = gl_ModelViewMatrix * position;
    viewPos = viewSpaceOrigin.xyz;
    
    gl_FogFragCoord = length(viewSpaceOrigin.xyz);
}
