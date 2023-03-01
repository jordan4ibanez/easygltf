module easygltf.easygltf;

import std.stdio;
import std.conv;
import tinygltf;
import vector_3d;
import matrix_4d;
import quaternion_d;

/**
//Todo: Implementation note:
//Todo: Maybe promote floats to doubles?
//Todo: Doubles can be demoted, but initial value as float cannot regain precision.
*/

class Bone {
    Matrix4d localMatrix;

    /*
        So to find the weight of the current indice, say 1.
        You would simply do weight[1].
        This is why it's stored as an AA. Ease of use. Iterator friendly too.
    */
    double[int] weights;
    
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

        /*
        If you want to understand what is happening in this function, read this.

        This part of the GLTF spec is an absolute mess.
        By default, each indice of the model is limited to 4 joints affecting it.
        So it's stored as a Vec4. Not a quaternion.
        But wait it gets better.
        So if the model has more than 4 joints affecting an indice, it needs MORE
        than JOINTS_0, via JOINTS_1, JOINTS_2 etc. It's very interesting.
        BUT WAIT! There's more
        So JOINTS_0 is a synced list with WEIGHTS_0.
        So that means if you go into JOINTS_1 you also have to make sure WEIGHTS_1
        exists otherwise this can randomly crash.
        Also, I couldn't find a section of the GLTF spec that limits how many additional
        primitive attributes JOINTS_X can have, so you just have to keep iterating the
        attributes until you find one that doesn't exist in the associative array
        and then check that WEIGHTS_X also exists.
        Also, GUESS WHAT! In this we're iterating the INDICES of the model!
        So that means the synced containers are FLIPPED upside down.
        ALSO, we're using the XYZW component of the Vec4 as an array!
        So X,Y,Z,W is actually [0,1,2,3].
        You can't make this up.

        So to visualize this:
        Indice 0
        ->
        (this part is synced)
        Iterate JOINTS_0 Buffer.
        Iterate WEIGHTS_0 Buffer.
        ->
        Iterate the Vec4s because they're synced
        ->
        Iterate WEIGHT_0's XYZW component as a linear array
        ->
        If the WEIGHTS_0[]'s Vec4 X,Y,Z,W component is not equal to 0.0 THEN
        ->
        if the JOINTS_0[]'s Vec4 X,Y,Z,W component is equal to the current bone THEN
        ->
        Bone[Indice] = weight;

        Amazing.
        */

        // Being too dramatic here
        writeln("\nbegin the trials\n");

        // I'm limiting this thing to 1000 JOINTS_X components because if you need more than that you probably done goofed.
        foreach (i; 0..1000) {

            const string jointKey  = "JOINTS_" ~ to!string(i);
            const string weightKey = "WEIGHTS_" ~ to!string(i);

            if (!(jointKey in primitive.attributes)) {
                writeln(jointKey, " was not found!");
                break;
            }
            if (!(weightKey in primitive.attributes)) {
                writeln(weightKey, " was not found!");
                break;
            }

            // This is where it starts getting weird.
            Accessor jointAccessor  = model.accessors[primitive.attributes[jointKey]];
            Accessor weightAccessor = model.accessors[primitive.attributes[weightKey]];


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

            //* A debugging tool
            bool transpose = false;
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
