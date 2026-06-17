#version 120
/* gbuffers_skybasic.fsh */

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

varying vec3 viewPos;
varying vec4 color;

// Improved hash for stars
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Organic FBM noise for clouds
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float f = 0.0;
    f += 0.5000 * noise(p); p *= 2.02;
    f += 0.2500 * noise(p); p *= 2.03;
    f += 0.1250 * noise(p); p *= 2.01;
    f += 0.0625 * noise(p);
    return f / 0.9375;
}

void main() {
    vec3 viewDir = normalize(viewPos);
    
    // Transform to world space for sky
    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
    
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir = normalize(upPosition);
    
    float sunElevation = dot(sunDir, upDir);
    float isDay = step(0.0, sunElevation);
    float timeBlend = clamp(abs(sunElevation) * 2.5, 0.0, 1.0);
    
    vec3 daySunColor = mix(vec3(1.2, 0.7, 0.4), vec3(1.3, 1.25, 1.2), timeBlend);
    vec3 nightAmbient = vec3(0.05, 0.1, 0.15);
    
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
            starFactor = r * smoothstep(0.1, 0.3, horizonDot);
        }
    }
    
    vec3 finalColor = skyBase + vec3(starFactor) * (1.0 - timeBlend);
    
    // Round Sun and Moon!
    float sunDot = max(dot(viewDir, sunDir), 0.0);
    float moonDot = max(dot(viewDir, -sunDir), 0.0);
    
    // Smooth glow
    float glow = pow(sunDot, 16.0) * 0.5 + pow(sunDot, 64.0) * 2.0;
    float moonGlow = pow(moonDot, 16.0) * 0.3 + pow(moonDot, 64.0) * 0.5;
    
    finalColor += currentSunColor * glow * isDay;
    finalColor += vec3(0.4, 0.6, 0.8) * moonGlow * (1.0 - isDay);
    
    // Actual round disc for sun/moon
    if (sunDot > 0.999 && isDay > 0.5) finalColor += vec3(5.0); // Bright sun center
    if (moonDot > 0.9995 && isDay < 0.5) finalColor += vec3(2.0, 2.2, 2.5); // Moon disc
    
    // Realistic clouds!
    if (horizonDot > 0.02) {
        vec2 cloudPos = worldDir.xz / (worldDir.y + 0.001);
        cloudPos *= 2.0;
        cloudPos.x += frameTimeCounter * 0.05; // Wind
        
        float cloudNoise = fbm(cloudPos);
        float cloudDensity = smoothstep(0.4, 0.7, cloudNoise);
        
        if (cloudDensity > 0.0) {
            vec3 cloudColorDay = mix(vec3(1.0), daySunColor, 1.0 - horizonDot);
            vec3 cloudColorNight = vec3(0.1, 0.15, 0.2) + (moonGlow * vec3(0.1, 0.2, 0.3));
            vec3 clColor = mix(cloudColorNight, cloudColorDay, isDay);
            
            // Soften clouds near horizon
            float horizonFade = smoothstep(0.02, 0.15, horizonDot);
            finalColor = mix(finalColor, clColor, cloudDensity * horizonFade * 0.8);
        }
    }
    
    gl_FragColor = vec4(finalColor, 1.0);
}
