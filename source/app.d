import std.stdio;
import window.window;
import mesh.mesh;

void main()
{
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;

    //* Allow direct message passing through reference pointers. Reduces verbosity.
    Mesh.assignWindowContext(window);


    while (!window.shouldClose()) {
        window.clear(1,1,1);



        window.swapBuffers();
        window.pollEvents();
    }

    window.destroy();
}
