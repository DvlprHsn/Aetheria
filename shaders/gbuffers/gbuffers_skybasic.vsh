/* gbuffers_skybasic.vsh */

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    gl_FogFragCoord = gl_Position.z;
}
