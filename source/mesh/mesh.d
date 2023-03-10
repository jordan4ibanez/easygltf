module mesh.mesh;

import std.stdio;
import bindbc.opengl;
import camera.camera;
import shader.shader;
import texture.texture;
import window.window;
import vector_3d;
import vector_4d;
import vector_4i;

class Mesh {

    // Window context pointer.
    private static Window window = null;

    // Shader context pointer.
    private static Shader shader = null;

    // Camera context pointer;
    private static Camera camera = null;

    private static bool debugEnabled = false;

    private bool exists = false;

    // Vertex array object - Main object
    GLuint vao = 0;
    // Positions vertex buffer object
    GLuint pbo = 0;
    // Texture positions vertex buffer object
    GLuint tbo = 0;
    // Indices vertex buffer object
    GLuint ibo = 0;
    // Joints vertex buffer object
    GLuint jbo = 0;
    // Weights vertex buffer object
    GLuint wbo = 0;

    // Indices count, not sure why this is stored in this class?
    // Todo: Figure out why this is.
    GLuint indexCount = 0;
    
    
    private Texture texture = null;


    this(const float[] vertices, 
        const int[] indices, 
        const float[] textureCoordinates, 
        const int[] joints,
        const double[] weights,
        const string textureLocation ) {

        this.texture = new Texture(textureLocation);

        // Existence lock
        this.exists = true;

        // Don't bother if not divisible by 3 (x,y,z)
        assert(indices.length % 3 == 0 && indices.length >= 3);
        this.indexCount = cast(GLuint)(indices.length);

        // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
        glGenVertexArrays(1, &this.vao);
        glBindVertexArray(this.vao);
    

        // Positions VBO

        glGenBuffers(1, &this.pbo);
        glBindBuffer(GL_ARRAY_BUFFER, this.pbo);

        glBufferData(
            GL_ARRAY_BUFFER,                // Target object
            vertices.length * float.sizeof, // How big the object is
            vertices.ptr,                   // The pointer to the data for the object
            GL_STATIC_DRAW                  // Which draw mode OpenGL will use
        );

        glVertexAttribPointer(
            0,           // Attribute 0 (matches the attribute in the glsl shader)
            3,           // Size (literal like 3 points)  
            GL_FLOAT,    // Type
            GL_FALSE,    // Normalized?
            0,           // Stride
            cast(void*)0 // Array buffer offset
        );
        glEnableVertexAttribArray(0);


        // Texture coordinates VBO

        glGenBuffers(1, &this.tbo);
        glBindBuffer(GL_ARRAY_BUFFER, this.tbo);

        glBufferData(
            GL_ARRAY_BUFFER,
            textureCoordinates.length * float.sizeof,
            textureCoordinates.ptr,
            GL_STATIC_DRAW
        );

        glVertexAttribPointer(
            1,
            2,
            GL_FLOAT,
            GL_FALSE,
            0,
            cast(const(void)*)0
        );
        glEnableVertexAttribArray(1); 


        // Joints VBO

        glGenBuffers(1, &this.jbo);
        glBindBuffer(GL_ARRAY_BUFFER, this.jbo);

        glBufferData(
            GL_ARRAY_BUFFER,                // Target object
            joints.length * int.sizeof, // How big the object is
            joints.ptr,                   // The pointer to the data for the object
            GL_STATIC_DRAW                  // Which draw mode OpenGL will use
        );

        glVertexAttribPointer(
            2,           // Attribute 0 (matches the attribute in the glsl shader)
            4,           // Size (literal like 3 points)  
            GL_INT,    // Type
            GL_FALSE,    // Normalized?
            0,           // Stride
            cast(void*)0 // Array buffer offset
        );
        glEnableVertexAttribArray(2);

        // Weights VBO

        glGenBuffers(1, &this.wbo);
        glBindBuffer(GL_ARRAY_BUFFER, this.wbo);

        glBufferData(
            GL_ARRAY_BUFFER,                // Target object
            weights.length * double.sizeof, // How big the object is
            weights.ptr,                   // The pointer to the data for the object
            GL_STATIC_DRAW                  // Which draw mode OpenGL will use
        );

        glVertexAttribPointer(
            3,           // Attribute 0 (matches the attribute in the glsl shader)
            4,           // Size (literal like 3 points)  
            GL_DOUBLE,    // Type
            GL_FALSE,    // Normalized?
            0,           // Stride
            cast(void*)0 // Array buffer offset
        );
        glEnableVertexAttribArray(3);


        // Indices VBO

        glGenBuffers(1, &this.ibo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, this.ibo);

        glBufferData(
            GL_ELEMENT_ARRAY_BUFFER,     // Target object
            indices.length * int.sizeof, // size (bytes)
            indices.ptr,                 // the pointer to the data for the object
            GL_STATIC_DRAW               // The draw mode OpenGL will use
        );


        glBindBuffer(GL_ARRAY_BUFFER, 0);        
        
        // Unbind vao just in case
        glBindVertexArray(0);

        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR IN A MESH CONSTRUCTOR");
        }

        if (debugEnabled) {
            writeln("Mesh ", this.vao, " has been successfully created");
        }
    }

    void cleanUp() {

        // Don't bother the gpu with garbage data
        if (!this.exists) {
            if (debugEnabled) {
                writeln("sorry, I cannot clear gpu memory, I don't exist in gpu memory");
            }
            return;
        }

        // This is done like this because it works around driver issues
        
        // When you bind to the array, the buffers are automatically unbound
        glBindVertexArray(this.vao);

        // Disable all attributes of this "object"
        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);

        // Delete the positions vbo
        glDeleteBuffers(1, &this.pbo);
        assert (glIsBuffer(this.pbo) == GL_FALSE);
    
        // Delete the texture coordinates vbo
        glDeleteBuffers(1, &this.tbo);
        assert (glIsBuffer(this.tbo) == GL_FALSE);

        // Delete the colors vbo
        // glDeleteBuffers(1, &this.cbo);
        // assert (glIsBuffer(this.cbo) == GL_FALSE);

        // Delete the indices vbo
        glDeleteBuffers(1, &this.ibo);
        assert (glIsBuffer(this.ibo) == GL_FALSE);

        // Unbind the "object"
        glBindVertexArray(0);
        // Now we can delete it without any issues
        glDeleteVertexArrays(1, &this.vao);
        assert(glIsVertexArray(this.vao) == GL_FALSE);

        

        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR IN A MESH DESTRUCTOR");
        }

        if (debugEnabled) {
            writeln("Mesh ", this.vao, " has been successfully deleted from gpu memory");
        }
    }

    void render(Vector3d offset, Vector3d rotation, Vector3d scale, float light) {

        // Don't bother the gpu with garbage data
        if (!this.exists) {
            if (debugEnabled) {
                writeln("sorry, I cannot render, I don't exist in gpu memory");
            }
            return;
        }

        shader.setUniformInt("textureSampler", 0);
        //! getShader("main").setUniformF("light", light);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, this.texture.getId);

        camera.setObjectMatrix(offset, rotation, scale);

        glBindVertexArray(this.vao);
        // glDrawArrays(GL_TRIANGLES, 0, this.indexCount);
        glDrawElements(GL_TRIANGLES, this.indexCount, GL_UNSIGNED_INT, cast(const(void)*)0);
        
        GLenum glErrorInfo = window.getAndClearGLErrors();
        if (glErrorInfo != GL_NO_ERROR) {
            writeln("GL ERROR: ", glErrorInfo);
            writeln("ERROR IN A MESH RENDER");
        }
        if (debugEnabled) {
            writeln("Mesh ", this.vao, " has rendered successfully ");
        }
    }

    // void batchRender(Vector3d offset, Vector3d rotation, Vector3d scale, bool culling, Vector3d min, Vector3d max) {

    //     // Don't bother the gpu with garbage data
    //     if (!this.exists) {
    //         if (debugEnabled) {
    //             writeln("sorry, I cannot render, I don't exist in gpu memory");
    //         }
    //         return;
    //     }

    //     shader.setUniformI("textureSampler", 0);
    //     // getShader("main").setUniformF("light", light);

    //     glActiveTexture(GL_TEXTURE0);
    //     glBindTexture(GL_TEXTURE_2D, this.texture.getId);

    //     //! Camera.setObjectMatrix(offset, rotation, scale);

    //     if (culling) {
    //         // Let's get some weird behavior to show it
    //         bool inside = true;//!Re-enable this insideFrustumAABB(min, max);
    //         // bool inside = insideFrustumSphere(10);
    //         if (!inside) {
    //             return;
    //         }
    //     }

    //     glBindVertexArray(this.vao);
    //     // glDrawArrays(GL_TRIANGLES, 0, this.indexCount);
    //     glDrawElements(GL_TRIANGLES, this.indexCount, GL_UNSIGNED_INT, cast(const(void)*)0);
        
    //     GLenum glErrorInfo = window.getAndClearGLErrors();
    //     if (glErrorInfo != GL_NO_ERROR) {
    //         writeln("GL ERROR: ", glErrorInfo);
    //         writeln("ERROR IN A MESH RENDER");
    //     }
    //     if (debugEnabled) {
    //         writeln("Mesh ", this.vao, " has rendered successfully ");
    //     }
    // }

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

    // This injects and holds the pointer to the Camera object.
    public static void createCameraContext(Camera camera) {
        if (this.camera !is null) {
            throw new Exception("Tried to assign a camera context to mesh more than once!");
        }
        this.camera = camera;
    }
    // Prevents a circular reference.
    public static void destroyCameraContext() {
        this.camera = null;
    }

    public static void createShaderContext(Shader shader) {
        if (this.shader !is null) {
            throw new Exception("Tried to assign the shader context more than once!");
        }
        this.shader = shader;
    }

    public static void destroyShaderContext() {
        this.shader = null;
    }
}