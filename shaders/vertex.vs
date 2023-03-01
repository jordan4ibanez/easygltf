#version 410 core

// This can always be made bigger in the future
#define MAX_BONES = 30;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec4 joint;
layout (location = 3) in vec4 weight;

out vec2 outputTextureCoordinate;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

//! This is identity, this allows freely modifying the bone
uniform mat4 boneTRS = mat4(
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
);

uniform mat4[256] boneMatrix;

void main() {
    
    

    mat4 skinMat = 
        weight.x * boneMatrix[int(joint.x)] +
        weight.y * boneMatrix[int(joint.y)] +
        weight.z * boneMatrix[int(joint.z)] +
        weight.w * boneMatrix[int(joint.w)];

    vec4 worldPosition = skinMat * vec4(position,1.0);

    vec4 cameraPosition = objectMatrix * worldPosition;

    gl_Position = cameraMatrix * cameraPosition;

    outputTextureCoordinate = textureCoordinate;
}