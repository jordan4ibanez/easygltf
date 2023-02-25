module texture.texture;

import std.stdio;
import bindbc.opengl;
import window.window;

class Texture {

    // Window context pointer.
    private static Window window;

    private static const bool debugEnabled = true;
        
    private GLuint id = 0;    
    private GLuint width = 0;
    private GLuint height = 0;

    this(string textureName) {
        
        TrueColorImage tempImageObject = loadImageFromFile(textureName).getAsTrueColorImage();

        this.width = tempImageObject.width();
        this.height = tempImageObject.height();

        ubyte[] tempData = tempImageObject.imageData.bytes;

        glGenTextures(1, &this.id);
        glBindTexture(GL_TEXTURE_2D, this.id);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, this.width, this.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, tempData.ptr);

        // Enable texture clamping to edge
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

        // Border color is nothing
        float[4] borderColor = [0,0,0,0];
        glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, borderColor.ptr);

        // Add in nearest neighbor texture filtering
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST/*_MIPMAP_NEAREST*/);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        // glGenerateMipmap(GL_TEXTURE_2D);

        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR IN TEXTURE");

            throw new Exception("Failed to load texture!");
        }
    }

    void cleanUp() {
        glDeleteTextures(1, &this.id);
        if (debugEnabled) {
            writeln("TEXTURE ", this.id, " HAS BEEN DELETED");
        }
    }

    // This injects and holds the pointer to the Window object.
    public static void assignWindowContext(Window window) {
        if (this.window !is null) {
            throw new Exception("Tried to assign a window context to mesh more than once!");
        }
        this.window = window;
    }
    // Prevents a circular reference.
    public static void destroyWindowContext() {
        this.window = null;
    }
}