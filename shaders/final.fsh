#version 120

/* final.fsh - Final screen-space adjustments */

uniform sampler2D gcolor;
varying vec2 texcoord;

// ACES tonemapping
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec4 color = texture2D(gcolor, texcoord);
    
    // Noticeable exposure bump
    color.rgb *= 1.8;
    
    // Saturation and vibrance boost
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 blend = color.rgb + (color.rgb - vec3(luminance)) * 0.3; // Saturation +30%
    color.rgb = mix(blend, color.rgb, 0.5); 
    
    // Tonemapping
    color.rgb = ACESFilm(color.rgb);
    
    // Subtle vignette
    vec2 pos = texcoord - 0.5;
    float dist = length(pos);
    color.rgb *= smoothstep(1.0, 0.3, dist); // softer vignette
    
    // Contrast pop
    color.rgb = mix(color.rgb, color.rgb * color.rgb * (3.0 - 2.0 * color.rgb), 0.15);
    
    gl_FragColor = vec4(color.rgb, 1.0);
}
