import std.stdio;
import bindbc.opengl;
import camera.camera;
import mesh.mesh;
import shader.shader;
import texture.texture;
import window.window;
import vector_3d;
import easygltf.easygltf;

void main()
{

    
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createWindowContext(window);
    Camera.createWindowContext(window);
    Texture.createWindowContext(window);
    Shader.createWindowContext(window);

    // Camera controls view point and mathematical
    Camera camera = new Camera();

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createCameraContext(camera);
    
    // Shader controls GLSL
    Shader shader = new Shader("base", "shaders/vertex.vs", "shaders/fragment.fs");
    shader.createUniform("cameraMatrix");
    shader.createUniform("objectMatrix");
    shader.createUniform("textureSampler");
 

    Camera.createShaderContext(shader);
    Mesh.createShaderContext(shader);

    // Debug model
    // float[] vertices = [
    //     0.5f,  0.5f, 0.0f,
    //     0.5f, -0.5f, 0.0f,
    //     -0.5f, -0.5f, 0.0f,
    //     -0.5f,  0.5f, 0.0f,
    // ];
    // int[] indices = [
    //     0, 1, 3, 3, 1, 2,
    // ];
    // float[] textureCoordinates = [
    //     0, 0,
    //     0, 1,
    //     1, 1,
    //     1, 0
    // ];
    // Very fancy
    // float[] colors = [
    //     0.5f, 0.0f, 0.0f,
    //     0.0f, 0.5f, 0.0f,
    //     0.0f, 0.0f, 0.5f,
    //     0.0f, 0.5f, 0.5f,
    // ];

    EasyGLTF gltf = new EasyGLTF("models/cube.gltf");

    const GLMesh meshData = gltf.glMeshes[0];

    Mesh debugMesh = new Mesh(vertices, indices, textureCoordinates, "textures/debug.png");

    float rotation = 180.0;

    while (!window.shouldClose()) {

        rotation += 1;
        if (rotation > 360.0) {
            rotation = rotation - 360.0;
        }
        
        writeln(rotation);
        
        window.pollEvents();

        glUseProgram(shader.getShaderProgram);

        window.clear(1);
        camera.clearDepthBuffer();
        camera.setRotation(Vector3d(0,0,0));
        camera.updateCameraMatrix();

        debugMesh.render(
            Vector3d(0,0,-4), // Translation
            Vector3d(0,rotation,0), // Rotation
            Vector3d(1), // Scale
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
