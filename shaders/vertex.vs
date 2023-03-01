#version 410 core

// This can always be made bigger in the future
#define MAX_BONES = 30;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 textureCoordinate;
layout (location = 2) in vec4 joint;
layout (location = 3) in vec4 weight;

out vec2 outputTextureCoordinate;
out vec3 outputColor;

uniform mat4 cameraMatrix;
uniform mat4 objectMatrix;

//! This is identity
uniform mat4 boneTRS = mat4(
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
);


void main() {
    

    int jointArray[4] = int[4](int(joint.x), int(joint.y), int(joint.z), int(joint.w));
    double weightArray[4] = double[4](weight.x, weight.y, weight.z, weight.w);
    
    mat4 newBoneTRS = mat4(
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1
    );


    for (int i = 0; i < 4; i++) {
        if (jointArray[i] == 3) {
            if (weightArray[i] != 0.0) {
                newBoneTRS = boneTRS;
                // outputCoordinate += vec4(bonePosition, 0);
            }
        }
    }

    vec4 outputCoordinate = cameraMatrix * objectMatrix * vec4(position, 1.0) * newBoneTRS;

    gl_Position = outputCoordinate;
    outputTextureCoordinate = textureCoordinate;
}