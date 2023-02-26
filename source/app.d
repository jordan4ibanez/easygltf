import std.stdio;
import window.window;
import mesh.mesh;
import texture.texture;
import camera.camera;

void main()
{
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createWindowContext(window);
    Camera.createWindowContext(window);
    Texture.createWindowContext(window);

    // Camera controls view point and mathematical
    Camera camera = new Camera();

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.createCameraContext(camera);

    while (!window.shouldClose()) {
        window.clear(0);


        window.swapBuffers();
        window.pollEvents();
    }

    //* Clean up all reference pointers.
    Mesh.destroyCameraContext();

    Texture.destroyWindowContext();
    Mesh.destroyWindowContext();
    Camera.destroyWindowContext();

    window.destroy();
}
