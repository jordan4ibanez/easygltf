module window.window;

import std.stdio;
import std.conv;
import bindbc.opengl;
import bindbc.glfw;
import vector_2i;
import vector_2d;

// This is a special import. We only want to extract the loader from this module.
import loader = bindbc.loader.sharedlib;

// This is an import that allows us to print debug info.
import tools.log;


// This is an interface into OpenGL and GLFW

class Window {

    // OpenGL fields
    private string glVersion;

    // GLFW fields
    private Vector2i windowSize;
    
    private GLFWwindow* window = null;
    private GLFWmonitor* monitor = null;
    private GLFWvidmode videoMode;
    private bool fullscreen = false;
    // 0 none, 1 normal vsync, 2 double buffered
    private byte vsync = 1;

    // These 3 functions calculate the FPS
    private double deltaAccumulator = 0.0;
    private int fpsCounter = 0;
    private int FPS = 0;

    //* ======== GLFW Tools ========

    // Returns true if there was an error
    private bool initializeGLFW() {

        GLFWSupport returnedError;
        
        version(Windows) {
            returnedError = loadGLFW("libs/glfw3.dll");
        } else {
            // Linux,FreeBSD, OpenBSD, Mac OS, haiku, etc
            returnedError = loadGLFW();
        }

        if(returnedError != glfwSupport) {
            writeln("ERROR IN glfw_interface.d");
            writeln("---------- DIRECT DEBUG ERROR ---------------");
            // Log the direct error info
            foreach(info; loader.errors) {
                logCError(info.error, info.message);
            }
            writeln("---------------------------------------------");
            writeln("------------ FUZZY SUGGESTION ---------------");
            // Log fuzzy error info with suggestion
            if(returnedError == GLFWSupport.noLibrary) {
                writeln("The GLFW shared library failed to load!\n",
                "Is GLFW installed correctly?\n\n",
                "ABORTING!");
            }
            else if(GLFWSupport.badLibrary) {
                writeln("One or more symbols failed to load.\n",
                "The likely cause is that the shared library is for a lower\n",
                "version than bindbc-glfw was configured to load (via GLFW_31, GLFW_32 etc.\n\n",
                "ABORTING!");
            }
            writeln("-------------------------");
            return true;
        }

        return false;
    }

    nothrow
    static extern(C) void myframeBufferSizeCallback(GLFWwindow* theWindow, int x, int y) {
        size.x = x;
        size.y = y;
        glViewport(0,0,x,y);
    }
    nothrow
    static extern(C) void externalKeyCallBack(GLFWwindow* window, int key, int scancode, int action, int mods){
        // This is the best hack ever, or the worst
        try {
        Keyboard.keyCallback(key,scancode,action,mods);
        } catch(Exception e){nothrowWriteln(e);}
    }

    nothrow
    static extern(C) void externalcursorPositionCallback(GLFWwindow* window, double xpos, double ypos) {
        try {
            Mouse.mouseCallback(Vector2d(xpos, ypos));
        } catch(Exception e){nothrowWriteln(e);}
    }

    // Internally handles interfacing to C
    bool shouldClose() {
        bool newValue = (glfwWindowShouldClose(window) != 0);
        return newValue;
    }

    void swapBuffers() {
        glfwSwapBuffers(window);
    }

    Vector2i getSize() {
        return size;
    }

    void destroy() {
        glfwDestroyWindow(window);
    }

    double getAspectRatio() {
        return cast(double)size.x / cast(double)size.y;
    }

    void pollEvents() {
        glfwPollEvents();
        // This causes an issue with low FPS getting the wrong FPS
        // Perhaps make an internal engine ticker that is created as an object or struct
        // Store it on heap, then calculate from there, specific to this
        deltaAccumulator += getDelta();
        fpsCounter += 1;
        // Got a full second, reset counter, set variable
        if (deltaAccumulator >= 1) {
            deltaAccumulator = 0.0;
            FPS = fpsCounter;
            fpsCounter = 0;
        }
    }

    int getFPS() {
        return FPS;
    }

    void setTitle(string newTitle) {
        glfwSetWindowTitle(window, cast(const(char*))newTitle);
    }

    void close() {
        glfwSetWindowShouldClose(window, true);
    }

    // Gets the primary monitor's size and halfs it automatically
    bool initializeWindow(string name){   
        // -1, -1 indicates that it will automatically interpret as half window size
        return initializeGLFWComponents(name, -1, -1, false);
    }

    // Allows for predefined window size
    bool initializeWindow(string name, int windowSizeX, int windowSizeY){   
        return initializeGLFWComponents(name, windowSizeX, windowSizeY, false);
    }

    // Automatically half sizes, then full screens it
    bool initializeWindow(string name, bool fullScreen){   
        // -1, -1 indicates that it will automatically interpret as half window size
        return initializeGLFWComponents(name, -1, -1, fullScreen);
    }

    // Window talks directly to GLFW
    private bool initializeGLFWComponents(string name, int windowSizeX, int windowSizeY, bool fullScreenAuto) {

        // Something fails to load
        if (initializeGLFW()) {
            return true;
        }

        // Something scary fails to load
        if (!glfwInit()) {
            return true;
        }

        // Minimum version is 4.1 (July 26, 2010)
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

        // Allow driver optimizations
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

        bool halfScreenAuto = false;

        // Auto start as half screened
        if (windowSizeX == -1 || windowSizeY == -1) {
            halfScreenAuto = true;
            // Literally one pixel so glfw does not crash.
            // Is automatically changed before the player even sees the window.
            // Desktops like KDE will override the height (y) regardless
            windowSizeX = 1;
            windowSizeY = 1;
        }

        // Create a window on the primary monitor
        window = glfwCreateWindow(windowSizeX, windowSizeY, name.ptr, null, null);

        // Something even scarier fails to load
        if (!window || window == null) {
            writeln("WINDOW FAILED TO OPEN!\n",
            "ABORTING!");
            glfwTerminate();
            return true;
        }

        // In the future, get array of monitor pointers with: GLFWmonitor** monitors = glfwGetMonitors(&count);
        monitor = glfwGetPrimaryMonitor();

        // Using 3.3 regardless so enable raw input
        // This is so windows, kde, & gnome scale identically with cursor input, only the mouse dpi changes this
        // This allows the sensitivity to be controlled in game and behave the same regardless
        glfwSetInputMode(window, GLFW_RAW_MOUSE_MOTION, GLFW_TRUE);


        // Monitor information & full screening & halfscreening

        // Automatically half the monitor size
        if (halfScreenAuto) {
            writeln("automatically half sizing the window");
            setHalfSizeInternal();
        }

        // Automatically fullscreen, this is a bolt on
        if (fullScreenAuto) {
            writeln("automatically fullscreening the window");
            setFullScreenInternal();
        }

        glfwSetFramebufferSizeCallback(window, &myframeBufferSizeCallback);

        glfwSetKeyCallback(window, &externalKeyCallBack);

        glfwSetCursorPosCallback(window, &externalcursorPositionCallback);    
        
        glfwMakeContextCurrent(window);

        // The swap interval is ignored before context is current
        // We must set it again, even though it is automated in fullscreen/halfsize
        glfwSwapInterval(vsync);

        glfwGetWindowSize(window,&size.x, &size.y);    

        // No error :)
        return false;
    }

    private void updateVideoMode() {
        // Get primary monitor specs
        const GLFWvidmode* mode = glfwGetVideoMode(monitor);
        // Dereference the pointer into a usable structure in class
        videoMode = *mode;
    }

    void toggleFullScreen() {
        if (fullscreen) {
            setHalfSizeInternal();
        } else {
            setFullScreenInternal();
        }
    }

    bool isFullScreen() {
        return fullscreen;
    }

    private void setFullScreenInternal() {
        updateVideoMode();    

        glfwSetWindowMonitor(
            window,
            monitor,
            0,
            0,
            videoMode.width,
            videoMode.height,
            videoMode.refreshRate
        );

        glfwSwapInterval(vsync);

        centerMouse();
        stopMouseJolt();

        fullscreen = true;
    }

    private void setHalfSizeInternal() {

        updateVideoMode();
        
        // Divide by 2 to get a "perfectly" half sized window
        int windowSizeX = videoMode.width  / 2;
        int windowSizeY = videoMode.height / 2;

        // Divide by 4 to get a "perfectly" centered window
        int windowPositionX = videoMode.width  / 4;
        int windowPositionY = videoMode.height / 4;

        glfwSetWindowMonitor(
            window,
            null,
            windowPositionX,
            windowPositionY,
            windowSizeX,
            windowSizeY,
            videoMode.refreshRate // Windows cares about this for some reason
        );

        glfwSwapInterval(vsync);

        centerMouse();
        stopMouseJolt();

        fullscreen = false;
    }

    void lockMouse() {
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        centerMouse();
        stopMouseJolt();
    }

    void unlockMouse() {
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        centerMouse();
        stopMouseJolt();
    }

    void setMousePosition(double x, double y) {
        glfwSetCursorPos(window, x, y);
    }

    Vector2d centerMouse() {
        double x = size.x / 2.0;
        double y = size.y / 2.0;
        glfwSetCursorPos(
            window,
            x,
            y
        );
        return Vector2d(x,y);
    }

    void stopMouseJolt(){
        Mouse.setOldPosition(Vector2d(size.x / 2.0, size.y / 2.0));
    }

    void setVsync(ubyte value) {
        vsync = value;
        glfwSwapInterval(vsync);
    }

    //! ====== End GLFW Tools ======
    

    //* ======= OpenGL Tools =======
    
    /// Initializes OpenGL
    private bool initializeOpenGL() {
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
        
        // Vector2i windowSize = Window.getSize();

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

    //! ===== End OpenGL Tools =====

}