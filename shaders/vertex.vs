#version 410 core

// Frag is for tri positions and whatnot

// This can always be made bigger in the future
const int MAX_BONES = 6;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec4 joint;
layout (location = 3) in vec4 weight;

out vec2 outputTextureCoordinate;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

uniform mat4 boneMatrices[MAX_BONES];

uniform mat4 testMatrix;
uniform mat4 ibm;

void main() {

    mat4 skinMat = 
        weight.x * boneMatrices[int(joint.x)] +
        weight.y * boneMatrices[int(joint.y)] +
        weight.z * boneMatrices[int(joint.z)] +
        weight.w * boneMatrices[int(joint.w)];

    int[4] jointArray = int[4](int(joint.x), int(joint.y), int(joint.z), int(joint.w));

    float[4] floatArray = float[4](weight.x, weight.y, weight.z, weight.w);

    bool found = false;
    for (int i = 0; i < 4; i++) {
        if (jointArray[i] == 3 && floatArray[i] != 0.0) {
            found = true;
        }
    }

    vec4 worldPosition;

    if (found) {
        worldPosition = skinMat * testMatrix * ibm * vec4(position,1.0);
    } else {
        worldPosition = vec4(position,1.0);
    }

    vec4 cameraPosition = objectMatrix * worldPosition;

    gl_Position = cameraMatrix * cameraPosition;

    outputTextureCoordinate = textureCoordinate;
}
