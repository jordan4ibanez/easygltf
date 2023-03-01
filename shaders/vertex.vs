#version 410 core

// This can always be made bigger in the future
#define MAX_BONES = 30;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec4 weight;
layout (location = 3) in vec4 joint;

out vec2 outputTextureCoordinate;
out vec3 outputColor;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

uniform vec3 bonePosition;


void main() {
    

    vec4 outputCoordinate = cameraMatrix * objectMatrix * vec4(position, 1.0);

    if (gl_VertexID == 1) {
        outputCoordinate.y += 10;
    }

    gl_Position = outputCoordinate;
    outputTextureCoordinate = textureCoordinate;
}