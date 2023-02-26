module shader.shader;

import std.stdio;
import bindbc.opengl;

class Shader {

    private string name;

    private uint vertexShader = 0;
    private uint fragmentShader = 0;
    private uint shaderProgram = 0;

    private uint[string] uniforms;

    this(string name, uint vertexShader, uint fragmentShader, uint shaderProgram) {
        this.name = name;
        this.vertexShader = vertexShader;
        this.fragmentShader = fragmentShader;
        this.shaderProgram = shaderProgram;
    }

    void createUniform(string uniformName) {
        GLint location = glGetUniformLocation(this.shaderProgram, uniformName.ptr);
        writeln("uniform ", uniformName, " is at id ", location);
        // Do not allow out of bounds
        assert(location >= 0);
        uniforms[uniformName] = location;
    }

    // Set the uniform's int value in GPU memory (integer)
    void setUniformI(string uniformName, GLuint value) {
        glUniform1i(uniforms[uniformName], value);
        
        GLenum glErrorInfo = getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR CREATING UNIFORM: ", uniformName);
            // This absolutely needs to crash, there's no way
            // the game can continue without shaders
            assert(true == false);
        }
    }

    void setUniformF(string uniformName, GLfloat value) {
        glUniform1f(uniforms[uniformName], value);
        
        GLenum glErrorInfo = getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR CREATING UNIFORM: ", uniformName);
            // This needs to crash too! Game needs shaders!
            assert(true == false);
        }
    }

    uint getUniform(string uniformName) {
        return uniforms[uniformName];
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


    void createShaderProgram(
        string shaderName,
        string vertexShaderLocation,
        string fragmentShaderLocation,
        string[] uniforms
        ) {

        // The game cannot run without shaders, allow this to crash program
        string vertexShaderCode = cast(string)read(vertexShaderLocation);
        string fragmentShaderCode = cast(string)read(fragmentShaderLocation);

        uint vertexShader = compileShader(shaderName, vertexShaderCode, GL_VERTEX_SHADER);
        uint fragmentShader = compileShader(shaderName, fragmentShaderCode, GL_FRAGMENT_SHADER);

        uint shaderProgram = glCreateProgram();
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

            writeln("FREEZING PROGRAM TO ALLOW DIAGNOSTICS!");

            while(true) {
                
            }
        }

        

        writeln("GL Shader Program with ID ", shaderProgram, " successfully linked!");

        GameShader thisShader = GameShader(shaderName,vertexShader,fragmentShader, shaderProgram);

        foreach (string uniformName; uniforms) {
            thisShader.createUniform(uniformName);
            GLenum glErrorInfo = getAndClearGLErrors();
            if (glErrorInfo != GL_NO_ERROR) {
                writeln("GL ERROR: ", glErrorInfo);
                writeln("ERROR CREATING UNIFORM: ", uniformName);
                // More needed crashes!
                assert(true == false);
            }
        }
        

        container[shaderName] = thisShader;
    }

    void deleteShaders() {
        foreach (GameShader thisShader; container) {

            // Detach shaders from program
            glDetachShader(thisShader.shaderProgram, thisShader.vertexShader);
            glDetachShader(thisShader.shaderProgram, thisShader.fragmentShader);

            // Delete shaders
            glDeleteShader(thisShader.vertexShader);
            glDeleteShader(thisShader.fragmentShader);

            // Delete the program
            glDeleteProgram(thisShader.shaderProgram);

            writeln("Deleted shader: ", thisShader.name);

            // Remove the program from game memory
            container.remove(thisShader.name);
        }
    }
}