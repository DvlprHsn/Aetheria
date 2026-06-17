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

// --- ATMOSPHERIC OPTICS ---
uniform float wetness;

// Henyey-Greenstein phase function for realistic cloud scattering
float phaseHenyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

// --- SKY RENDERING ---
vec3 getSkyColor(vec3 rayDir, vec3 sunDir) {
    vec3 skyBlue = vec3(0.12, 0.3, 0.7);
    vec3 horizonColor = vec3(0.6, 0.75, 0.9); // bright near horizon
    vec3 sunsetColor = vec3(1.0, 0.3, 0.05);
    
    float sunHeight = sunDir.y;
    
    // Day/Night cycle base colors
    float dayFactor = smoothstep(-0.1, 0.1, sunHeight);
    vec3 nightBlue = vec3(0.01, 0.02, 0.05);
    vec3 nightHorizon = vec3(0.02, 0.05, 0.12);
    
    skyBlue = mix(nightBlue, skyBlue, dayFactor);
    horizonColor = mix(nightHorizon, horizonColor, dayFactor);
    
    // Elevation mix
    float elevation = max(0.0, rayDir.y);
    float horizonMix = pow(1.0 - elevation, 4.0);
    
    vec3 baseCol = mix(skyBlue, horizonColor, horizonMix);
    
    // Stormy sky color overlay
    vec3 stormSkyDay = vec3(0.3, 0.32, 0.35);
    vec3 stormSkyNight = vec3(0.02, 0.03, 0.04);
    vec3 stormSky = mix(stormSkyNight, stormSkyDay, dayFactor);
    baseCol = mix(baseCol, stormSky, wetness);
    
    // Stars at night
    if (dayFactor < 1.0 && rayDir.y > 0.0) {
        float starVal = hash(rayDir * 200.0);
        float starIntensity = pow(starVal, 250.0) * (1.0 - dayFactor);
        baseCol += vec3(starIntensity) * (1.0 - wetness); // no stars in rain
    }
    
    // Sunset global scatter
    float sunMix = max(0.0, 1.0 - abs(sunHeight) * 3.5);
    vec3 sunHoriz = vec3(sunDir.x, 0.0001, sunDir.z); // Epsilon to prevent NaN
    float toSun = max(0.0, dot(rayDir, normalize(sunHoriz)));
    vec3 sunsetGlow = sunsetColor * pow(toSun, 2.5) * horizonMix * sunMix * 1.5;
    
    baseCol += sunsetGlow * (1.0 - wetness * 0.8); // dull sunset in rain
    
    // Sun and Moon Discs with realistic glows
    float cosThetaSun = dot(rayDir, sunDir);
    float sunDisc = smoothstep(0.9998, 0.9999, cosThetaSun);
    float sunGlow = pow(max(0.0, cosThetaSun), 200.0) * dayFactor;
    float sunCorona = pow(max(0.0, cosThetaSun), 40.0) * dayFactor * 0.5;
    
    // Smooth sunset transition for sun
    float sunsetIntensity = max(0.0, 1.0 - abs(sunHeight) * 5.0);
    vec3 sunDiscColor = mix(vec3(2.5, 2.3, 1.8), vec3(2.0, 0.8, 0.2), sunsetIntensity);
    
    float cosThetaMoon = dot(rayDir, -sunDir);
    float moonDisc = smoothstep(0.9997, 0.9998, cosThetaMoon);
    float moonGlow = pow(max(0.0, cosThetaMoon), 100.0) * (1.0 - dayFactor);
    float moonCorona = pow(max(0.0, cosThetaMoon), 30.0) * (1.0 - dayFactor) * 0.3;
    
    // Add sun
    baseCol += vec3(sunGlow + sunCorona) * mix(vec3(1.2, 1.1, 0.9), vec3(1.5, 0.4, 0.1), sunsetIntensity) * (1.0 - wetness);
    baseCol = mix(baseCol, sunDiscColor, sunDisc * dayFactor * (1.0 - wetness));
    
    // Add moon
    baseCol += vec3(moonGlow + moonCorona) * vec3(0.5, 0.6, 0.8) * (1.0 - wetness);
    baseCol = mix(baseCol, vec3(0.9, 0.95, 1.1), moonDisc * (1.0 - dayFactor) * (1.0 - wetness));
    
    return baseCol;
}

// Intersect a ray with a horizontal plane at `height`
float intersectPlane(vec3 rayOrigin, vec3 rayDir, float height) {
    if(rayDir.y == 0.0) return -1.0;
    float t = (height - rayOrigin.y) / rayDir.y;
    return t;
}

// Raymarching volumetric 3D clouds
vec4 renderClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float maxDist) {
    float cloudMinHeight = 150.0;
    float cloudMaxHeight = 300.0;
    float cloudThickness = cloudMaxHeight - cloudMinHeight;
    
    // Intersect with cloud layer
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
    tMax = min(tMax, tMin + 3000.0); // Limit maximum draw distance for clouds
    if (tMax < tMin) return vec4(0.0);
    
    float t = tMin;
    float stepSize = (tMax - tMin) / 80.0; // 80 steps for perfect 3D volume clarity
    
    // Dithering to hide banding
    vec2 coord = gl_FragCoord.xy;
    float dither = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453) * stepSize;
    t += dither;
    
    vec4 sum = vec4(0.0);
    
    vec3 lightDir = sunDir.y > 0.0 ? sunDir : -sunDir;
    float dayFactor = smoothstep(-0.1, 0.1, sunDir.y);
    float cosTheta = dot(rayDir, lightDir);
    
    // Dual Henyey-Greenstein phase for forward and backward scattering
    float phase = mix(phaseHenyeyGreenstein(cosTheta, 0.7), phaseHenyeyGreenstein(cosTheta, -0.4), 0.3);
    
    for(int i = 0; i < 80; i++) {
        if (t >= tMax || sum.a >= 0.99) break;
        
        vec3 p = rayOrigin + rayDir * t;
        
        // Foamy noise sampling
        vec3 samplePos = p * 0.003; // perfect natural scale, larger cohesive clouds
        samplePos.x += frameTimeCounter * 0.01; // slow, realistic wind
        
        // Calculate structural noise
        float n = fbm(samplePos);
        float fineNoise = fbm(samplePos * 4.0);
        n -= fineNoise * mix(0.2, 0.1, wetness); // clear eroded edges, less erosion when rainy
        
        // Macro coverage for clustered natural clouds that don't cover the whole sky
        vec3 covPos = p * 0.0005; // larger distinct cloud groups
        covPos.z -= frameTimeCounter * 0.005;
        float coverage = fbm(covPos);
        
        // Adjust coverage based on weather
        float wetCoverage = mix(0.1, 0.8, wetness); // clear weather: low coverage, rain: high coverage
        coverage = coverage + wetCoverage - 0.2;
        coverage = smoothstep(0.4, 0.7, coverage);
        
        // Height gradient (sharp, flat bottoms, sweeping wispy tops)
        float heightFrac = (p.y - cloudMinHeight) / cloudThickness;
        float bottomGrad = mix(0.1, 0.05, wetness); // flatter bottoms in rain
        float verticalGradient = smoothstep(0.0, bottomGrad, heightFrac) * smoothstep(1.0, mix(0.3, 0.6, wetness), heightFrac);
        
        float baseThreshold = 0.8;
        float density = (n - baseThreshold + coverage) * verticalGradient;
        
        if (density > 0.0) {
            // Thicker and denser clouds during rain
            density *= mix(8.0, 15.0, wetness); 
            
            // Lighting sample inside cloud looking towards light source
            float densSun = fbm(samplePos + lightDir * 0.03) - baseThreshold + coverage;
            float lightTransmittance = exp(-max(0.0, densSun) * mix(3.0, 6.0, wetness)); // heavy self-shadowing in rain
            
            // Powder effect (darker edges)
            float powder = 1.0 - exp(-density * 2.0);
            
            // Ambient energy (darker, stormy ambient in rain)
            vec3 dayAmbient = mix(vec3(0.4, 0.5, 0.65), vec3(0.7, 0.8, 0.95), heightFrac);
            dayAmbient = mix(dayAmbient, vec3(0.25, 0.3, 0.35), wetness);
            
            vec3 nightAmbient = mix(vec3(0.01, 0.02, 0.05), vec3(0.05, 0.08, 0.12), heightFrac);
            nightAmbient = mix(nightAmbient, vec3(0.02, 0.03, 0.04), wetness);
            
            vec3 ambient = mix(nightAmbient, dayAmbient, dayFactor);
            
            // Sunset influence on clouds
            float sunsetFactor = smoothstep(0.0, 0.3, 1.0 - abs(sunDir.y) * 4.0);
            vec3 sunsetCloud = vec3(1.0, 0.4, 0.1) * sunsetFactor;
            sunsetCloud = mix(sunsetCloud, vec3(0.4, 0.2, 0.1), wetness); // duller sunset in rain
            
            // Direct light
            vec3 dayDirect = mix(vec3(1.2, 1.1, 1.0), sunsetCloud, sunsetFactor);
            dayDirect = mix(dayDirect, vec3(0.5, 0.55, 0.6), wetness); // muted sun in rain
            
            vec3 nightDirect = vec3(0.1, 0.15, 0.25); // Moonlight
            nightDirect = mix(nightDirect, vec3(0.05, 0.08, 0.12), wetness);
            
            vec3 directColor = mix(nightDirect, dayDirect, dayFactor);
            
            // Final cloud color (Henyey-Greenstein scattering + powder)
            vec3 cloudColor = ambient + directColor * lightTransmittance * powder * (1.0 + phase * 2.0);
            
            vec4 col = vec4(cloudColor * density, density);
            
            // Alpha compositing
            sum += col * (1.0 - sum.a);
        }
        
        t += stepSize;
    }
    
    return sum;
}

// --- FOG RENDERING ---
// Realistic volumetric fog
vec3 applyFog(vec3 color, float dist, vec3 rayDir, vec3 sunDir, float depth) {
    float fogDensity = mix(0.003, 0.008, wetness); // thicker fog in rain
    
    // Decrease fog density looking up into the sky so we can see stars/clouds
    if (depth > 0.99999) {
        float elevation = max(0.0, rayDir.y);
        fogDensity *= exp(-elevation * 10.0);
    }
    
    float fogFactor = 1.0 - exp(-dist * fogDensity);
    
    float sunHeight = sunDir.y;
    float dayFactor = smoothstep(-0.1, 0.1, sunHeight);
    
    // Sample the sky color at the horizon for realistic fog coloring
    vec3 horizonBlue = mix(vec3(0.02, 0.05, 0.12), vec3(0.6, 0.75, 0.9), dayFactor);
    float toSun = max(0.0, dot(rayDir, normalize(vec3(sunDir.x, 0.0001, sunDir.z))));
    vec3 sunsetGlow = vec3(1.0, 0.3, 0.05) * pow(toSun, 2.5) * max(0.0, 1.0 - abs(sunHeight) * 3.5) * 1.5;
    
    vec3 fogColor = horizonBlue + sunsetGlow;
    
    // Greyer, darker fog during rain
    vec3 rainyFogColor = mix(vec3(0.05, 0.06, 0.08), vec3(0.3, 0.35, 0.4), dayFactor);
    fogColor = mix(fogColor, rainyFogColor, wetness);
    
    return mix(color, fogColor, fogFactor);
}
