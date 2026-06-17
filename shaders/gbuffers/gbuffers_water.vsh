/* gbuffers_water.vsh */
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;
varying vec4 worldPos;

void main() {
    vec4 position = gl_Vertex;
    
    // Wave animation for water
    if(gl_Color.b > 0.8 && gl_Color.r < 0.2) {
        float wave = sin(frameTimeCounter * 2.0 + position.x * 0.5 + position.z * 0.5) * 0.1;
        wave += cos(frameTimeCounter * 1.5 + position.x * 0.8 - position.z * 0.4) * 0.1;
        position.y += wave;
    }
    
    gl_Position = gl_ModelViewProjectionMatrix * position;
    
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    
    vec4 viewSpaceOrigin = gl_ModelViewMatrix * position;
    viewPos = viewSpaceOrigin.xyz;
    worldPos = position;
    
    gl_FogFragCoord = length(viewSpaceOrigin.xyz);
}
