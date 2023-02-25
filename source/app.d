import std.stdio;
import window.window;

void main()
{
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;


    while (!window.shouldClose()) {
        window.clear(1,1,1);

        

        window.swapBuffers();
        window.pollEvents();
    }

    window.destroy();
}
