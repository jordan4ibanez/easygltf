import std.stdio;
import window.window;
import mesh.mesh;
import texture.texture;
import camera.camera;
import shader.shader;
import vector_3d;

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
    
    
    /*
        "",
        "",
        "",
    ""
    */

    Camera.createShaderContext(shader);
    Mesh.createShaderContext(shader);

    // Debug model
    float[] vertices = [
        -0.5f,  0.5f, 0.0f,
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.5f,  0.5f, 0.0f,
    ];
    int[] indices = [
        0, 1, 3, 3, 1, 2,
    ];
    float[] textureCoordinates = [
        0, 0,
        0, 1,
        1, 1,
        1, 0
    ];
    // Very fancy
    float[] colors = [
        0.5f, 0.0f, 0.0f,
        0.0f, 0.5f, 0.0f,
        0.0f, 0.0f, 0.5f,
        0.0f, 0.5f, 0.5f,
    ];

    Mesh debugMesh = new Mesh(vertices, indices, textureCoordinates, colors, "textures/debug.png");


    while (!window.shouldClose()) {
        window.clear(0);
        camera.updateCameraMatrix();

        debugMesh.render(Vector3d(0), Vector3d(0), Vector3d(1), 1);

        window.swapBuffers();
        window.pollEvents();
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
