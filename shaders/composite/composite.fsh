/* composite.fsh - Post-processing pass */

uniform sampler2D gcolor;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

varying vec2 texcoord;

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
    for(int i = 0; i < 4; i++) {
        f += amp * noise(p);
        p *= 2.02;
        amp *= 0.5;
    }
    return f;
}

// Compute view directory from screen coordinates
vec3 getViewDir(vec2 coord) {
    vec4 fragPos = vec4(coord * 2.0 - 1.0, 1.0, 1.0); // Depth = 1.0 for sky direction
    fragPos = gbufferProjectionInverse * fragPos;
    fragPos /= fragPos.w;
    vec3 viewDir = normalize((gbufferModelViewInverse * vec4(fragPos.xyz, 0.0)).xyz);
    return viewDir;
}

vec3 getSkyColor(vec3 rayDir, vec3 sunDir) {
    vec3 skyBlue = vec3(0.15, 0.35, 0.65);
    vec3 horizonColor = vec3(0.5, 0.7, 0.85); // bright near horizon
    vec3 sunsetColor = vec3(0.9, 0.35, 0.1);
    
    float sunHeight = sunDir.y;
    
    // Elevation mix
    float elevation = max(0.0, rayDir.y);
    float horizonMix = pow(1.0 - elevation, 5.0);
    
    // Day/Night cycle base colors
    float dayFactor = smoothstep(-0.1, 0.1, sunHeight);
    skyBlue = mix(vec3(0.01, 0.02, 0.05), skyBlue, dayFactor);
    horizonColor = mix(vec3(0.02, 0.05, 0.1), horizonColor, dayFactor);
    
    vec3 baseCol = mix(skyBlue, horizonColor, horizonMix);
    
    // Stars at night
    if (dayFactor < 1.0 && rayDir.y > 0.0) {
        float starVal = hash(rayDir * 100.0);
        float starIntensity = pow(starVal, 150.0) * (1.0 - dayFactor);
        baseCol += vec3(starIntensity);
    }
    
    // Sunset contribution
    float sunMix = max(0.0, 1.0 - abs(sunHeight) * 3.0);
    vec3 sunHoriz = vec3(sunDir.x, 0.0001, sunDir.z); // Epsilon to prevent NaN when sun is at zenith
    float toSun = max(0.0, dot(rayDir, normalize(sunHoriz)));
    vec3 sunsetGlow = sunsetColor * pow(toSun, 3.0) * horizonMix * sunMix;
    
    baseCol += sunsetGlow;
    
    // Sun Disc
    float sunDisc = smoothstep(0.9992, 0.9995, dot(rayDir, sunDir));
    baseCol = mix(baseCol, vec3(1.5, 1.2, 0.9), sunDisc);
    
    // Moon Disc
    float moonDisc = smoothstep(0.9996, 0.9998, dot(rayDir, -sunDir));
    baseCol = mix(baseCol, vec3(0.6, 0.7, 0.9), moonDisc);
    
    return baseCol;
}

// Intersect a ray with a horizontal plane at `height`
float intersectPlane(vec3 rayOrigin, vec3 rayDir, float height) {
    if(rayDir.y == 0.0) return -1.0;
    float t = (height - rayOrigin.y) / rayDir.y;
    return t;
}

// Raymarching volumetric "foamy" clouds
vec4 renderClouds(vec3 rayOrigin, vec3 rayDir, vec3 sunDir, float maxDist) {
    float cloudMinHeight = 120.0;
    float cloudMaxHeight = 160.0;
    
    // Intersect with cloud layer
    float tMin = intersectPlane(rayOrigin, rayDir, cloudMinHeight);
    float tMax = intersectPlane(rayOrigin, rayDir, cloudMaxHeight);
    
    if (rayDir.y > 0.0) {
        if (tMin < 0.0) tMin = 0.0;
        if (tMax < 0.0) return vec4(0.0);
    } else {
        if (tMin < 0.0) return vec4(0.0);
        if (tMax < 0.0) tMax = 0.0;
        // Swap for looking down
        float tmp = tMin; tMin = tMax; tMax = tmp;
    }
    
    if (tMin > maxDist) return vec4(0.0);
    tMax = min(tMax, maxDist);
    tMax = min(tMax, tMin + 2000.0); // Limit maximum draw distance for clouds to prevent smearing
    if (tMax < tMin) return vec4(0.0);
    
    // Raymarch bounds
    float t = tMin;
    float stepSize = (tMax - tMin) / 32.0; // 32 steps for performance
    
    // Dithering to hide banding
    vec2 coord = gl_FragCoord.xy;
    float dither = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453) * stepSize;
    t += dither;
    
    vec4 sum = vec4(0.0);
    
    for(int i = 0; i < 32; i++) {
        if (t >= tMax || sum.a >= 0.99) break;
        
        vec3 p = rayOrigin + rayDir * t;
        
        // Foamy noise sampling
        vec3 samplePos = p * 0.015;
        samplePos.x += frameTimeCounter * 0.1; // Wind movement
        
        float n = fbm(samplePos);
        float verticalGradient = 1.0 - abs((p.y - 140.0) / 20.0); // fade near edges
        
        float density = n * verticalGradient - 0.35; // Cloud threshold
        
        if (density > 0.0) {
            density *= 3.0; // Scale density
            
            // Simple lighting: sunlight or moonlight direction sample
            vec3 lightDir = sunDir.y > 0.0 ? sunDir : -sunDir;
            float densSun = fbm(samplePos + lightDir * 0.05) - 0.35;
            float light = exp(-densSun * 2.0); // Shadowing inside clouds
            
            float dayFactor = smoothstep(-0.1, 0.1, sunDir.y);
            vec3 dayCloudColor = mix(vec3(0.4, 0.45, 0.55), vec3(1.0, 0.95, 0.9), light);
            vec3 nightCloudColor = mix(vec3(0.05, 0.05, 0.08), vec3(0.2, 0.25, 0.35), light);
            vec3 cloudColor = mix(nightCloudColor, dayCloudColor, dayFactor);
            
            // Highlight near sun/moon
            float phase = max(0.0, dot(rayDir, lightDir));
            vec3 highlightColor = mix(vec3(0.3, 0.35, 0.5), vec3(1.0, 0.9, 0.7), dayFactor);
            cloudColor += highlightColor * pow(phase, 4.0) * light;
            
            vec4 col = vec4(cloudColor * density, density);
            sum += col * (1.0 - sum.a); // alpha blend
        }
        
        t += stepSize;
    }
    
    return sum;
}

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;
    
    vec3 rayDir = getViewDir(texcoord);
    vec3 sunDir = normalize(sunPosition);
    vec3 rayOrigin = cameraPosition;
    
    // Background sky color
    vec3 skyColor = getSkyColor(rayDir, sunDir);
    
    // Calculate world position for depth buffer to limit cloud ray distance
    float maxDist = 10000.0;
    if (depth < 0.99999) {
        vec4 fragPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        fragPos = gbufferProjectionInverse * fragPos;
        fragPos /= fragPos.w;
        vec4 viewPos = gbufferModelViewInverse * fragPos;
        maxDist = length(viewPos.xyz);
    }
    
    // Render clouds
    vec4 clouds = renderClouds(rayOrigin, rayDir, sunDir, maxDist);
    
    // Blend final output
    vec3 finalColor = color.rgb;
    
    if (depth > 0.99999) {
        // Sky background
        finalColor = skyColor;
    }
    
    // Apply clouds over background or terrain
    finalColor = finalColor * (1.0 - clouds.a) + clouds.rgb;
    
    // Output
    gl_FragColor = vec4(finalColor, 1.0);
}
