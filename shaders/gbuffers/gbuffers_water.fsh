/* gbuffers_water.fsh */

varying vec2 texcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;
varying vec3 worldPos;

uniform sampler2D texture;
uniform float frameTimeCounter;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Wave generation
    float time = frameTimeCounter * 1.5;
    float wave1 = sin(worldPos.x * 2.0 + time) * cos(worldPos.z * 2.0 + time);
    float wave2 = sin(worldPos.x * 5.0 - time * 0.8) * cos(worldPos.z * 4.0 + time * 1.2);
    
    float wave = wave1 * 0.5 + wave2 * 0.2;
    
    // Pseudo normal from wave
    vec3 wNormal = normalize(vec3(wave * 0.1, 1.0, wave * 0.1));
    
    // Fake Fresnel effect for reflections (since we process this in gbuffers, we approximate the reflection later in composite, or just make it nice and blue-ish here)
    vec3 viewDir = normalize(-viewPos);
    float fresnel = pow(1.0 - max(dot(wNormal, viewDir), 0.0), 3.0);
    
    vec3 waterColor = mix(vec3(0.05, 0.2, 0.4), vec3(0.2, 0.5, 0.6), fresnel);
    
    // Alpha adjusts with fresnel to be more opaque at glancing angles
    float alpha = mix(0.6, 0.9, fresnel);
    
    gl_FragColor = vec4(waterColor, alpha);
}
