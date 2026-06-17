#version 120

/*
 * gbuffers_terrain.fsh
 * Fragment shader for solid blocks
 */

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 color;
varying vec3 normal;

#include "/lib/common.glsl"

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    vec3 lightDir = vec3(0.5, 1.0, 0.3);
    
    // Apply basic lighting via the included helper
    albedo.rgb = applyBasicLighting(albedo.rgb, normal, lightDir, vec3(0.2), vec3(1.0));

    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(gl_Fog.color, albedo, fogFactor);
}
