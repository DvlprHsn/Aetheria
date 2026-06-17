/* composite.fsh - Post-processing pass */

uniform sampler2D gcolor;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 texcoord;

#include "/lib/atmosphere.glsl"

// Compute view directory from screen coordinates
vec3 getViewDir(vec2 coord) {
    vec4 fragPos = vec4(coord * 2.0 - 1.0, 1.0, 1.0); // Depth = 1.0 for sky direction
    fragPos = gbufferProjectionInverse * fragPos;
    fragPos /= fragPos.w;
    vec3 viewDir = normalize((gbufferModelViewInverse * vec4(fragPos.xyz, 0.0)).xyz);
    return viewDir;
}

// Included from atmosphere.glsl

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;
    
    vec3 rayDir = getViewDir(texcoord);
    
    // OptiFine sunPosition is in View Space. We MUST convert it to World Space!
    vec3 sunDir = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
    
    // Prevent floating point precision loss at far coordinates which causes blurriness/blockiness
    vec3 rayOrigin = mod(cameraPosition, 100000.0);
    
    // Background sky color
    vec3 skyColor = getSkyColor(rayDir, sunDir);
    
    // Calculate world position for depth buffer
    float maxDist = 20000.0;
    float hitDist = maxDist;
    if (depth < 0.99999) {
        vec4 fragPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        fragPos = gbufferProjectionInverse * fragPos;
        fragPos /= fragPos.w;
        vec4 viewPos = gbufferModelViewInverse * fragPos;
        hitDist = length(viewPos.xyz);
        maxDist = hitDist;
    }
    
    // Render clouds
    vec4 clouds = renderClouds(rayOrigin, rayDir, sunDir, maxDist);
    
    // Blend final output
    vec3 finalColor = color.rgb;
    
    if (depth > 0.99999) {
        // Sky background
        finalColor = skyColor;
    }
    
    // Apply clouds over background or terrain
    finalColor = finalColor * (1.0 - clouds.a) + clouds.rgb;
    
    // Apply realistic fog over everything based on depth
    finalColor = applyFog(finalColor, hitDist, rayDir, sunDir, depth);
    
    // Output
    gl_FragColor = vec4(finalColor, 1.0);
}
