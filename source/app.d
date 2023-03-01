import std.stdio;
import bindbc.opengl;
import camera.camera;
import mesh.mesh;
import shader.shader;
import texture.texture;
import window.window;
import vector_3d;
import easygltf.easygltf;
import matrix_4d;
import math;

void main()
{

    
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createWindowContext(window);
    Camera.createWindowContext(window);
    Texture.createWindowContext(window);
    Shader.createWindowContext(window);

    // Camera controls view point and mathematical OpenGL calculations
    Camera camera = new Camera();

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createCameraContext(camera);
    
    // Shader controls GLSL
    Shader shader = new Shader("base", "shaders/vertex.vs", "shaders/fragment.fs");
    shader.createUniform("cameraMatrix");
    shader.createUniform("objectMatrix");
    shader.createUniform("textureSampler");
    // shader.createUniform("animationProgress");
    shader.createUniform("boneTRS");
 

    Camera.createShaderContext(shader);
    Mesh.createShaderContext(shader);

    EasyGLTF gltf = new EasyGLTF("models/debug_character.gltf");

    const GLMesh meshData = gltf.glMeshes[0];

    Mesh debugMesh = new Mesh(
        meshData.getVertexPositions(),
        meshData.getIndices(),
        meshData.getTextureCoordinates(),
        meshData.getJoints(),
        meshData.getWeights(),
        "textures/debug_character.png"
    );

    float rotation = 180.0;

    float brightness = 0.0;
    float brightUp = true;

    while (!window.shouldClose()) {

        rotation += 1;
        if (rotation > 360.0) {
            rotation = rotation - 360.0;
        }


        window.pollEvents();

        glUseProgram(shader.getShaderProgram);

        // shader.setUniformF("animationProgress", cast(GLfloat) brightness);

        window.clear(1);
        camera.clearDepthBuffer();
        camera.setRotation(Vector3d(0,0,0));
        camera.updateCameraMatrix();
        
        Matrix4d boneMatrixTest = Matrix4d()
            .rotateXYZ((rotation / 360.0) * PI2 * 4,0,0);

        shader.setUniformMatrix4f("boneTRS", boneMatrixTest.getFloatArray());

        debugMesh.render(
            Vector3d(0,-2,-4), // Translation
            Vector3d(0,rotation,0), // Rotation
            Vector3d(0.25), // Scale
        1);

        window.swapBuffers();
    }

    Mesh.destroyShaderContext();
    Camera.destroyShaderContext();

    shader.deleteShader();

    //* Clean up all reference pointers.
    Mesh.destroyCameraContext();

    Shader.destroyWindowContext();
    Texture.destroyWindowContext();
    Mesh.destroyWindowContext();
    Camera.destroyWindowContext();

    window.destroy();
}
