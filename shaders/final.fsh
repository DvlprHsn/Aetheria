#version 120

/* final.fsh - Final screen-space adjustments */

uniform sampler2D gcolor;
varying vec2 texcoord;

// ACES tonemapping
vec3 ACESFilm(vec3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    
    // Slight exposure bump
    color.rgb *= 1.2;
    
    // Tonemapping
    color.rgb = ACESFilm(color.rgb);
    
    // Subtle vignette
    vec2 pos = texcoord - 0.5;
    float dist = length(pos);
    color.rgb *= smoothstep(0.8, 0.2, dist);
    
    // Subtle contrast curve
    color.rgb = mix(color.rgb, color.rgb * color.rgb * (3.0 - 2.0 * color.rgb), 0.2);
    
    gl_FragColor = vec4(color.rgb, 1.0);
}
