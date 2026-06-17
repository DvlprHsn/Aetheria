/*
 * gbuffers_terrain.fsh
 * Fragment shader for solid blocks
 */

uniform sampler2D texture;
uniform vec3 sunPosition;

varying vec2 texcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;

#include "/lib/common.glsl"

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Light and view directions in view space
    vec3 lightDir = normalize(sunPosition);
    vec3 viewDir = normalize(-viewPos);
    
    // Configurable material properties for terrain
    float roughness = 0.8; // High roughness for dirt, stone, grass
    float shininess = 16.0; // Low shininess for diffuse surfaces
    float specularIntensity = 0.05; // Faint specular bump
    
    // Calculate Oren-Nayar diffuse
    float diffuse = calculateOrenNayar(viewDir, lightDir, normal, roughness);
    diffuse = max(diffuse, 0.2); // Minimum ambient light
    
    // Calculate simple specular
    float specular = calculateSpecular(viewDir, lightDir, normal, shininess);
    
    // Combine lighting
    vec3 sunColor = vec3(1.0, 0.95, 0.9);
    vec3 ambientColor = vec3(0.2, 0.25, 0.3);
    
    vec3 finalLight = mix(ambientColor, sunColor, diffuse);
    albedo.rgb = albedo.rgb * finalLight + (specular * specularIntensity * sunColor);

    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(gl_Fog.color, albedo, fogFactor);
}
