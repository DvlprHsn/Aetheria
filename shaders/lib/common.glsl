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
