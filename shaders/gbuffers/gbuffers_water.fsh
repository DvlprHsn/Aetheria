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

#include "/lib/common.glsl"

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    
    // Tint water to be more realistic (Cyan-blue)
    if(color.b > 0.8 && color.r < 0.2) {
        albedo.rgb = mix(albedo.rgb, vec3(0.05, 0.4, 0.6), 0.7);
        albedo.a = 0.7; // Translucent
    }

    vec3 sunDir = normalize(sunPosition);
    vec3 viewDir = normalize(-viewPos);
    vec3 upDir = normalize(upPosition);
    
    float sunElevation = dot(sunDir, upDir);
    vec3 lightDir = sunElevation > 0.0 ? sunDir : -sunDir;
    float timeBlend = clamp(abs(sunElevation) * 2.0, 0.0, 1.0);
    float isDay = step(0.0, sunElevation);
    
    vec3 daySunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.9), timeBlend);
    vec3 dayAmbient = mix(vec3(0.3, 0.2, 0.2), vec3(0.2, 0.4, 0.6), timeBlend);
    
    vec3 nightMoonColor = mix(vec3(0.1, 0.2, 0.4), vec3(0.2, 0.3, 0.5), timeBlend);
    vec3 nightAmbient = vec3(0.02, 0.04, 0.08);
    
    vec3 currentLightColor = mix(nightMoonColor, daySunColor, isDay);
    vec3 ambientColor = mix(nightAmbient, dayAmbient, isDay);
    
    vec3 torchColor = vec3(1.0, 0.6, 0.2);
    float torchIntensity = pow(lmcoord.x, 2.0);
    vec3 currentTorchLight = torchColor * torchIntensity * 2.5;
    
    float skyLight = pow(lmcoord.y, 2.0);
    
    // We calculate a bumpy normal for water
    vec3 bumpNormal = normal;
    if(color.b > 0.8 && color.r < 0.2) {
        float wave = sin(frameTimeCounter * 3.0 + worldPos.x) * 0.1;
        bumpNormal.y += wave;
        bumpNormal.x -= wave * 0.5;
        bumpNormal = normalize(bumpNormal);
    }
    
    float diffuse = calculateOrenNayar(viewDir, lightDir, bumpNormal, 0.1); // water is smooth
    diffuse = max(diffuse, 0.0);
    
    float specular = calculateSpecular(viewDir, lightDir, bumpNormal, 128.0); // high shininess for water
    float specularIntensity = 0.5;
    
    // Fresnel effect
    float fresnel = pow(1.0 - max(dot(bumpNormal, viewDir), 0.0), 5.0);
    albedo.a = mix(albedo.a, 0.95, fresnel); // More opaque at grazing angles
    
    vec3 directionalLight = currentLightColor * diffuse * skyLight;
    vec3 specularLight = currentLightColor * specular * specularIntensity * skyLight;
    
    vec3 shadowCoord = getShadowCoord(viewPos, gbufferModelViewInverse, shadowModelView, shadowProjection);
    float shadowFactor = getShadow(shadowtex0, shadowCoord);
    shadowFactor = mix(1.0, shadowFactor, skyLight);
    
    // Fake sky reflection based on fresnel
    vec3 skyReflectionColor = mix(nightAmbient, daySunColor, isDay) * 1.5;
    vec3 ambientWithReflection = mix(ambientColor, skyReflectionColor, fresnel * skyLight);
    
    vec3 finalLight = (ambientWithReflection * skyLight) + (directionalLight * shadowFactor) + currentTorchLight;
    albedo.rgb = albedo.rgb * finalLight + (specularLight * shadowFactor);
    
    vec3 fogColorDay = mix(daySunColor, vec3(0.5, 0.7, 1.0), 0.5);
    vec3 fogColorNight = nightAmbient;
    vec3 fogColor = mix(fogColorNight, fogColorDay, isDay);
    
    float viewDotLight = max(dot(viewDir, lightDir), 0.0);
    vec3 sunGlowColor = currentLightColor * pow(viewDotLight, 4.0);
    fogColor += sunGlowColor * 0.3 * skyLight;
    
    float fogFactor = clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0);
    gl_FragColor = mix(vec4(fogColor, albedo.a), albedo, fogFactor);
}
