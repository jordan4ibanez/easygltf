module easygltf.easygltf;

import tinygltf;

class EasyGLTF {

    Model model;

    this(string fileLocation, bool debugInfo = false) {
        this.model = new Model(fileLocation, debugInfo);

        if (!model.loadFile()) {
            throw new Exception("Failed to load model " ~ fileLocation ~ "!");
        }
    }


}