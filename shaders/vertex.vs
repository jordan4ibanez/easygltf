#version 410 core

// Frag is for tri positions and whatnot

// This can always be made bigger in the future
const int MAX_BONES = 256;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec4 joint;
layout (location = 3) in vec4 weight;

out vec2 outputTextureCoordinate;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;
uniform mat4 boneMatrices[MAX_BONES];

void main() {
    
    

    mat4 skinMat = 
        weight.x * boneMatrices[int(joint.x)] +
        weight.y * boneMatrices[int(joint.y)] +
        weight.z * boneMatrices[int(joint.z)] +
        weight.w * boneMatrices[int(joint.w)];

    vec4 worldPosition = skinMat * vec4(position,1.0);

    vec4 cameraPosition = objectMatrix * worldPosition;

    gl_Position = cameraMatrix * cameraPosition;

    outputTextureCoordinate = textureCoordinate;
}