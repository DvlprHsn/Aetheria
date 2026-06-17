/* gbuffers_entities.vsh */

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
