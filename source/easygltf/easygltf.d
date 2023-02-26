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
        const int accessorId = primitive.attributes["POSITION"];
        const Accessor accessor = model.accessors[accessorId];
        const BufferView bufferView = model.bufferViews[accessor.bufferView];
        const Buffer buffer = model.buffers[bufferView.buffer];

        // Calculate the byte offset.
        const int byteOffset = getByteOffset(accessor, bufferView);
        // Calculate the byte stride
        const int byteStride = accessor.byteStride(bufferView);

        for (int i = 0; i < accessor.count; i++) {
            // This is counted as Vector3 so 0,1,2 is one position, 3,4,5 is the next, etc.
            // OpenGL expects a raw stream of data in one array, so that's why this is raw.
            // Note: You could bolt on a counter to do things to the values. But make sure it starts at
            // 1 so you can modulo 3!
            

        }
    }

    int getByteOffset(const Accessor accessor, const BufferView bufferView) {
        return cast(int)(accessor.byteOffset + bufferView.byteOffset);
    }
}

private struct BufferOffset {

    private ubyte[] bufferData;
    private int offset;

    /// Construct a buffer offset raw. It is the baseline buffer data.
    this(ubyte[] bufferData, const int offset) {
        this.bufferData = bufferData;
        this.offset = offset;
    }

    /// Construct a buffer offset INSIDE another buffer offset. It allows things like vectors, matrices, etc to be read.
    this(BufferOffset otherBufferOffset, const int offset) {
        this.bufferData = otherBufferOffset.bufferData;
        this.offset = offset + otherBufferOffset.offset;
    }

    /// Getter for raw data within the buffer data. Remember: These can be chained, so that's why this is a custom getter.
    ubyte at(const int offset) {
        return bufferData[this.offset + offset];
    }

}

private auto rawReadPrimitive(T)(const BufferOffset readFrom) {
    ubyte[] rawData;
    for (int i = 0; i < T.sizeof; i++) {
         rawData[] ~= readFrom.at(i);
    }
    return cast(T)test;
}