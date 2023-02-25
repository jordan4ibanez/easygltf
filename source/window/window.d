module window.window;

import std.stdio;
import bindbc.opengl;
import bindbc.glfw;

// This is a special import. We only want to extract the loader from this module.
import loader = bindbc.loader.sharedlib;

// This is an import that allows us to print debug info.
import tools.log;


// This is an interface into OpenGL and GLFW

class Window {

    string glVersion;
    
    /// Initializes OpenGL
    bool initializeOpenGL() {
        /**
        Compare the return value of loadGL with the global `glSupport` constant to determine if the version of GLFW
        configured at compile time is the version that was loaded.
        */
        GLSupport ret = loadOpenGL();

        this.glVersion = translateGLVersionName(ret);

        writeln("The current supported context is: ", this.glVersion);

        // Minimum version is GL 4.1 (July 26, 2010)
        if(ret < GLSupport.gl41) {
            writeln("ERROR IN gl_interface.d");
            // Log the error info
            foreach(info; loader.errors) {
                /*
                A hypothetical logging function. Note that `info.error` and `info.message` are `const(char)*`, not
                `string`.
                */
                logCError(info.error, info.message);
            }

            // Optionally construct a user-friendly error message for the user
            string msg;
            if(ret == GLSupport.noLibrary) {
                msg = "This application requires the GLFW library.";
            }
            else if(ret == GLSupport.badLibrary) {
                msg = "The version of the GLFW library on your system is too low. Please upgrade.";
            }
            // GLSupport.noContext
            else {
                msg = "Your GPU cannot support the minimum OpenGL Version: 4.1! Released: July 26, 2010.\n" ~
                    "Are your graphics drivers updated?";
            }
            // A hypothetical message box function
            writeln(msg);
            writeln("ABORTING");
            return true;
        }

        if (!isOpenGLLoaded()) {
            writeln("GL FAILED TO LOAD!!");
            return true;
        }

        // Wipe the error buffer completely
        getAndClearGLErrors();
        
        Vector2i windowSize = Window.getSize();

        glViewport(0, 0, windowSize.x, windowSize.y);

        // Enable backface culling
        glEnable(GL_CULL_FACE);

        // Alpha color blending
        glEnable(GL_BLEND);

        // Enable depth testing
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LESS);


        GLenum glErrorInfo = getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR IN GL INIT");
        }

        return false;
    }

    GLenum getAndClearGLErrors(){
        GLenum error = glGetError();
        // Clear OpenGL errors
        while (glGetError() != GL_NO_ERROR) {
            glGetError();
        }
        return error;
    }

    string getInitialOpenGLVersion() {
        string raw = to!string(loadedOpenGLVersion());
        char[] charArray = raw.dup[2..raw.length];
        return "OpenGL " ~ charArray[0] ~ "." ~ charArray[1];
    }

    string translateGLVersionName(GLSupport name) {
        string raw = to!string(name);
        char[] charArray = raw.dup[2..raw.length];
        return "OpenGL " ~ charArray[0] ~ "." ~ charArray[1];
    }

}