module window.window;

import std.stdio;
import std.conv;
import std.string;
import bindbc.opengl;
import bindbc.glfw;
import vector_2i;
import vector_2d;
import delta_time;

// This is a special import. We only want to extract the loader from this module.
import loader = bindbc.loader.sharedlib;

// This is an import that allows us to print debug info.
import tools.log;


// This is an interface into OpenGL and GLFW

class Window {

    // Sort of a variation on singleton, create more than one window and OpenGL context and it crashes.
    static private bool locked = false;

    // OpenGL fields
    private static string glVersion;

    // GLFW fields
    private static string windowTitle;
    private static Vector2i windowSize;
    
    private static  GLFWwindow* window = null;
    private static GLFWmonitor* monitor = null;
    private static GLFWvidmode videoMode;
    private static bool fullscreen = false;
    // 0 none, 1 normal vsync, 2 double buffered
    private static byte vsync = 1;

    // These 3 functions calculate the FPS
    private static double deltaAccumulator = 0.0;
    private static int fpsCounter = 0;
    private static int FPS = 0;
    
    this(string windowTitle) {
        this.windowTitle = windowTitle;
    }

    Window initialize() {
        checkLock();

        if (!initializeGLFW()) {
            throw new Exception("GLFW failed");
        }

        if (!initializeOpenGL()) {
            throw new Exception("OpenGL failed");
        }

        return this;
    }

    // This checks the lock state and WILL crash the program if more than one exist
    private void checkLock() {
        if (locked) {
            throw new Exception("More than one window was created!");
        }
        locked = true;
    }

    //* ======== GLFW Tools ========

    // Returns success state 
    private bool initializeGLFWComponents() {

        GLFWSupport returnedError;
        
        version(Windows) {
            returnedError = loadGLFW("libs/glfw3.dll");
        } else {
            // Linux,FreeBSD, OpenBSD, Mac OS, haiku, etc
            returnedError = loadGLFW();
        }

        if(returnedError != glfwSupport) {
            writeln("ERROR IN GLFW!");
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
            return false;
        }

        return true;
    }

    nothrow
    static extern(C) void myframeBufferSizeCallback(GLFWwindow* theWindow, int x, int y) {
        this.windowSize.x = x;
        this.windowSize.y = y;
        glViewport(0,0,x,y);
    }
    // nothrow
    // static extern(C) void externalKeyCallBack(GLFWwindow* window, int key, int scancode, int action, int mods){
    //     // This is the best hack ever, or the worst
    //     try {
    //     Keyboard.keyCallback(key,scancode,action,mods);
    //     } catch(Exception e){nothrowWriteln(e);}
    // }

    // nothrow
    // static extern(C) void externalcursorPositionCallback(GLFWwindow* window, double xpos, double ypos) {
    //     try {
    //         Mouse.mouseCallback(Vector2d(xpos, ypos));
    //     } catch(Exception e){nothrowWriteln(e);}
    // }

    // Internally handles interfacing to C
    bool shouldClose() {
        bool newValue = (glfwWindowShouldClose(window) != 0);
        return newValue;
    }

    void swapBuffers() {
        glfwSwapBuffers(window);
    }

    Vector2i getSize() {
        return windowSize;
    }

    void destroy() {
        glfwDestroyWindow(window);
    }

    double getAspectRatio() {
        return cast(double)windowSize.x / cast(double)windowSize.y;
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
    // private bool initializeWindow(){   
    //     // -1, -1 indicates that it will automatically interpret as half window size
    //     return initializeGLFW(-1, -1, false);
    // }

    // // Allows for predefined window size
    // bool initializeWindow(int windowSizeX, int windowSizeY){   
    //     return initializeGLFW(this.windowTitle, windowSizeX, windowSizeY, false);
    // }

    // // Automatically half sizes, then full screens it
    // bool initializeWindow(bool fullScreen){   
    //     // -1, -1 indicates that it will automatically interpret as half window size
    //     return initializeGLFW(this.windowTitle, -1, -1, fullScreen);
    // }

    // Window talks directly to GLFW
    private bool initializeGLFW(int windowSizeX = -1, int windowSizeY = -1, bool fullScreenAuto = false) {

        // Something fails to load
        if (!initializeGLFWComponents()) {
            return false;
        }

        // Something scary fails to load
        if (!glfwInit()) {
            return false;
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
        window = glfwCreateWindow(windowSizeX, windowSizeY, this.windowTitle.toStringz, null, null);

        // Something even scarier fails to load
        if (!window || window == null) {
            writeln("WINDOW FAILED TO OPEN!\n",
            "ABORTING!");
            glfwTerminate();
            return false;
        }

        // In the future, get array of monitor pointers with: GLFWmonitor** monitors = glfwGetMonitors(&count);
        monitor = glfwGetPrimaryMonitor();

        // Using 3.3 regardless so enable raw input
        // This is so windows, kde, & gnome scale identically with cursor input, only the mouse dpi changes this
        // This allows the sensitivity to be controlled in game and behave the same regardless
        glfwSetInputMode(window, GLFW_RAW_MOUSE_MOTION, GLFW_TRUE);


        // Monitor information & full screening & halfscreening

        // Automatically half the monitor size
        // if (halfScreenAuto) {
        //     writeln("automatically half sizing the window");
        //     setHalfSizeInternal();
        // }

        // Automatically fullscreen, this is a bolt on
        // if (fullScreenAuto) {
        //     writeln("automatically fullscreening the window");
        //     setFullScreenInternal();
        // }

        glfwSetFramebufferSizeCallback(window, &myframeBufferSizeCallback);

        // glfwSetKeyCallback(window, &this.externalKeyCallBack);

        // glfwSetCursorPosCallback(window, &externalcursorPositionCallback);    
        
        glfwMakeContextCurrent(window);

        // The swap interval is ignored before context is current
        // We must set it again, even though it is automated in fullscreen/halfsize
        glfwSwapInterval(vsync);

        glfwGetWindowSize(window,&windowSize.x, &windowSize.y);    

        // No error :)
        return true;
    }

    private void updateVideoMode() {
        // Get primary monitor specs
        const GLFWvidmode* mode = glfwGetVideoMode(monitor);
        // Dereference the pointer into a usable structure in class
        videoMode = *mode;
    }

    // void toggleFullScreen() {
    //     if (fullscreen) {
    //         setHalfSizeInternal();
    //     } else {
    //         setFullScreenInternal();
    //     }
    // }

    bool isFullScreen() {
        return fullscreen;
    }

    // private void setFullScreenInternal() {
    //     updateVideoMode();    

    //     glfwSetWindowMonitor(
    //         window,
    //         monitor,
    //         0,
    //         0,
    //         videoMode.width,
    //         videoMode.height,
    //         videoMode.refreshRate
    //     );

    //     glfwSwapInterval(vsync);

    //     centerMouse();
    //     stopMouseJolt();

    //     fullscreen = true;
    // }

    // private void setHalfSizeInternal() {

    //     updateVideoMode();
        
    //     // Divide by 2 to get a "perfectly" half sized window
    //     int windowSizeX = videoMode.width  / 2;
    //     int windowSizeY = videoMode.height / 2;

    //     // Divide by 4 to get a "perfectly" centered window
    //     int windowPositionX = videoMode.width  / 4;
    //     int windowPositionY = videoMode.height / 4;

    //     glfwSetWindowMonitor(
    //         window,
    //         null,
    //         windowPositionX,
    //         windowPositionY,
    //         windowSizeX,
    //         windowSizeY,
    //         videoMode.refreshRate // Windows cares about this for some reason
    //     );

    //     glfwSwapInterval(vsync);

    //     centerMouse();
    //     stopMouseJolt();

    //     fullscreen = false;
    // }

    // void lockMouse() {
    //     glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    //     centerMouse();
    //     stopMouseJolt();
    // }

    // void unlockMouse() {
    //     glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
    //     centerMouse();
    //     stopMouseJolt();
    // }

    void setMousePosition(double x, double y) {
        glfwSetCursorPos(window, x, y);
    }

    Vector2d centerMouse() {
        double x = windowSize.x / 2.0;
        double y = windowSize.y / 2.0;
        glfwSetCursorPos(
            window,
            x,
            y
        );
        return Vector2d(x,y);
    }

    // void stopMouseJolt(){
    //     Mouse.setOldPosition(Vector2d(size.x / 2.0, size.y / 2.0));
    // }

    void setVsync(ubyte value) {
        vsync = value;
        glfwSwapInterval(vsync);
    }

    //! ====== End GLFW Tools ======
    

    //* ======= OpenGL Tools =======
    
    /// Returns success
    private bool initializeOpenGL() {
        /**
        Compare the return value of loadGL with the global `glSupport` constant to determine if the version of GLFW
        configured at compile time is the version that was loaded.
        */
        GLSupport ret = loadOpenGL();

        writeln(ret);

        this.glVersion = translateGLVersionName(ret);

        writeln("The current supported context is: ", this.glVersion);

        // Minimum version is GL 4.1 (July 26, 2010)
        if(ret < GLSupport.gl41) {
            writeln("ERROR IN OpenGL");
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
            return false;
        }

        if (!isOpenGLLoaded()) {
            writeln("GL FAILED TO LOAD!!");
            return false;
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
            return false;
        }

        return true;
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