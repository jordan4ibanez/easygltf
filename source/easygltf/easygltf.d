module easygltf.easygltf;

import std.stdio;
import std.algorithm.sorting;
import std.conv;
import tinygltf;
import vector_3d;
import vector_4d;
import vector_4i;
import matrix_4d;
import quaternion_d;

/**
//Todo: Implementation note:
//Todo: Maybe promote floats to doubles?
//Todo: Doubles can be demoted, but initial value as float cannot regain precision.
*/

class Bone {
    Matrix4d localMatrix;
    
    this(Matrix4d localMatrix) {
        this.localMatrix = localMatrix;
    }
}

/// Stores all OpenGL raw data.
class GLMesh {

    string name;

    private bool animated = false;

    private float[] vertexPositions;
    private int[] indices;
    private float[] textureCoordinates;

    private Matrix4d[int] inverseBindMatrices;

    private Bone[int] bones;
    
    // These are synced
    private double[] weights;
    private int[] joints;

    this(string name) {
        this.name = name;
    }

    // Get if the model has animation data
    bool isAnimated() {
        return this.animated;
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

    /// Gets the indices joints as a hard array
    auto getJoints() const {
        return joints[0..joints.length];
    }

    /// Gets the indices weights as a hard array
    auto getWeights() const {
        return weights[0..weights.length];
    }

    /// Gets the IBMs as an associative array
    auto getInverseBindMatrices() const {
        return inverseBindMatrices;
    }

    /// Gets the Bones as an associative array
    auto getBones() const {
        return cast(Bone[int])bones;
    }

    /// Returns unordered matrix array as raw float arry
    auto getRawBonesInverseBindMatricesArrayFloat() const {
        float[] rawArray;
        foreach (k,thisMatrix; inverseBindMatrices) {
            Matrix4d temp = thisMatrix;
            foreach (value; temp.getFloatArray()) {
                rawArray ~= value;
            }
        }
        return rawArray[0..rawArray.length];
    }

    /// Returns unordered matrix array as raw float arry
    auto getRawBonesInverseBindMatricesArrayDouble() const {
        double[] rawArray;
        foreach (k,thisMatrix; inverseBindMatrices) {
            Matrix4d temp = thisMatrix;
            writeln(temp);
            foreach (value; temp.getFloatArray()) {
                rawArray ~= value;
            }
        }
        return rawArray[0..rawArray.length];
    }

    /// Gets the bones matrix as a hard array of Matrix4d
    auto getBonesMatrixArray() const {

        // Needs to sort linearly
        int[] keys;                
        foreach (key; this.bones.byKey) {
            keys ~= key;
        }
        keys.sort!("a < b");

        Matrix4d[] bonesFlatArray;
        foreach (int key; keys) {
            bonesFlatArray ~= bones[key].localMatrix;
        }

        return bonesFlatArray[0..bonesFlatArray.length];
    }

    /// Returns unordered matrix array as raw float arry
    auto getRawBonesArrayFloat() const {
        float[] rawArray;
        foreach (k,thisBone; bones) {
            writeln(k);

            Matrix4d thisMatrix = thisBone.localMatrix;
            foreach (value; thisMatrix.getFloatArray()) {
                rawArray ~= value;
            }
        }
        return rawArray[0..rawArray.length];
    }

    /// Gets the bones matrix as a hard array of floats
    auto getBonesArrayFloat() const {
        Matrix4d[] bonesFlatArray = getBonesMatrixArray();
        
        float[] rawArray;
        foreach (thisMatrix; bonesFlatArray) {
            foreach (value; thisMatrix.getFloatArray) {
                rawArray ~= value;
            }
        }
        
        return rawArray[0..rawArray.length];
    }

    auto getBonesArrayProccessedFloat() const {
        float[] rawArray;

        foreach (k,thisBone; bones) {

            Matrix4d matrix = thisBone.localMatrix;
            Matrix4d IBM    = inverseBindMatrices[k];

            Matrix4d processed = matrix.mul(IBM);

            foreach (value; processed.getFloatArray) {
                rawArray ~= value;
            }
        }

        return rawArray[0..rawArray.length];
    }

    /// Gets the bones matrix as a hard array of doubles
    auto getBonesArrayDouble() const {
        Matrix4d[] bonesFlatArray = getBonesMatrixArray();
        
        double[] rawArray;
        foreach (thisMatrix; bonesFlatArray) {
            foreach (value; thisMatrix.getFloatArray) {
                rawArray ~= value;
            }
        }
        
        return rawArray[0..rawArray.length];
    }

    /// Gets how many bones are in the array as GLint
    int getBoneCount() const {
        return cast(int)bones.length;
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
        foreach (integerKey, mesh; model.meshes) {

            // We are assembling this OpenGL Mesh object
            GLMesh thisMesh =  new GLMesh(mesh.name);

            foreach (primitive; mesh.primitives) {
                this.extractVertexPositions(model, thisMesh, primitive);
                this.extractIndices(model, thisMesh, primitive);
                this.extractTextureCoordinates(model, thisMesh, primitive);

                //! Skins NEED to exist to animate. This GLMesh becomes a static model if no skin is specified.
                if (model.skins.length > integerKey) {
                    this.extractInverseBindMatrices(model, thisMesh, model.skins[integerKey]);
                    this.extractBones(model, thisMesh);
                    this.extractBoneWeights(model, thisMesh, primitive);

                    thisMesh.animated = true;
                }
            }

            glMeshes ~= thisMesh;
        }
    }

private:
    
    void extractBoneWeights(Model model, GLMesh thisMesh, Primitive primitive) {

        const int i = 0;

        const string jointKey  = "JOINTS_" ~ to!string(i);
        const string weightKey = "WEIGHTS_" ~ to!string(i);

        if (!(jointKey in primitive.attributes)) {
            writeln(jointKey, " was not found!");
            return;
        }
        if (!(weightKey in primitive.attributes)) {
            writeln(weightKey, " was not found!");
            return;
        }

        // This is where it starts getting weird.

        // Run the chains
        Accessor jointAccessor  = model.accessors[primitive.attributes[jointKey]];
        Accessor weightAccessor = model.accessors[primitive.attributes[weightKey]];

        BufferView jointBufferView  = model.bufferViews[jointAccessor.bufferView];
        BufferView weightBufferView = model.bufferViews[weightAccessor.bufferView];

        Buffer jointBuffer  = model.buffers[jointBufferView.buffer];
        Buffer weightBuffer = model.buffers[weightBufferView.buffer];
        
        const int jointByteOffset = getByteOffset(jointAccessor, jointBufferView);
        const int weightByteOffset = getByteOffset(weightAccessor, weightBufferView);

        const int jointByteStride = jointAccessor.byteStride(jointBufferView);
        const int weightByteStride = weightAccessor.byteStride(weightBufferView);

        // We have to assume that these are synced
        // Iterating the indice in the mesh
        foreach (currentIndice; 0..jointAccessor.count) {

            float[4] jointArray  = readVector4f(jointAccessor,  BufferOffset( jointBuffer.data,  jointByteOffset +  (currentIndice * jointByteStride)));
            float[4] weightArray = readVector4f(weightAccessor, BufferOffset( weightBuffer.data, weightByteOffset + (currentIndice * weightByteStride)));

            // If weights are stored in 5121 (ubyte) or 5123 (ushort) they are normalized
            if (weightAccessor.componentType == 5121 || weightAccessor.componentType == 5123) {
                
                // Need the values of the data's min and max, or denormalization is not possible
                if (weightAccessor.minValues.length <= 0 || weightAccessor.maxValues.length <= 0) {
                    throw new Exception("GLTF model has normalized weight component with no min or max!");
                }

                const float min = weightAccessor.minValues[0];
                const float max = weightAccessor.maxValues[0];

                foreach (l; 0..weightArray.length) {
                    weightArray[l] = (max - weightArray[l]) / (max - min);
                }
            }
            
            // Now construct and dump the vectors into the containers
            foreach (thisJoint; jointArray) {
                thisMesh.joints ~= cast(int)thisJoint;
            }
            // thisMesh.joints  ~= Vector4i(
            //     cast(int)jointArray[0],
            //     cast(int)jointArray[1],
            //     cast(int)jointArray[2],
            //     cast(int)jointArray[3]
            // );
            
            foreach (thisWeight; weightArray) {
                thisMesh.weights ~= thisWeight;                
            }
            // thisMesh.weights ~= Vector4d(
            //     weightArray[0],
            //     weightArray[1],
            //     weightArray[2],
            //     weightArray[3]
            // );
        }
    
    }

    void extractBones(Model model, GLMesh thisMesh) {
        const Skin skin = model.skins[0];
        
        bool[int] boneTracker;

        // Automatically is identity
        Matrix4d parentMatrix = Matrix4d();

        // Iterate the joint (bone) chain
        foreach (key, value; skin.joints) {
            this.iterateParentChildHierarchy(boneTracker, thisMesh, model, value, parentMatrix);
        }
    }

    void iterateParentChildHierarchy(ref bool[int] boneTracker, GLMesh thisMesh, Model model, int gltfIndex, Matrix4d parentMatrix) {

        if (gltfIndex in boneTracker && boneTracker[gltfIndex]) {
            // writeln("already iterated ", gltfIndex);
            return;
        } else {
            // writeln("iterating: ", gltfIndex);
            boneTracker[gltfIndex] = true;
        }

        Node boneNode = model.nodes[gltfIndex];

        Matrix4d localMatrix = Matrix4d();
        
        // Bone supplies matrix
        if (boneNode.matrix.length == 16) {
            // M is short for matrix, you can probably see why
            double[16] m = boneNode.matrix;
            localMatrix = Matrix4d(
                m[0],  m[1],  m[2],  m[3],
                m[4],  m[5],  m[6],  m[7],
                m[8],  m[9],  m[10], m[11],
                m[12], m[13], m[14], m[15]
            );
        }
        // Bone supplies TRS
        else {
            // T R S - Translation Rotation Scale
            double[] t = boneNode.translation;
            double[] r = boneNode.rotation;
            double[] s = boneNode.scale;

            Vector3d translation = t.length == 3 ? Vector3d(t[0], t[1], t[2]) : Vector3d(0,0,0);
            Vector3d rotation = Vector3d(0,0,0);
            if (r.length == 4) {
                Quaterniond(r[0], r[1], r[2], r[3]).getEulerAnglesXYZ(rotation);
            }
            Vector3d scale = s.length == 3 ? Vector3d(s[0], s[1], s[2]) : Vector3d(1,1,1);
            
            localMatrix
                .setTranslation(translation)
                .setRotationXYZ(rotation.x, rotation.y, rotation.z)
                .scale(scale);
        }

        //! This might need to be inverted
        Matrix4d globalMatrix = parentMatrix.mul(localMatrix);

        Matrix4d inverseBindMatrix = thisMesh.inverseBindMatrices[gltfIndex];

        Matrix4d jointMatrix = globalMatrix
            .mul(inverseBindMatrix);
        
        thisMesh.bones[gltfIndex] = new Bone(jointMatrix);

        foreach (int gltfChild; boneNode.children) {
            // writeln("child: ", gltfChild);
            iterateParentChildHierarchy(boneTracker, thisMesh, model, gltfChild, globalMatrix);
        }
    }

    void extractInverseBindMatrices(Model model, GLMesh thisMesh, Skin skin) {
        // Run the chain
        Accessor accessor = model.accessors[skin.inverseBindMatrices];
        BufferView bufferView = model.bufferViews[accessor.bufferView];
        Buffer buffer = model.buffers[bufferView.buffer];

        // Calculate the byte offset.
        const int byteOffset = getByteOffset(accessor, bufferView);
        // Calculate the byte stride
        const int byteStride = accessor.byteStride(bufferView);

        // Hold the order of the skin nodes
        int[] skinBones = skin.joints;

        for (int i = 0; i < accessor.count; i++) {

            // M stands for Inverse Bind Matrix
            float[16] m = readMatrix4f(BufferOffset(buffer.data, byteOffset + (byteStride * i)));

            Matrix4d inverseBindMatrix;

            //* A debugging tool - row column switch
            bool transpose = true;
            if (transpose) {
                inverseBindMatrix = Matrix4d(
                    m[0], m[4], m[8],  m[12],
                    m[1], m[5], m[9],  m[13],
                    m[2], m[6], m[10], m[14],
                    m[3], m[7], m[11], m[15]
                );
            } else {
                inverseBindMatrix = Matrix4d(
                    m[0],  m[1],  m[2],  m[3],
                    m[4],  m[5],  m[6],  m[7],
                    m[8],  m[9],  m[10], m[11],
                    m[12], m[13], m[14], m[15]
                );
            }

            // Needs to stay in sync, this is why it's an AA
            thisMesh.inverseBindMatrices[skinBones[i]] = inverseBindMatrix;
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

private float[4] readVector4f(Accessor accessor, const BufferOffset readFrom) {
    return[
		readPrimitive(accessor, readFrom),
		readPrimitive(accessor, BufferOffset(readFrom, float.sizeof)),
		readPrimitive(accessor, BufferOffset(readFrom, 2 * float.sizeof)),
        readPrimitive(accessor, BufferOffset(readFrom, 3 * float.sizeof))
    ];
}

// Agnostic matrix4x4 type (mat4)
private float[16] readMatrix4f(const BufferOffset readFrom) {
    // S stands for storage, you can probably see why I made it one letter
    float[16] s;
    for (int i = 0; i < 16; i++) {
        s[i] = rawReadPrimitive!float(BufferOffset(readFrom, i * cast(int)float.sizeof));
    }
    return s;
    /*
    return core::matrix4(
        s[0], s[1], s[2], s[3],
        s[4], s[5], s[6], s[7],
        s[8], s[9], s[10],s[11],
        s[12],s[13],s[14],s[15]
    );
    */
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
