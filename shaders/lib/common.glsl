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
