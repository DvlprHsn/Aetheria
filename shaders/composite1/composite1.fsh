/* composite1.fsh - Bloom & Sun Shafts */
uniform sampler2D colortex0;
uniform mat4 gbufferProjection;
uniform vec3 sunPosition;

varying vec2 texcoord;

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;
    
    // Sun shafts
    vec3 sunShafts = vec3(0.0);
    vec4 clipSun = gbufferProjection * vec4(sunPosition, 1.0);
    vec2 screenSun = (clipSun.xy / clipSun.w) * 0.5 + 0.5;
    
    if (clipSun.w > 0.0) {
        vec2 delta = (texcoord - screenSun);
        float len = length(delta);
        vec2 stepDir = delta * (1.0 / 25.0);
        
        vec2 sampleCoord = texcoord;
        float decay = 1.0;
        float weight = 0.08; // Intensity
        
        for(int i = 0; i < 25; i++) {
            sampleCoord -= stepDir;
            // Bound check
            if (sampleCoord.x < 0.0 || sampleCoord.x > 1.0 || sampleCoord.y < 0.0 || sampleCoord.y > 1.0) break;
            
            vec3 sampleColor = texture2D(colortex0, sampleCoord).rgb;
            
            // Extract bright spots (sun / bright clouds)
            float brightness = dot(sampleColor, vec3(0.333));
            vec3 highlight = sampleColor * smoothstep(1.5, 2.5, brightness);
            
            sunShafts += highlight * decay * weight;
            decay *= 0.92; // Attenuation
        }
    }
    
    // Bloom (simple radial/box blur approx)
    vec3 bloom = vec3(0.0);
    float bRadius = 0.005;
    bloom += texture2D(colortex0, texcoord + vec2(bRadius, bRadius)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(-bRadius, bRadius)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(bRadius, -bRadius)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(-bRadius, -bRadius)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(0.0, bRadius * 1.5)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(0.0, -bRadius * 1.5)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(bRadius * 1.5, 0.0)).rgb;
    bloom += texture2D(colortex0, texcoord + vec2(-bRadius * 1.5, 0.0)).rgb;
    bloom /= 8.0;
    
    // Extract blooming parts
    float b = dot(bloom, vec3(0.333));
    bloom *= smoothstep(1.0, 2.0, b);
    
    // Tone mapping / ACES approx to prevent blowing out whites too much
    vec3 finalColor = color + sunShafts + (bloom * 0.3);
    
    // Mild vignette
    vec2 p = texcoord * 2.0 - 1.0;
    float dist = length(p);
    finalColor *= smoothstep(1.5, 0.5, dist);
    
    // ACES Film Tone Mapping
    float a = 2.51;
    float b2 = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    finalColor = clamp((finalColor*(a*finalColor+b2))/(finalColor*(c*finalColor+d)+e), 0.0, 1.0);
    
    gl_FragColor = vec4(finalColor, 1.0);
}
