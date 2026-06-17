/*
 * gbuffers_terrain.fsh
 * Fragment shader for solid blocks
 */

uniform sampler2D texture;
uniform sampler2D lightmap;
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
    
    // Determine whether we are using sun or moon as primary directional light
    // In Optifine, sunPosition points to the sun. During night, sunElevation < 0.
    // We'll flip the light direction for the moon.
    vec3 lightDir = sunElevation > 0.0 ? sunDir : -sunDir;
    float timeBlend = clamp(abs(sunElevation) * 2.0, 0.0, 1.0); // 0 at dawn/dusk, 1 at noon/midnight
    
    // Day vs Night intensities
    float isDay = step(0.0, sunElevation);
    
    // Base colors based on time
    vec3 daySunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.9), timeBlend);
    vec3 dayAmbient = mix(vec3(0.3, 0.2, 0.2), vec3(0.2, 0.4, 0.6), timeBlend);
    
    vec3 nightMoonColor = mix(vec3(0.1, 0.2, 0.4), vec3(0.2, 0.3, 0.5), timeBlend);
    vec3 nightAmbient = vec3(0.02, 0.04, 0.08); // Very dark nights
    
    // Current sun/moon and ambient colors
    vec3 currentLightColor = mix(nightMoonColor, daySunColor, isDay);
    vec3 ambientColor = mix(nightAmbient, dayAmbient, isDay);
    
    // Torch lighting (block light)
    vec3 torchColor = vec3(1.0, 0.6, 0.2); // Warm orange
    float torchIntensity = pow(lmcoord.x, 2.0); // Non-linear falloff for realism
    vec3 currentTorchLight = torchColor * torchIntensity * 2.5;
    
    // Sky light strength (from lightmap, handles cave shadows!)
    float skyLight = pow(lmcoord.y, 2.0);
    
    // Configurable material properties for terrain
    float roughness = 0.8; // High roughness for dirt, stone, grass
    float shininess = 16.0; // Low shininess for diffuse surfaces
    float specularIntensity = 0.05; // Faint specular bump
    
    // Calculate Oren-Nayar diffuse
    float diffuse = calculateOrenNayar(viewDir, lightDir, normal, roughness);
    diffuse = max(diffuse, 0.0);
    
    // Calculate simple specular
    float specular = calculateSpecular(viewDir, lightDir, normal, shininess);
    
    // Directional light depends on sky visibility
    vec3 directionalLight = currentLightColor * diffuse * skyLight;
    
    // Specular highlight only where sunlight directly hits
    vec3 specularLight = currentLightColor * specular * specularIntensity * skyLight;
    
    // Final lighting = ambient + directional + torch
    vec3 finalLight = (ambientColor * skyLight) + directionalLight + currentTorchLight;
    
    // Apply lighting
    albedo.rgb = albedo.rgb * finalLight + specularLight;
    
    // Custom Sky-based fog depending on time of day
    vec3 fogColorDay = mix(daySunColor, vec3(0.5, 0.7, 1.0), 0.5);
    vec3 fogColorNight = nightAmbient;
    vec3 fogColor = mix(fogColorNight, fogColorDay, isDay);
    
    // Light scattering/glow around the sun setting (horizon)
    float viewDotLight = max(dot(viewDir, lightDir), 0.0);
    vec3 sunGlowColor = currentLightColor * pow(viewDotLight, 4.0);
    fogColor += sunGlowColor * 0.3 * skyLight; // only if we can see the sky
    
    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(vec4(fogColor, 1.0), albedo, fogFactor);
}
