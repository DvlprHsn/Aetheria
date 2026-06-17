/* lib/lighting.glsl */

// Calculates a simple Lambertian diffuse lighting factor.
float calculateDiffuse(vec3 normal, vec3 lightDir) {
    return max(dot(normalize(normal), normalize(lightDir)), 0.0);
}

// Applies basic ambient and directional light
vec3 applyBasicLighting(vec3 albedo, vec3 normal, vec3 sunDir, vec3 ambientColor, vec3 sunColor) {
    float diffuse = calculateDiffuse(normal, sunDir);
    // Minimum ambient light ensures shadows aren't pitch black
    diffuse = max(diffuse, 0.2);
    
    return albedo * mix(ambientColor, sunColor, diffuse);
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
            float pcfDepth = texture2D(shadowtex, shadowCoord.xy + vec2(x, y) * texelSize).r;
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
