#version 120
/* composite.fsh - Post-processing pass */

uniform sampler2D gcolor;
uniform sampler2D depthtex0;

varying vec2 texcoord;
varying vec3 sunPositionScreen;

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    float depth = texture2D(depthtex0, texcoord).r;
    
    // Simple God Rays (Radial Blur)
    int NUM_SAMPLES = 16;
    float density = 0.5;
    float weight = 0.05;
    float decay = 0.95;
    float exposure = 0.8;
    
    vec2 tc = texcoord;
    vec2 deltaTextCoord = tc - sunPositionScreen.xy;
    deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * density;
    float illuminationDecay = 1.0;
    
    vec3 raysColor = vec3(0.0);
    // Only apply god rays if the sun is somewhat visible
    if(sunPositionScreen.z > 0.0 && sunPositionScreen.x > -0.5 && sunPositionScreen.x < 1.5 && sunPositionScreen.y > -0.5 && sunPositionScreen.y < 1.5) {
        for(int i = 0; i < NUM_SAMPLES; i++) {
            tc -= deltaTextCoord;
            // Check depth. If depth is very close to 1.0, it's sky.
            float sampleDepth = texture2D(depthtex0, tc).r;
            if(sampleDepth > 0.9999) {
                vec3 sampleColor = texture2D(gcolor, tc).rgb;
                raysColor += sampleColor * illuminationDecay * weight;
            }
            illuminationDecay *= decay;
        }
    }
    
    color.rgb += raysColor * exposure;
    
    // Simple bloom (Box blur of bright areas)
    vec3 bloom = vec3(0.0);
    float bloomThreshold = 1.0; // High threshold so only very bright things glow
    vec2 offset = vec2(1.0 / 1920.0, 1.0 / 1080.0); // Approximation
    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            vec3 bColor = texture2D(gcolor, texcoord + vec2(float(x), float(y)) * offset).rgb;
            if(length(bColor) > bloomThreshold) {
                bloom += bColor * 0.1;
            }
        }
    }
    color.rgb += bloom;
    
    gl_FragColor = color;
}
