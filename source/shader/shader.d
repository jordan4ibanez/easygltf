module shader.shader;

import std.stdio;
import std.file;
import bindbc.opengl;
import window.window;

class Shader {

    // Window context pointer.
    private static Window window;

    private string name;

    private uint vertexShader = 0;
    private uint fragmentShader = 0;
    private uint shaderProgram = 0;

    private uint[string] uniforms;

    this(string name,
        string vertexShaderCodeLocation,
        string fragmentShaderCodeLocation,
        string[] uniforms = []) {
    
        this.name = name;

        // The game cannot run without shaders, bail out
        if (!exists(vertexShaderCodeLocation)) {
            throw new Exception("Vertex shader code does not exist!");
        }
        if (!exists(fragmentShaderCodeLocation)) {
            throw new Exception("Fragment shader code does not exist!");
        }

        string vertexShaderCode = cast(string)read(vertexShaderCodeLocation);
        string fragmentShaderCode = cast(string)read(fragmentShaderCodeLocation);

        this.vertexShader = compileShader(name, vertexShaderCode, GL_VERTEX_SHADER);
        this.fragmentShader = compileShader(name, fragmentShaderCode, GL_FRAGMENT_SHADER);

        this.shaderProgram = glCreateProgram();

        glAttachShader(shaderProgram, vertexShader);
        glAttachShader(shaderProgram, fragmentShader);

        glLinkProgram(shaderProgram);

        int success;
        // Default value is SPACE instead of garbage
        char[512] infoLog = (' ');
        glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);

        if (!success) {
            glGetProgramInfoLog(shaderProgram, 512, null, infoLog.ptr);
            writeln(infoLog);

            throw new Exception("Error creating shader program!");
        }

        writeln("GL Shader Program with ID ", shaderProgram, " successfully linked!");

        foreach (string uniformName; uniforms) {
            this.createUniform(uniformName);
        }
    }

    void createUniform(string uniformName) {
        GLint location = glGetUniformLocation(this.shaderProgram, uniformName.ptr);
        writeln("uniform ", uniformName, " is at id ", location);
        // Do not allow out of bounds
        if (location < 0) {
            throw new Exception("OpenGL uniform is out of bounds!");
        }
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR CREATING UNIFORM: ", uniformName);
            // More needed crashes!
            throw new Exception("Failed to create shader uniform!");
        }

        uniforms[uniformName] = location;
    }

    // Set the uniform's int value in GPU memory (integer)
    void setUniformInt(string uniformName, GLuint value) {
        glUniform1i(uniforms[uniformName], value);
        
        GLenum glErrorInfo = window.getAndClearGLErrors();

        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            // This absolutely needs to crash, there's no way
            // the game can continue without shaders
            throw new Exception("Error setting shader uniform: " ~ uniformName);
        }
    }

    void setUniformFloat(string uniformName, GLfloat value) {
        glUniform1f(uniforms[uniformName], value);
        
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            // This needs to crash too! Game needs shaders!
            throw new Exception("Error setting shader uniform: " ~ uniformName);
        }
    }

    void setUniformDouble(string uniformName, GLdouble value) {
        glUniform1d(uniforms[uniformName], value);
        
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            // This needs to crash too! Game needs shaders!
            throw new Exception("Error setting shader uniform: " ~ uniformName);
        }
    }

    void setUniformMatrix4f(string uniformName, float[] matrix, GLint count = 1) {

        glUniformMatrix4fv(
            uniforms[uniformName], // Location
            count, // Count
            GL_FALSE,// Transpose
            matrix.ptr// Pointer
        );
        
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            // This needs to crash too! Game needs shaders!
            throw new Exception("Error setting shader uniform: " ~ uniformName);
        }
    }

    void setUniformMatrix4d(string uniformName, double[] matrix, GLint count = 1) {

        glUniformMatrix4dv(
            uniforms[uniformName], // Location
            count, // Count
            GL_FALSE,// Transpose
            matrix.ptr// Pointer
        );
        
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            // This needs to crash too! Game needs shaders!
            throw new Exception("Error setting shader uniform: " ~ uniformName);
        }
    }

    uint getUniform(string uniformName) {
        return uniforms[uniformName];
    }

    uint getShaderProgram() {
        return this.shaderProgram;
    }

    // Automates shader compilation
    private uint compileShader(string name, string sourceCode, uint shaderType) { 

        uint shader;
        shader = glCreateShader(shaderType);

        char* shaderCodePointer = sourceCode.dup.ptr;
        const(char*)* shaderCodeConstantPointer = &shaderCodePointer;
        glShaderSource(shader, 1, shaderCodeConstantPointer, null);
        glCompileShader(shader);

        int success;
        // Default value is SPACE instead of garbage
        char[512] infoLog = (' ');
        glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

        // Log info in terminal, freeze the program to prevent erroneous behavior
        if (!success) {
            string infoName = "?Other Shader?";
            if (shaderType == GL_VERTEX_SHADER) {
                infoName = "GL Vertex Shader";
            } else if (shaderType == GL_FRAGMENT_SHADER) {
                infoName = "GL Fragment Shader";
            }

            writeln("ERROR IN SHADER ", name, " ", infoName);

            glGetShaderInfoLog(shader, 512, null, infoLog.ptr);
            writeln(infoLog);

            throw new Exception("Shader compile error");
        }

        // Match the correct debug info name
        string infoName = "?Other Shader?";
        if (shaderType == GL_VERTEX_SHADER) {
            infoName = "GL Vertex Shader";
        } else if (shaderType == GL_FRAGMENT_SHADER) {
            infoName = "GL Fragment Shader";
        }

        writeln("Successfully compiled ", infoName, " with ID: ", shader);

        return shader;
    }

    void deleteShader() {

        // Detach shaders from program
        glDetachShader(this.shaderProgram, this.vertexShader);
        glDetachShader(this.shaderProgram, this.fragmentShader);

        // Delete shaders
        glDeleteShader(this.vertexShader);
        glDeleteShader(this.fragmentShader);

        // Delete the program
        glDeleteProgram(this.shaderProgram);

        writeln("Deleted shader: ", this.name);
    }

    // This injects and holds the pointer to the Window object.
    public static void createWindowContext(Window window) {
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