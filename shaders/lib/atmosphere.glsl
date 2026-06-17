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

// --- WEATHER & TIME PROFILES ---
// Weight function for time of day (circular 0-24000)
float getPhaseWeight(float t, float center, float width) {
    float diff = abs(t - center);
    if(diff > 12000.0) diff = 24000.0 - diff;
    return max(0.0, 1.0 - diff / width);
}

struct TimeProfile {
    float dawn;
    float morning;
    float day;
    float sunset;
    float night;
    float midnight;
};

TimeProfile getTimeProfile() {
    float t = float(worldTime);
    TimeProfile tp;
    tp.dawn = getPhaseWeight(t, 23500.0, 1500.0);
    tp.morning = getPhaseWeight(t, 2500.0, 2000.0);
    tp.day = getPhaseWeight(t, 6000.0, 3000.0);
    tp.sunset = getPhaseWeight(t, 12500.0, 1500.0);
    tp.night = getPhaseWeight(t, 16000.0, 2000.0) + getPhaseWeight(t, 20000.0, 2000.0);
    tp.midnight = getPhaseWeight(t, 18000.0, 2000.0);
    
    // Normalize safely
    float total = tp.dawn + tp.morning + tp.day + tp.sunset + tp.night + tp.midnight;
    if (total > 0.0) {
        tp.dawn /= total; tp.morning /= total; tp.day /= total;
        tp.sunset /= total; tp.night /= total; tp.midnight /= total;
    } else {
        tp.day = 1.0;
    }
    return tp;
}

// --- SKY RENDERING ---
vec3 getSkyColor(vec3 rayDir, vec3 sunDir) {
    TimeProfile tp = getTimeProfile();
    float isThunder = max(0.0, wetness * 1.5 - 0.5); // Emulate thunder phase from extreme wetness
    float rainFade = clamp(wetness * 2.0, 0.0, 1.0);
    
    // Clear Sky Colors
    vec3 skyDay = vec3(0.15, 0.35, 0.75);
    vec3 horizDay = vec3(0.55, 0.7, 0.9);
    
    vec3 skyMorning = vec3(0.2, 0.3, 0.65);
    vec3 horizMorning = vec3(0.75, 0.6, 0.65);
    
    vec3 skyDawn = vec3(0.25, 0.15, 0.35);
    vec3 horizDawn = vec3(1.0, 0.35, 0.1); 
    
    vec3 skyNight = vec3(0.015, 0.02, 0.05);
    vec3 horizNight = vec3(0.02, 0.04, 0.1);
    
    vec3 skyMidnight = vec3(0.005, 0.005, 0.015);
    vec3 horizMidnight = vec3(0.01, 0.01, 0.03);
    
    // Stormy / Rainy Sky Colors
    vec3 stormSkyDay = vec3(0.25, 0.28, 0.32);
    vec3 stormHorizDay = vec3(0.35, 0.38, 0.42);
    vec3 thunderSkyDay = vec3(0.1, 0.12, 0.15); // Dark greenish-grey
    vec3 thunderHorizDay = vec3(0.15, 0.18, 0.2);
    
    vec3 stormSkyNight = vec3(0.01, 0.01, 0.02);
    vec3 stormHorizNight = vec3(0.02, 0.02, 0.03);
    
    // Mix clear sky by time
    vec3 clearSky = skyDawn * tp.dawn + skyMorning * tp.morning + skyDay * tp.day + skyDawn * tp.sunset + skyNight * tp.night + skyMidnight * tp.midnight;
    vec3 clearHoriz = horizDawn * tp.dawn + horizMorning * tp.morning + horizDay * tp.day + horizDawn * tp.sunset + horizNight * tp.night + horizMidnight * tp.midnight;
    
    // Mix rainy sky
    float dayNightMix = clamp(tp.dawn + tp.morning + tp.day + tp.sunset, 0.0, 1.0);
    vec3 rainSky = mix(stormSkyNight, stormSkyDay, dayNightMix);
    vec3 rainHoriz = mix(stormHorizNight, stormHorizDay, dayNightMix);
    
    vec3 thundSky = mix(stormSkyNight, thunderSkyDay, dayNightMix);
    vec3 thundHoriz = mix(stormHorizNight, thunderHorizDay, dayNightMix);
    
    vec3 finalStormSky = mix(rainSky, thundSky, isThunder);
    vec3 finalStormHoriz = mix(rainHoriz, thundHoriz, isThunder);
    
    // Mix clear and storm by wetness
    vec3 finalSky = mix(clearSky, finalStormSky, rainFade);
    vec3 finalHoriz = mix(clearHoriz, finalStormHoriz, rainFade);
    
    // Elevation mix
    float elevation = max(0.0, rayDir.y);
    float horizonMix = pow(1.0 - elevation, 4.0);
    vec3 baseCol = mix(finalSky, finalHoriz, horizonMix);
    
    // Stars at night
    float nightLevel = tp.night + tp.midnight;
    if (nightLevel > 0.0 && rayDir.y > 0.0) {
        float starVal = hash(rayDir * 200.0);
        float starIntensity = pow(starVal, 250.0) * nightLevel * (1.0 - rainFade); // No stars during storm
        baseCol += vec3(starIntensity);
    }
    
    // Sun and Moon Discs
    float cosThetaSun = dot(rayDir, sunDir);
    float sunDisc = smoothstep(0.9998, 0.9999, cosThetaSun);
    float dayLevel = tp.morning + tp.day + tp.sunset + tp.dawn;
    float sunGlow = pow(max(0.0, cosThetaSun), 150.0) * dayLevel;
    float sunCorona = pow(max(0.0, cosThetaSun), 40.0) * dayLevel * 0.5;
    
    vec3 sunDiscColor = mix(vec3(2.5, 2.3, 1.8), vec3(2.0, 0.5, 0.05), tp.dawn + tp.sunset);
    
    float cosThetaMoon = dot(rayDir, -sunDir);
    float moonDisc = smoothstep(0.9997, 0.9998, cosThetaMoon);
    float moonGlow = pow(max(0.0, cosThetaMoon), 100.0) * nightLevel;
    float moonCorona = pow(max(0.0, cosThetaMoon), 30.0) * nightLevel * 0.3;
    
    baseCol += vec3(sunGlow + sunCorona) * mix(vec3(1.1, 1.1, 1.0), vec3(1.5, 0.4, 0.1), tp.dawn + tp.sunset) * (1.0 - rainFade);
    baseCol = mix(baseCol, sunDiscColor, sunDisc * dayLevel * (1.0 - rainFade));
    
    baseCol += vec3(moonGlow + moonCorona) * vec3(0.6, 0.7, 0.9) * (1.0 - rainFade);
    baseCol = mix(baseCol, vec3(1.0, 1.0, 1.2), moonDisc * nightLevel * (1.0 - rainFade));
    
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
    
    // High-level clouds (above 6000m) 
    float height = 6000.0;
    float t = intersectPlane(rayOrigin, rayDir, height);
    if (t < 0.0 || t > 50000.0) return vec4(0.0);
    
    vec3 p = rayOrigin + rayDir * t;
    vec3 samplePos = p * 0.0001; // Wide scale
    samplePos.x += frameTimeCounter * 0.001;
    
    // 1. Cirrus: Fibrous, hair-like
    float typeCirrus = fbm_cirrus(samplePos);
    // 2. Cirrocumulus: Small ripples, grains
    float typeCirrocumulus = fbm_ripples(samplePos * 1.5);
    // 3. Cirrostratus: Transparent, whitish veil
    float typeCirrostratus = smoothstep(0.2, 0.8, fbm(samplePos * 0.5));
    
    // Storm approach / weather decides which high clouds to show
    float stormApproach = clamp(wetness * 2.0, 0.0, 1.0); 
    
    float noiseVal = mix(typeCirrus, typeCirrocumulus, stormApproach);
    noiseVal = mix(noiseVal, typeCirrostratus, smoothstep(0.5, 1.0, stormApproach));
    
    float density = smoothstep(0.4, 0.7, noiseVal) * 0.4;
    
    if (density <= 0.0) return vec4(0.0);
    
    TimeProfile tp = getTimeProfile();
    float dayLevel = tp.morning + tp.day + tp.sunset + tp.dawn;
    float nightLevel = tp.night + tp.midnight;
    
    vec3 cloudCol = vec3(1.0);
    cloudCol = mix(cloudCol, vec3(1.0, 0.5, 0.2), tp.dawn + tp.sunset);
    cloudCol = mix(cloudCol, vec3(0.05, 0.08, 0.12), nightLevel);
    
    return vec4(cloudCol * density, density * (1.0 - wetness)); 
}

vec4 renderVolumetricClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float maxDist) {
    TimeProfile tp = getTimeProfile();
    float isThunder = max(0.0, wetness * 1.5 - 0.5);
    
    // Cloud boundaries
    // Mid-level (2000-6000m): Altocumulus, Altostratus
    // Low-level (<2000m): Stratus, Stratocumulus, Nimbostratus
    // Vertical: Cumulus, Cumulonimbus
    float cloudMinHeight = 800.0;
    float cloudMaxHeight = mix(2500.0, 5000.0, wetness); // Thunder/Rain clouds grow vertically (Cumulonimbus)
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
    tMax = min(tMax, tMin + 20000.0);
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
        
        vec3 samplePos = p * 0.002;
        samplePos.x += frameTimeCounter * 0.01;
        float baseNoise = fbm(samplePos);
        float detailNoise = fbm(samplePos * 3.0);
        
        // --- 10 GENERA CLOUD PROFILES ---
        float cloudCoverage = fbm(p * 0.0003 - vec3(frameTimeCounter * 0.005, 0, 0));
        
        // Mid-Level Clouds
        // 4. Altocumulus: Rounded patches
        float altocumulus = fbm_ripples(samplePos * 0.8) - 0.5 + cloudCoverage;
        // 5. Altostratus: Featureless, grey sheet
        float altostratus = baseNoise - detailNoise * 0.05 + 0.1;
        
        // Low-Level Clouds
        // 6. Stratus: Uniform featureless layer
        float stratus = baseNoise - detailNoise * 0.05;
        // 7. Stratocumulus: Globular, rolled
        float stratocumulus = baseNoise - abs(detailNoise * 0.3) - 0.2 + cloudCoverage * 0.5;
        // 8. Nimbostratus: Dark rain-bearing sheet
        float nimbostratus = baseNoise - detailNoise * 0.1 + 0.3;
        
        // Vertical Development Clouds
        // 9. Cumulus: Puffy, cotton-like
        float cumulus = baseNoise - detailNoise * 0.2 - 0.6 + cloudCoverage * 0.8;
        // 10. Cumulonimbus: Massive, thunder-bearing
        float cumulonimbus = baseNoise - detailNoise * 0.15 + cloudCoverage * 0.4;
        
        // Combine Genera based on Weather Profile
        // Sunny/Clear: Cumulus + Stratocumulus
        float genSunny = mix(cumulus, stratocumulus, 0.3);
        // Rain Approaching: Altostratus + Altocumulus + Stratus
        float genMid = mix(altostratus, altocumulus, 0.5);
        // Rain/Thunder: Cumulonimbus + Nimbostratus + Stratus
        float genStorm = mix(mix(cumulonimbus, nimbostratus, 0.5), stratus, 0.2);
        
        float n = mix(mix(genSunny, genMid, clamp(wetness * 2.0, 0.0, 1.0)), genStorm, wetness);
        
        // Vertical shaping limits
        float bottomRound = mix(0.1, 0.01, wetness); 
        float topWispy = mix(0.4, 0.8, wetness);
        float verticalGradient = smoothstep(0.0, bottomRound, heightFrac) * smoothstep(1.0, topWispy, heightFrac);
        
        float density = n * verticalGradient;
        
        if (density > 0.0) {
            density *= mix(4.0, 25.0, wetness); // Immensely dense storms
            
            // Self shadowing
            vec3 lightStep = lightDir * mix(40.0, 15.0, wetness);
            vec3 lP = p + lightStep;
            float lHeightFrac = clamp((lP.y - cloudMinHeight) / cloudThickness, 0.0, 1.0);
            float densSun = (fbm(lP * 0.002) - 0.4) * smoothstep(0.0, bottomRound, lHeightFrac);
            densSun = mix(max(0.0, densSun), max(0.0, densSun + 0.5), wetness); 
            
            float lightTransmittance = exp(-densSun * mix(2.0, 8.0, wetness)); 
            
            float powder = 1.0 - exp(-density * 2.0);
            
            // Coloring
            vec3 dayAmbient = mix(mix(vec3(0.5, 0.55, 0.6), vec3(0.8, 0.85, 0.9), heightFrac), vec3(0.15, 0.18, 0.22), wetness);
            vec3 nightAmbient = mix(vec3(0.015, 0.02, 0.025), vec3(0.03, 0.04, 0.05), wetness);
            vec3 dawnAmbient = vec3(0.3, 0.2, 0.25);
            vec3 morningAmbient = vec3(0.4, 0.35, 0.4);
            vec3 sunsetAmbient = vec3(0.4, 0.25, 0.2);
            vec3 midnightAmbient = vec3(0.005, 0.005, 0.01);
            
            vec3 ambient = dayAmbient * tp.day + nightAmbient * tp.night + dawnAmbient * tp.dawn + morningAmbient * tp.morning + sunsetAmbient * tp.sunset + midnightAmbient * tp.midnight;
            
            vec3 dayDirect = mix(vec3(1.1, 1.05, 1.0), vec3(0.3, 0.35, 0.4), wetness);
            vec3 nightDirect = vec3(0.05, 0.08, 0.12);
            vec3 dawnDirect = vec3(1.2, 0.4, 0.1);
            vec3 morningDirect = vec3(1.1, 0.8, 0.5);
            vec3 sunsetDirect = vec3(1.2, 0.4, 0.05);
            vec3 midnightDirect = vec3(0.01, 0.02, 0.04);
            
            vec3 directColor = dayDirect * tp.day + nightDirect * tp.night + dawnDirect * tp.dawn + morningDirect * tp.morning + sunsetDirect * tp.sunset + midnightDirect * tp.midnight;
            
            vec3 cloudColor = ambient + directColor * lightTransmittance * powder * (1.0 + phase * 2.5);
            
            // Emulate slight lightning flashes in heavy thunder
            if (isThunder > 0.5) {
                float flash = pow(max(0.0, sin(frameTimeCounter * 5.0) * sin(frameTimeCounter * 2.3) * sin(frameTimeCounter * 11.0)), 15.0);
                cloudColor += vec3(0.8, 0.9, 1.0) * flash * 2.0;
            }
            
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

