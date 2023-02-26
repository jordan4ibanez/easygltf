module easygltf.easygltf;

import std.stdio;
import tinygltf;

/// Stores all OpenGL raw data.
class Mesh {

}

/// GLTF context to get OpenGL data. Automatically loads and decodes JSON data.
class EasyGLTF {

    Model model;

    this(string fileLocation, bool debugInfo = false) {

        // Automatically load and decode the JSON file. Store all data into model. Becomes usable data.
        this.model = new Model(fileLocation, debugInfo);

        if (!model.loadFile()) {
            throw new Exception("Failed to load model " ~ fileLocation ~ "!");
        }

        // Now automatically decode the decoded model. Turns it into raw OpenGL data that you can utilize easily.
        foreach (mesh; model.meshes) {
            writeln(mesh.name);
        }
    }


}