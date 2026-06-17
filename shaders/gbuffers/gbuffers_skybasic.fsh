#version 120
/* gbuffers_skybasic.fsh */
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;

varying vec3 viewPos;
varying vec4 color;

// Improved hash for stars
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec3 viewDir = normalize(viewPos);
    
    // Transform to world space for sky
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir = normalize(upPosition);
    
    float sunElevation = dot(sunDir, upDir);
    float isDay = step(0.0, sunElevation);
    float timeBlend = clamp(abs(sunElevation) * 2.0, 0.0, 1.0);
    
    vec3 daySunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.9), timeBlend);
    vec3 nightAmbient = vec3(0.02, 0.04, 0.08);
    
    vec3 currentSunColor = mix(nightAmbient, daySunColor, isDay);
    
    vec3 fogColorDay = mix(daySunColor, vec3(0.2, 0.5, 1.0), 0.5); // Sky blue at zenith
    vec3 fogColorNight = nightAmbient;
    vec3 skyBase = mix(fogColorNight, fogColorDay, isDay);
    
    // Gradient based on horizon
    float horizonDot = max(dot(worldDir, upDir), 0.0);
    skyBase = mix(skyBase * 0.5, skyBase, horizonDot);
    
    // Stars
    float starFactor = 0.0;
    if (isDay < 0.5 && horizonDot > 0.1) {
        vec2 starPos = worldDir.xz / (worldDir.y + 0.001);
        float r = hash21(floor(starPos * 200.0));
        if (r > 0.99) {
            starFactor = r;
        }
    }
    
    // Sky color with stars
    vec3 finalColor = skyBase + vec3(starFactor) * (1.0 - timeBlend);
    
    // Sun / Moon Glow
    float sunDot = max(dot(viewDir, sunDir), 0.0);
    float glow = pow(sunDot, 16.0) * 0.5 + pow(sunDot, 64.0) * 2.0;
    
    finalColor += currentSunColor * glow;
    
    // Draw the actual sun (or moon based on Optifine color input)
    // if using gl_color from optifine it contains the sun/moon disc
    finalColor.rgb = mix(finalColor.rgb, color.rgb, color.a);
    
    gl_FragColor = vec4(finalColor, 1.0);
}
