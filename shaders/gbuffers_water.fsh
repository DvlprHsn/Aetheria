#version 120
/* gbuffers_water.fsh */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float frameTimeCounter;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 color;
varying vec3 normal;
varying vec3 viewPos;
varying vec4 worldPos;

// Computes specular highlights
float calculateSpecular(vec3 viewDir, vec3 lightDir, vec3 normal, float shininess) {
    vec3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfDir), 0.0);
    return pow(NdotH, shininess);
}

// Compute shadow using shadow2D filtering (PCF)
float getShadow(sampler2D shadowtex, vec3 shadowCoord) {
    if (shadowCoord.z > 1.0 || shadowCoord.x < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y < 0.0 || shadowCoord.y > 1.0) {
        return 1.0;
    }
    
    float bias = 0.001;
    float currentDepth = shadowCoord.z - bias;
    float texelSize = 1.0 / 2048.0;
    float shadow = 0.0;
    
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            float pcfDepth = texture2D(shadowtex, shadowCoord.xy + vec2(float(x), float(y)) * texelSize).r;
            shadow += currentDepth > pcfDepth ? 0.0 : 1.0;
        }
    }
    return shadow / 9.0;
}

vec3 getShadowCoord(vec3 viewPos, mat4 gbufferModelViewInverse, mat4 shadowModelView, mat4 shadowProjection) {
    vec4 playerPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
    vec4 shadowViewPos = shadowModelView * playerPos;
    vec4 shadowClip = shadowProjection * shadowViewPos;
    return shadowClip.xyz / shadowClip.w * 0.5 + 0.5;
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Tint water to be more realistic (Cyan-blue)
    if(color.b > 0.8 && color.r < 0.2) {
        albedo.rgb = mix(albedo.rgb, vec3(0.05, 0.4, 0.6), 0.7);
        albedo.a = 0.8; // Translucent but substantial
    }

    vec3 sunDir = normalize(sunPosition);
    vec3 viewDir = normalize(-viewPos);
    vec3 upDir = normalize(upPosition);
    
    float sunElevation = dot(sunDir, upDir);
    vec3 lightDir = sunElevation > 0.0 ? sunDir : -sunDir;
    float timeBlend = clamp(abs(sunElevation) * 2.5, 0.0, 1.0);
    float isDay = step(0.0, sunElevation);
    
    vec3 daySunColor = mix(vec3(1.2, 0.7, 0.4), vec3(1.3, 1.25, 1.2), timeBlend);
    vec3 dayAmbient = mix(vec3(0.5, 0.4, 0.4), vec3(0.4, 0.6, 0.8), timeBlend);
    
    vec3 nightMoonColor = mix(vec3(0.1, 0.2, 0.4), vec3(0.3, 0.4, 0.6), timeBlend);
    vec3 nightAmbient = vec3(0.05, 0.1, 0.15);
    
    vec3 currentLightColor = mix(nightMoonColor, daySunColor, isDay);
    vec3 ambientColor = mix(nightAmbient, dayAmbient, isDay);
    
    vec3 torchColor = vec3(1.0, 0.6, 0.2);
    float torchIntensity = pow(lmcoord.x, 2.0);
    vec3 currentTorchLight = torchColor * torchIntensity * 2.5;
    
    float skyLight = pow(lmcoord.y, 2.0);
    
    // We calculate a bumpy normal for water
    vec3 bumpNormal = normal;
    if(color.b > 0.8 && color.r < 0.2) {
        // More complex wave equations for realistic surface simulation
        float waveScale = 3.0;
        float time = frameTimeCounter * 3.0; // faster waves
        
        float w1 = sin((worldPos.x + worldPos.z + time) * waveScale) * 0.1;
        float w2 = cos((worldPos.x - worldPos.z - time * 0.8) * waveScale * 1.5) * 0.1;
        float w3 = sin((worldPos.x * 0.5 + worldPos.z * 1.3 + time * 1.2) * waveScale * 0.5) * 0.1;
        
        bumpNormal.x += (w1 + w3);
        bumpNormal.z += (w2 - w1);
        bumpNormal = normalize(bumpNormal);
    }
    
    float diffuse = max(dot(bumpNormal, lightDir), 0.0);
    
    // Specular highlight for water shimmering
    float specular = calculateSpecular(viewDir, lightDir, bumpNormal, 256.0); // very high shininess for water
    float specularIntensity = 0.8; // intense shimmer
    
    // Fresnel effect
    float fresnel = pow(1.0 - max(dot(bumpNormal, viewDir), 0.0), 4.0);
    albedo.a = mix(albedo.a, 0.98, fresnel); // More opaque at grazing angles
    
    // Shadows
    vec3 shadowCoord = getShadowCoord(viewPos, gbufferModelViewInverse, shadowModelView, shadowProjection);
    float rawShadow = getShadow(shadowtex0, shadowCoord);
    float shadowFactor = mix(1.0, rawShadow, skyLight * 0.9);
    
    vec3 directionalLight = currentLightColor * diffuse * skyLight * shadowFactor;
    vec3 specularLight = currentLightColor * specular * specularIntensity * skyLight * shadowFactor;
    
    // Realist sky reflection color based on fresnel and shadows
    vec3 skyReflectionColor = mix(nightAmbient * 3.0, vec3(0.5, 0.8, 1.2), isDay) * 1.5;
    
    // Combine sun glow and sky
    float viewDotSun = max(dot(viewDir, lightDir), 0.0);
    vec3 reflectionSunGlow = currentLightColor * pow(viewDotSun, 32.0) * 0.5;
    skyReflectionColor += reflectionSunGlow;
    
    vec3 ambientWithReflection = mix(ambientColor, skyReflectionColor * shadowFactor, fresnel * skyLight);
    
    vec3 minAmbient = vec3(0.08, 0.08, 0.12);
    vec3 finalLight = max(ambientWithReflection * skyLight, minAmbient) + directionalLight + currentTorchLight;
    albedo.rgb = albedo.rgb * finalLight + specularLight;
    
    vec3 fogColorDay = mix(daySunColor, vec3(0.5, 0.7, 1.0), 0.5);
    vec3 fogColorNight = nightAmbient;
    vec3 fogColor = mix(fogColorNight, fogColorDay, isDay);
    
    float viewDotLight = max(dot(viewDir, lightDir), 0.0);
    vec3 sunGlowColor = currentLightColor * pow(viewDotLight, 4.0);
    fogColor += sunGlowColor * 0.3 * skyLight;
    
    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(vec4(fogColor, albedo.a), albedo, fogFactor);
}
