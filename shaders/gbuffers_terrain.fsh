#version 120
/*
 * gbuffers_terrain.fsh
 * Fragment shader for solid blocks
 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;

// Calculates a simple Lambertian diffuse lighting factor.
float calculateDiffuse(vec3 normal, vec3 lightDir) {
    return max(dot(normalize(normal), normalize(lightDir)), 0.0);
}

// Oren-Nayar diffuse reflection model
float calculateOrenNayar(vec3 viewDir, vec3 lightDir, vec3 normal, float roughness) {
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float VdotL = dot(viewDir, lightDir);
    
    float s = VdotL - NdotL * NdotV;
    float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));
    
    float r2 = roughness * roughness;
    float A = 1.0 - 0.5 * (r2 / (r2 + 0.33));
    float B = 0.45 * (r2 / (r2 + 0.09));
    
    return NdotL * (A + B * s / t);
}

// Simple Blinn-Phong specular highlight
float calculateSpecular(vec3 viewDir, vec3 lightDir, vec3 normal, float shininess) {
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfDir), 0.0);
    return pow(NdotH, shininess);
}

// Compute shadow using shadow2D filtering (PCF)
float getShadow(sampler2D shadowtex, vec3 shadowCoord) {
    if (shadowCoord.z > 1.0 || shadowCoord.x < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
        return 1.0;
    }
    
    // Bias to prevent acne
    float bias = 0.001;
    float currentDepth = shadowCoord.z - bias;
    
    // 3x3 PCF sampling (with shadowMapResolution = 2048)
    float texelSize = 1.0 / 2048.0;
    float shadow = 0.0;
    
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            float pcfDepth = texture2D(shadowtex, shadowCoord.xy + vec2(float(x), float(y)) * texelSize).r;
            shadow += currentDepth > pcfDepth ? 0.0 : 1.0;
        }
    }
    return shadow / 9.0;
}

vec3 getShadowCoord(vec3 viewPos, mat4 gbufferModelViewInverse, mat4 shadowModelView, mat4 shadowProjection) {
    vec4 playerPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
    vec4 shadowViewPos = shadowModelView * playerPos;
    vec4 shadowClip = shadowProjection * shadowViewPos;
    return shadowClip.xyz / shadowClip.w * 0.5 + 0.5;
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Validate alpha to avoid shading transparent fragments
    if(albedo.a < 0.01) discard;
    
    // Light and view directions in view space
    vec3 sunDir = normalize(sunPosition);
    vec3 viewDir = normalize(-viewPos);
    vec3 upDir = normalize(upPosition);
    
    // Calculate sun elevation (-1 to 1)
    float sunElevation = dot(sunDir, upDir);
    vec3 lightDir = sunElevation > 0.0 ? sunDir : -sunDir;
    float timeBlend = clamp(abs(sunElevation) * 2.5, 0.0, 1.0); // 0 at dawn/dusk, 1 at noon/midnight
    
    // Day vs Night intensities
    float isDay = step(0.0, sunElevation);
    
    // Base colors based on time (Brighter!)
    vec3 daySunColor = mix(vec3(1.2, 0.7, 0.4), vec3(1.3, 1.25, 1.2), timeBlend);
    vec3 dayAmbient = mix(vec3(0.5, 0.4, 0.4), vec3(0.4, 0.6, 0.8), timeBlend);
    
    vec3 nightMoonColor = mix(vec3(0.1, 0.2, 0.4), vec3(0.3, 0.4, 0.6), timeBlend);
    vec3 nightAmbient = vec3(0.05, 0.1, 0.15); // Better night visibility
    
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
    float roughness = 0.8; // High roughness for dirt, grass
    float shininess = 16.0; // Low shininess
    float specularIntensity = 0.05; // Faint specular
    
    float diffuse = calculateOrenNayar(viewDir, lightDir, normal, roughness);
    diffuse = max(diffuse, 0.0);
    
    float specular = calculateSpecular(viewDir, lightDir, normal, shininess);
    
    // Shadows!
    vec3 shadowCoord = getShadowCoord(viewPos, gbufferModelViewInverse, shadowModelView, shadowProjection);
    float rawShadow = getShadow(shadowtex0, shadowCoord);
    float shadowFactor = mix(1.0, rawShadow, skyLight * 0.9); // Mostly apply shadow outdoors
    
    float shadowSmoothing = mix(1.0, shadowFactor, 0.8); // Softer shadows inside the lighted areas
    vec3 directionalLight = currentLightColor * diffuse * skyLight * shadowSmoothing;
    
    vec3 minAmbient = vec3(0.08, 0.08, 0.12);
    vec3 finalLight = max(ambientColor * skyLight, minAmbient) + directionalLight + currentTorchLight;
    
    albedo.rgb = albedo.rgb * finalLight + (currentLightColor * specular * specularIntensity * skyLight * shadowFactor);
    
    // Custom Sky-based fog depending on time of day
    vec3 fogColorDay = mix(daySunColor, vec3(0.5, 0.7, 1.0), 0.5);
    vec3 fogColorNight = nightAmbient;
    vec3 fogColor = mix(fogColorNight, fogColorDay, isDay);
    
    float viewDotLight = max(dot(viewDir, lightDir), 0.0);
    vec3 sunGlowColor = currentLightColor * pow(viewDotLight, 4.0);
    fogColor += sunGlowColor * 0.3 * skyLight; // only if we can see the sky
    
    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(vec4(fogColor, albedo.a), albedo, fogFactor);
}
