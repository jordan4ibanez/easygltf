#version 410 core

// Frag is for tri colors and whatnot

in vec2 outputTextureCoordinate;
// in float animationProgress;

out vec4 fragColor;

uniform sampler2D textureSampler;

// Just shoveling this into the frag shader for a test. Default is 1.0;
// uniform float animationProgress = 1;

void main() {
    fragColor = texture(textureSampler, outputTextureCoordinate);// * vec4(animationProgress,animationProgress,animationProgress, 1.0);
}