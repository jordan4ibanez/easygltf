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


    while (!window.shouldClose()) {
        window.clear(1,1,1);



        window.swapBuffers();
        window.pollEvents();
    }

    //* Clean up all reference pointers.
    Texture.destroyWindowContext();
    Mesh.destroyWindowContext();
    Camera.destroyWindowContext();

    window.destroy();
}
