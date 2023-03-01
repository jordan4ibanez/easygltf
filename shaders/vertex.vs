#version 410 core

// This can always be made bigger in the future
#define MAX_BONES = 30;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec3 color;

out vec2 outputTextureCoordinate;
out vec3 outputColor;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

void main() {
    

    vec4 outputCoordinate = cameraMatrix * objectMatrix * vec4(position, 1.0);

    float test = random(vec2(outputCoordinate.x, outputCoordinate.z));

    

    vec2 weird = textureCoordinate;
    weird.x += test / 10.0;
    weird.y += test / 10.0;
    

    gl_Position = outputCoordinate;
    outputTextureCoordinate = weird;
    

}