import std.stdio;
import window.window;
import mesh.mesh;
import camera.camera;

void main()
{
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.assignWindowContext(window);
    Camera.assignWindowContext(window);


    while (!window.shouldClose()) {
        window.clear(1,1,1);



        window.swapBuffers();
        window.pollEvents();
    }

    Mesh.destroyWindowContext();
    Camera.destroyWindowContext();

    window.destroy();
}
