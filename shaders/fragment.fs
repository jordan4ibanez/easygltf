
#version 410 core

in vec2 outputTextureCoordinate;
// in float animationProgress;

out vec4 fragColor;

uniform sampler2D textureSampler;
// Just shoveling this into the frag shader for a test.
uniform float animationProgress;

void main() {

    fragColor = texture(textureSampler, outputTextureCoordinate) * vec4(animationProgress,animationProgress,animationProgress, 1.0);

}