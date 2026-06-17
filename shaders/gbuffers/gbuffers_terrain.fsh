/*
 * gbuffers_terrain.fsh
 * Fragment shader for solid blocks
 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;

#include "/lib/common.glsl"

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Validate alpha to avoid shading transparent fragments
    if(albedo.a < 0.1) discard;
    
    // Light and view directions in view space
    vec3 sunDir = normalize(sunPosition);
    vec3 viewDir = normalize(-viewPos);
    vec3 upDir = normalize(upPosition);
    
    // Calculate sun elevation (-1 to 1)
    float sunElevation = dot(sunDir, upDir);
    
    vec3 lightDir = sunElevation > 0.0 ? sunDir : -sunDir;
    float timeBlend = clamp(abs(sunElevation) * 2.0, 0.0, 1.0);
    
    float isDay = step(0.0, sunElevation);
    
    vec3 daySunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.9), timeBlend);
    vec3 dayAmbient = mix(vec3(0.3, 0.2, 0.2), vec3(0.2, 0.4, 0.6), timeBlend);
    vec3 nightMoonColor = mix(vec3(0.1, 0.2, 0.4), vec3(0.2, 0.3, 0.5), timeBlend);
    vec3 nightAmbient = vec3(0.02, 0.04, 0.08);
    
    vec3 currentLightColor = mix(nightMoonColor, daySunColor, isDay);
    vec3 ambientColor = mix(nightAmbient, dayAmbient, isDay);
    
    vec3 torchColor = vec3(1.0, 0.6, 0.2);
    float torchIntensity = pow(lmcoord.x, 2.0);
    vec3 currentTorchLight = torchColor * torchIntensity * 2.5;
    
    float skyLight = pow(lmcoord.y, 2.0);
    
    // --- SHADOW MAPPING ---
    float shadow = 1.0;
    if (skyLight > 0.01) {
        // Convert viewPos to World Space, then to Shadow Space
        vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
        vec4 shadowSpacePos = shadowProjection * (shadowModelView * worldPos);
        vec3 shadowCoord = (shadowSpacePos.xyz / shadowSpacePos.w) * 0.5 + 0.5;
        
        if (shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && 
            shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0 && 
            shadowCoord.z >= 0.0 && shadowCoord.z <= 1.0) {
            
            float shadowDepth = texture2D(shadowtex0, shadowCoord.xy).r;
            float bias = 0.001 * tan(acos(clamp(dot(normal, lightDir), 0.0, 1.0)));
            bias = clamp(bias, 0.0005, 0.015);
            
            if (shadowDepth < shadowCoord.z - bias) {
                shadow = 0.0;
            }
        }
    }
    
    float diffuse = calculateOrenNayar(viewDir, lightDir, normal, 0.8) * shadow;
    diffuse = max(diffuse, 0.0);
    float specular = calculateSpecular(viewDir, lightDir, normal, 16.0) * shadow;
    
    vec3 directionalLight = currentLightColor * diffuse * skyLight;
    vec3 specularLight = currentLightColor * specular * 0.05 * skyLight;
    
    vec3 finalLight = (ambientColor * skyLight) + directionalLight + currentTorchLight;
    albedo.rgb = albedo.rgb * finalLight + specularLight;
    
    // Basic fog from distance
    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    vec3 fogColor = mix(nightAmbient, mix(daySunColor, vec3(0.5, 0.7, 1.0), 0.5), isDay);
    
    gl_FragColor = mix(vec4(fogColor, 1.0), albedo, fogFactor);
}
