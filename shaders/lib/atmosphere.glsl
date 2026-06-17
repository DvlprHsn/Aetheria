/* atmosphere.glsl - Atmospheric scattering, sky, clouds, and fog */

// --- NOISE FUNCTIONS ---
// Hash and Noise functions for "foamy" volume clouds
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
                   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float f = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for(int i = 0; i < 5; i++) {
        f += amp * noise(p * freq);
        freq *= 2.02;
        amp *= 0.5;
    }
    return f;
}

// Stretched FBM for Cirrus
float fbm_cirrus(vec3 p) {
    p.x *= 0.2; // Stretch along wind direction
    p.z *= 0.8;
    return fbm(p);
}

// Ripple FBM for Altocumulus / Cirrocumulus
float fbm_ripples(vec3 p) {
    p *= 3.0; // Higher frequency
    float n = fbm(p);
    return abs(n * 2.0 - 1.0); // Ridged noise
}

// --- ATMOSPHERIC OPTICS ---
uniform float wetness;
uniform int worldTime;

// Henyey-Greenstein phase function for realistic cloud scattering
float phaseHenyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

// --- SKY RENDERING ---
// Time of Day Profiles
float getMorningFactor(float sunHeight) {
    return smoothstep(0.0, 0.2, sunHeight) * smoothstep(0.4, 0.2, sunHeight);
}
float getDawnFactor(float sunHeight) {
    return smoothstep(-0.1, 0.05, sunHeight) * smoothstep(0.1, -0.05, sunHeight);
}
float getDayFactor(float sunHeight) {
    return smoothstep(0.1, 0.3, sunHeight);
}

vec3 getSkyColor(vec3 rayDir, vec3 sunDir) {
    float sunHeight = sunDir.y;
    
    // Base time factors
    float dayF = getDayFactor(sunHeight);
    float dawnF = getDawnFactor(sunHeight);
    float morningF = getMorningFactor(sunHeight);
    float nightF = 1.0 - smoothstep(-0.1, 0.1, sunHeight);
    
    // Clear Sky Colors
    vec3 skyDay = vec3(0.12, 0.3, 0.7);
    vec3 horizDay = vec3(0.6, 0.75, 0.9);
    
    vec3 skyMorning = vec3(0.15, 0.25, 0.6);
    vec3 horizMorning = vec3(0.8, 0.6, 0.7);
    
    vec3 skyDawn = vec3(0.2, 0.1, 0.3);
    vec3 horizDawn = vec3(1.0, 0.3, 0.05); // Sunset / Dawn
    
    vec3 skyNight = vec3(0.01, 0.015, 0.04);
    vec3 horizNight = vec3(0.02, 0.03, 0.08);
    
    // Stormy Sky Colors (Rain/Thunder)
    vec3 stormSkyDay = vec3(0.25, 0.28, 0.32);
    vec3 stormHorizDay = vec3(0.35, 0.38, 0.42);
    
    vec3 stormSkyNight = vec3(0.01, 0.01, 0.02);
    vec3 stormHorizNight = vec3(0.02, 0.02, 0.03);
    
    // Blend times for clear
    vec3 clearSky = skyNight * nightF + skyDawn * dawnF + skyMorning * morningF + skyDay * dayF;
    vec3 clearHoriz = horizNight * nightF + horizDawn * dawnF + horizMorning * morningF + horizDay * dayF;
    
    // Blend times for storm
    float dayStorm = clamp(dayF + morningF + dawnF, 0.0, 1.0);
    vec3 stormSky = mix(stormSkyNight, stormSkyDay, dayStorm);
    vec3 stormHoriz = mix(stormHorizNight, stormHorizDay, dayStorm);
    
    // Mix clear and storm by wetness
    vec3 finalSky = mix(clearSky, stormSky, wetness);
    vec3 finalHoriz = mix(clearHoriz, stormHoriz, wetness);
    
    // Elevation mix
    float elevation = max(0.0, rayDir.y);
    float horizonMix = pow(1.0 - elevation, 4.0);
    vec3 baseCol = mix(finalSky, finalHoriz, horizonMix);
    
    // Stars at night
    if (nightF > 0.0 && rayDir.y > 0.0) {
        float starVal = hash(rayDir * 200.0);
        float starIntensity = pow(starVal, 250.0) * nightF * (1.0 - wetness); // No stars during storm
        baseCol += vec3(starIntensity);
    }
    
    // Sun and Moon Discs
    float cosThetaSun = dot(rayDir, sunDir);
    float sunDisc = smoothstep(0.9998, 0.9999, cosThetaSun);
    float sunGlow = pow(max(0.0, cosThetaSun), 200.0) * (1.0 - nightF);
    float sunCorona = pow(max(0.0, cosThetaSun), 40.0) * (1.0 - nightF) * 0.5;
    
    vec3 sunDiscColor = mix(vec3(2.5, 2.3, 1.8), vec3(2.0, 0.8, 0.2), dawnF);
    
    float cosThetaMoon = dot(rayDir, -sunDir);
    float moonDisc = smoothstep(0.9997, 0.9998, cosThetaMoon);
    float moonGlow = pow(max(0.0, cosThetaMoon), 100.0) * nightF;
    float moonCorona = pow(max(0.0, cosThetaMoon), 30.0) * nightF * 0.3;
    
    baseCol += vec3(sunGlow + sunCorona) * mix(vec3(1.2, 1.1, 0.9), vec3(1.5, 0.4, 0.1), dawnF) * (1.0 - wetness);
    baseCol = mix(baseCol, sunDiscColor, sunDisc * (1.0 - nightF) * (1.0 - wetness));
    
    baseCol += vec3(moonGlow + moonCorona) * vec3(0.5, 0.6, 0.8) * (1.0 - wetness);
    baseCol = mix(baseCol, vec3(0.9, 0.95, 1.1), moonDisc * nightF * (1.0 - wetness));
    
    return baseCol;
}

// Intersect a ray with a horizontal plane at `height`
float intersectPlane(vec3 rayOrigin, vec3 rayDir, float height) {
    if(rayDir.y == 0.0) return -1.0;
    float t = (height - rayOrigin.y) / rayDir.y;
    return t;
}

// High-Level clouds (Cirrus, Cirrocumulus, Cirrostratus) rendered as a 2D plane for crisp detail
vec4 renderHighClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir) {
    if (rayDir.y <= 0.01) return vec4(0.0);
    
    float height = 600.0; // High altitude above volumetric
    float t = intersectPlane(rayOrigin, rayDir, height);
    if (t < 0.0 || t > 10000.0) return vec4(0.0);
    
    vec3 p = rayOrigin + rayDir * t;
    vec3 samplePos = p * 0.0002;
    samplePos.x += frameTimeCounter * 0.002;
    
    // Choose high cloud type based on weather approach
    // Sunny = Cirrus
    // Pre-rain (wetness starting) = Cirrostratus / Cirrocumulus
    float typeCirrus = fbm_cirrus(samplePos);
    float typeCirrocumulus = fbm_ripples(samplePos);
    float typeCirrostratus = smoothstep(0.2, 0.8, fbm(samplePos * 0.5)); // broad veil
    
    float stormApproach = clamp(wetness * 2.0, 0.0, 1.0); // 0 to 1 as rain approaches
    
    float noiseVal = mix(typeCirrus, typeCirrocumulus, stormApproach);
    noiseVal = mix(noiseVal, typeCirrostratus, smoothstep(0.5, 1.0, stormApproach));
    
    float density = smoothstep(0.4, 0.7, noiseVal) * 0.5; // Thin
    
    if (density <= 0.0) return vec4(0.0);
    
    // Lighting
    float sunHeight = sunDir.y;
    float dawnF = getDawnFactor(sunHeight);
    float nightF = 1.0 - smoothstep(-0.1, 0.1, sunHeight);
    
    vec3 cloudCol = vec3(1.0);
    cloudCol = mix(cloudCol, vec3(1.0, 0.5, 0.2), dawnF); // dawn colors
    cloudCol = mix(cloudCol, vec3(0.05, 0.08, 0.12), nightF); // night colors
    
    return vec4(cloudCol * density, density * (1.0 - wetness)); // Fade out out fully rainy
}

// Raymarching volumetric 3D clouds (Low & Mid level, Vertical Development)
// Handles: Stratus, Stratocumulus, Nimbostratus, Altocumulus, Altostratus, Cumulus, Cumulonimbus
vec4 renderVolumetricClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float maxDist) {
    float sunHeight = sunDir.y;
    float dayF = getDayFactor(sunHeight);
    float dawnF = getDawnFactor(sunHeight);
    float morningF = getMorningFactor(sunHeight);
    float nightF = 1.0 - smoothstep(-0.1, 0.1, sunHeight);
    
    // Cloud boundaries
    float cloudMinHeight = 100.0;
    float cloudMaxHeight = mix(250.0, 500.0, wetness); // Thunder/Rain clouds grow vertically (Cumulonimbus)
    float cloudThickness = cloudMaxHeight - cloudMinHeight;
    
    float tMin = intersectPlane(rayOrigin, rayDir, cloudMinHeight);
    float tMax = intersectPlane(rayOrigin, rayDir, cloudMaxHeight);
    
    if (rayDir.y > 0.0) {
        if (tMin < 0.0) tMin = 0.0;
        if (tMax < 0.0) return vec4(0.0);
    } else {
        if (tMin < 0.0) return vec4(0.0);
        if (tMax < 0.0) tMax = 0.0;
        float tmp = tMin; tMin = tMax; tMax = tmp;
    }
    
    if (tMin > maxDist) return vec4(0.0);
    tMax = min(tMax, maxDist);
    tMax = min(tMax, tMin + 3500.0);
    if (tMax < tMin) return vec4(0.0);
    
    float t = tMin;
    float stepSize = (tMax - tMin) / 80.0; 
    
    vec2 coord = gl_FragCoord.xy;
    float dither = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453) * stepSize;
    t += dither;
    
    vec4 sum = vec4(0.0);
    
    vec3 lightDir = sunDir.y > 0.0 ? sunDir : -sunDir;
    float cosTheta = dot(rayDir, lightDir);
    float phase = mix(phaseHenyeyGreenstein(cosTheta, 0.7), phaseHenyeyGreenstein(cosTheta, -0.4), 0.3);
    
    for(int i = 0; i < 80; i++) {
        if (t >= tMax || sum.a >= 0.99) break;
        
        vec3 p = rayOrigin + rayDir * t;
        float heightFrac = clamp((p.y - cloudMinHeight) / cloudThickness, 0.0, 1.0);
        
        // Profiles for genera
        vec3 samplePos = p * 0.003;
        samplePos.x += frameTimeCounter * 0.01;
        
        float baseNoise = fbm(samplePos);
        float detailNoise = fbm(samplePos * 4.0);
        
        // Genus: Cumulus (Sunny, low altitude)
        float cumulus = baseNoise - detailNoise * 0.2;
        float cumulusCoverage = fbm(p * 0.0005 - vec3(0, 0, frameTimeCounter * 0.005));
        cumulus = (cumulus - 0.7 + cumulusCoverage * 0.5);
        // Genus: Stratocumulus (Sunny/Cloudy, wider flat bases)
        float stratoCumulus = baseNoise - abs(detailNoise * 0.3) - 0.3;
        // Genus: Nimbostratus / Cumulonimbus (Rainy, solid, tall)
        float nimboStratus = baseNoise - detailNoise * 0.1 + 0.3; // Very dense
        
        // Blend Genera based on weather
        // wetness 0.0: Cumulus / Stratocumulus
        // wetness 0.5: Altostratus transition
        // wetness 1.0: Cumulonimbus (towering) & Nimbostratus
        
        float n = mix(mix(cumulus, stratoCumulus, 0.3), nimboStratus, wetness);
        
        // Vertical shaping
        float bottomRound = mix(0.1, 0.01, wetness); // Flat bottom for storm, rounded for strato
        float topWispy = mix(0.4, 0.8, wetness);
        float verticalGradient = smoothstep(0.0, bottomRound, heightFrac) * smoothstep(1.0, topWispy, heightFrac);
        
        float density = n * verticalGradient;
        
        if (density > 0.0) {
            density *= mix(6.0, 20.0, wetness); // Immensely dense storms
            
            // Self shadowing
            vec3 lightStep = lightDir * (mix(30.0, 15.0, wetness));
            vec3 lP = p + lightStep;
            float lHeightFrac = clamp((lP.y - cloudMinHeight) / cloudThickness, 0.0, 1.0);
            float densSun = (fbm(lP * 0.003) - 0.4) * smoothstep(0.0, bottomRound, lHeightFrac);
            densSun = mix(max(0.0, densSun), max(0.0, densSun + 0.5), wetness); // Thicker shadow in storm
            
            float lightTransmittance = exp(-densSun * mix(2.0, 8.0, wetness)); 
            
            float powder = 1.0 - exp(-density * 2.0);
            
            // Coloring
            vec3 dayAmbient = mix(mix(vec3(0.4, 0.45, 0.5), vec3(0.6, 0.65, 0.7), heightFrac), vec3(0.15, 0.18, 0.22), wetness);
            vec3 nightAmbient = mix(vec3(0.01, 0.015, 0.02), vec3(0.03, 0.04, 0.05), wetness);
            vec3 dawnAmbient = vec3(0.3, 0.2, 0.25);
            
            vec3 ambient = dayAmbient * dayF + nightAmbient * nightF + dawnAmbient * dawnF + dayAmbient * morningF;
            
            vec3 dayDirect = mix(vec3(1.1, 1.05, 1.0), vec3(0.3, 0.35, 0.4), wetness);
            vec3 nightDirect = vec3(0.05, 0.08, 0.12);
            vec3 dawnDirect = vec3(1.2, 0.4, 0.1);
            vec3 morningDirect = vec3(1.1, 0.8, 0.5);
            
            vec3 directColor = dayDirect * dayF + nightDirect * nightF + dawnDirect * dawnF + morningDirect * morningF;
            
            vec3 cloudColor = ambient + directColor * lightTransmittance * powder * (1.0 + phase * 2.5);
            
            vec4 col = vec4(cloudColor * density, density);
            sum += col * (1.0 - sum.a);
        }
        t += stepSize;
    }
    
    return sum;
}

// --- MAIN CLOUD ALLOCATOR ---
// Blends high clouds and volumetric clouds seamlessly
vec4 renderAtmosphereClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float maxDist) {
    vec4 volClouds = renderVolumetricClouds(rayOrigin, rayDir, sunDir, maxDist);
    // Apply high clouds behind volumetric clouds
    vec4 highClouds = renderHighClouds(rayOrigin, rayDir, sunDir);
    
    // Blend high clouds over nothing, then volumetric over that
    vec4 combined = highClouds;
    combined = volClouds + combined * (1.0 - volClouds.a);
    return combined;
}

// --- FOG RENDERING ---
vec3 applyFog(vec3 color, float dist, vec3 rayDir, vec3 sunDir, float depth) {
    float fogDensity = mix(0.002, 0.009, wetness); // Foggy mornings & storms
    
    if (depth > 0.99999) {
        float elevation = max(0.0, rayDir.y);
        fogDensity *= exp(-elevation * 10.0);
    }
    
    float fogFactor = 1.0 - exp(-dist * fogDensity);
    
    vec3 skyHorizon = getSkyColor(vec3(rayDir.x, 0.0, rayDir.z), sunDir);
    
    // Fog color is mostly the horizon sky color
    return mix(color, skyHorizon, fogFactor);
}

