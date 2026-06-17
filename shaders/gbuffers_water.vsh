#version 120
/* gbuffers_water.vsh */
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;
varying vec4 worldPos;

void main() {
    vec4 position = gl_Vertex;
    
    // Wave animation for water vertex height
    if(gl_Color.b > 0.8 && gl_Color.r < 0.2) {
        vec4 wPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
        float wave = sin(frameTimeCounter * 2.0 + wPos.x * 1.5 + wPos.z * 1.5) * 0.1;
        wave += cos(frameTimeCounter * 1.5 + wPos.x * 2.0 - wPos.z * 1.0) * 0.1;
        position.y += wave;
    }
    
    gl_Position = gl_ModelViewProjectionMatrix * position;
    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    
    vec4 viewSpaceOrigin = gl_ModelViewMatrix * position;
    viewPos = viewSpaceOrigin.xyz;
    worldPos = gbufferModelViewInverse * viewSpaceOrigin; // proper world pos
    
    gl_FogFragCoord = length(viewSpaceOrigin.xyz);
}
