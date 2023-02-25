import std.stdio;
import window.window;

void main()
{
    // Window controls OpenGL and GLFW
	Window window = new Window("easygltf prototyping").initialize;


    while (!window.shouldClose()) {
        writeln("hi there");

        window.pollEvents();
    }

}
