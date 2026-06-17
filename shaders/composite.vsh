#version 120
/* composite.vsh - Post-processing pass */

varying vec2 texcoord;
varying vec3 sunPositionScreen;

uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.st;

    // Calculate sun position in screen space for god rays
    vec4 sunPosView = vec4(sunPosition, 1.0); // sunPosition is usually in view space in Optifine
    vec4 sunPosClip = gbufferProjection * sunPosView;
    sunPositionScreen = (sunPosClip.xyz / sunPosClip.w) * 0.5 + 0.5;
}
