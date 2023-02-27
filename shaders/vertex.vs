#version 410 core

// This can always be made bigger in the future
#define MAX_BONES = 30;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
// layout (location = 2) in vec3 color;

out vec2 outputTextureCoordinate;
out vec3 outputColor;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

void main() {

    gl_Position = cameraMatrix * objectMatrix * vec4(position, 1.0);
    outputTextureCoordinate = textureCoordinate;
    

}