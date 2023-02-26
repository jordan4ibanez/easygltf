module easygltf.easygltf;

import std.stdio;
import tinygltf;

/// Stores all OpenGL raw data.
class GLMesh {
    string name;

    this(string name) {
        this.name = name;
    }
}

/// GLTF context to get OpenGL data. Automatically loads and decodes JSON data.
class EasyGLTF {

    private Model model;

    /// Stores the raw mesh data for you to work with.
    GLMesh[] glMeshes;

    this(string fileLocation, bool debugInfo = false) {

        // Automatically load and decode the JSON file. Store all data into model. Becomes usable data.
        this.model = new Model(fileLocation, debugInfo);

        if (!model.loadFile()) {
            throw new Exception("Failed to load model " ~ fileLocation ~ "!");
        }

        // Now automatically decode the decoded model. Turns it into raw OpenGL data that you can easily utilize.
        foreach (mesh; model.meshes) {

            GLMesh thisMesh =  new GLMesh(mesh.name);

            foreach (primitive; mesh.primitives) {
                this.extractVertexPositions(model, thisMesh, primitive);
            }

            glMeshes ~= thisMesh;
        }
    }

    void extractVertexPositions(Model model, GLMesh thisMesh, Primitive primitive) {

        // Run the chain
        int accessorId = primitive.attributes["POSITION"];
        Accessor accessor = model.accessors[accessorId];
        BufferView bufferView = model.bufferViews[accessor.bufferView];
        Buffer buffer = model.buffers[bufferView.buffer];

        // Calculate the byte offset.
        const int byteOffset = getByteOffset(accessor, bufferView);
        // Calculate the byte stride
        const int byteStride = accessor.byteStride(bufferView);



    }


    int getByteOffset(Accessor accessor, BufferView bufferView) {
        return cast(int)(accessor.byteOffset + bufferView.byteOffset);
    }
}