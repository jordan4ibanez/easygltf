module easygltf.easygltf;

import std.stdio;
import tinygltf;
import vector_3d;
import matrix_4d;

/**
//Todo: Implementation note:
//Todo: Maybe promote floats to doubles?
//Todo: Doubles can be demoted, but initial value as float cannot regain precision.
*/

class Bone {

}

/// Stores all OpenGL raw data.
class GLMesh {

    string name;

    private float[] vertexPositions;
    private int[] indices;
    private float[] textureCoordinates;
    private Bone[] bones;

    this(string name) {
        this.name = name;
    }

    // Convert these into a hard slice so no garbage data gets included.

    /// Gets the vertex positions as a hard array.
    auto getVertexPositions() const {
        return vertexPositions[0..vertexPositions.length];
    }
        
    /// Gets the indices as a hard array.
    auto getIndices() const {
        return indices[0..indices.length];
    }

    /// Gets the texture coordinates as a hard array.
    auto getTextureCoordinates() const {
        return textureCoordinates[0..textureCoordinates.length];
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
                this.extractIndices(model, thisMesh, primitive);
                this.extractTextureCoordinates(model, thisMesh, primitive);
                this.extractBones(model, thisMesh, primitive);
            }

            glMeshes ~= thisMesh;
        }
    }

private:

    void extractBones(Model model, GLMesh thisMesh, Primitive primitive) {
        const Skin skin = model.skins[0];
        
        bool[int] boneTracker;

        // Automatically is identity
        Matrix4d rootIdentity = Matrix4d();

        // Iterate the joint (bone) chain
        foreach (key, value; skin.joints) {
            this.iterateParentChildHierarchy(boneTracker, thisMesh, model, value, rootIdentity);
        }
    }

    void iterateParentChildHierarchy(ref bool[int] boneTracker, GLMesh thisMesh, Model model, int gltfIndex, Matrix4d parentMatrix) {

        if (gltfIndex in boneTracker && boneTracker[gltfIndex]) {
            writeln("already iterated ", gltfIndex);
            return;
        } else {
            writeln("iterating: ", gltfIndex);
            boneTracker[gltfIndex] = true;
        }

        Node boneNode = model.nodes[gltfIndex];

        Matrix4d localMatrix = Matrix4d();
        Matrix4d globalMatrix = Matrix4d();
        
        // Bone supplies matrix
        if (boneNode.matrix.length > 0) {

            writeln("Bone supplies TRS matrix!");

        }
        // Bone supplies TRS
        else {

            writeln("Bone supplies Translation, Rotation, Scale!");

        }




        foreach (int gltfChild; boneNode.children) {
            writeln("child: ", gltfChild);
            iterateParentChildHierarchy(boneTracker, thisMesh, model, gltfChild, globalMatrix);
        }
    }

    void extractTextureCoordinates(Model model, GLMesh thisMesh, Primitive primitive) {
        // Run the chain
        const int accessorId = primitive.attributes["TEXCOORD_0"];
        const Accessor accessor = model.accessors[accessorId];
        const BufferView bufferView = model.bufferViews[accessor.bufferView];
        const Buffer buffer = model.buffers[bufferView.buffer];

        // Calculate the byte offset.
        const int byteOffset = getByteOffset(accessor, bufferView);
        // Calculate the byte stride
        const int byteStride = accessor.byteStride(bufferView);

        for (int i = 0; i < accessor.count; i++) {
            float[2] textureCoordinate = readVector2f(BufferOffset(buffer.data, byteOffset + (byteStride * i)));
            
            foreach (xy; textureCoordinate) {
                thisMesh.textureCoordinates ~= xy;
            }
        }
    }

    void extractIndices(Model model, GLMesh thisMesh, Primitive primitive) {
        // Run the chain
        const int accessorId = primitive.indices;
        const Accessor accessor = model.accessors[accessorId];
        const BufferView bufferView = model.bufferViews[accessor.bufferView];
        const Buffer buffer = model.buffers[bufferView.buffer];

        // Calculate the byte offset.
        const int byteOffset = getByteOffset(accessor, bufferView);
        // Calculate the byte stride
        const int byteStride = accessor.byteStride(bufferView);

        for (int i = 0; i < accessor.count; i++) {
            thisMesh.indices ~= cast(int)readPrimitive(accessor, BufferOffset(buffer.data, byteOffset + (byteStride * i)));
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
            // Feel free to modify this to your hearts content.
            float[3] vertexPosition = readVector3f(BufferOffset(buffer.data, byteOffset + (byteStride * i)));

            foreach (xyz; vertexPosition) {
                thisMesh.vertexPositions ~= xyz;
            }

        }
    }

    int getByteOffset(const Accessor accessor, const BufferView bufferView) {
        return cast(int)(accessor.byteOffset + bufferView.byteOffset);
    }
}

// Buffer offset is a look into the buffer at a certain point in the data array.
private struct BufferOffset {

    private const ubyte[] bufferData;
    private const int offset;

    /// Construct a buffer offset raw. It is the baseline buffer data.
    this(const ubyte[] bufferData, const int offset) {
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

/// Extracts raw data from the buffer ubyte[] and converts it into T (type: float, double, int, etc)
private auto rawReadPrimitive(T)(BufferOffset readFrom) {
    ubyte[T.sizeof] rawData;
    for (int i = 0; i < T.sizeof; i++) {
        rawData[i] = readFrom.at(i);
    }
    return *(cast(T*)rawData.ptr);
}

// Agnostic array type (vector2)
//Todo: turn this into template reader from the component type
private float[2] readVector2f(const BufferOffset readFrom) {
	return[
		rawReadPrimitive!float(readFrom),
		rawReadPrimitive!float(BufferOffset(readFrom, float.sizeof)),
    ];
}

// Agnostic array type (vector3)
//Todo: turn this into template reader from the component type
private float[3] readVector3f(const BufferOffset readFrom) {
	return[
		rawReadPrimitive!float(readFrom),
		rawReadPrimitive!float(BufferOffset(readFrom, float.sizeof)),
		rawReadPrimitive!float(BufferOffset(readFrom, 2 * float.sizeof))
    ];
}

// These values become promoted or demoted into whatever def type they are in
// These values corrispond with tinygltf::TINYGLTF_COMPONENT_TYPE
private double readPrimitive(const Accessor accessor, const BufferOffset readFrom) {
    switch(accessor.componentType) {
        case (5120): {
            return rawReadPrimitive!byte(readFrom);
        }
        case (5121): {
            return rawReadPrimitive!ubyte(readFrom);
        }
        case (5122): {
            return rawReadPrimitive!short(readFrom);
        }
        case (5123): {
            return rawReadPrimitive!ushort(readFrom);
        }
        case (5124): {
            return rawReadPrimitive!int(readFrom);
        }
        case (5125): {
            return rawReadPrimitive!uint(readFrom);
        }
        case (5126): {
            return rawReadPrimitive!float(readFrom);
        }
        case (5130): {
            return rawReadPrimitive!double(readFrom);
        }
        default: return 0;
    }
}
