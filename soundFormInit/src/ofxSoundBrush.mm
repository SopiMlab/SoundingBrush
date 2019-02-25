#include "ofxSoundBrush.h"

//--------------------------------------------------
ofxSoundBrush::ofxSoundBrush(){
    color = ofColor::black;
    size = 1.0f;
    patch = "pd/sinewithamp.pd";
    left = 99999.0f; //extreme value towards the right
    right = -10.0f;
    top = 99999.0f;
    bottom = -1000;
    average = glm::vec2(0, 0);
    standardDeviationX = standardDeviationY = 0.0f;
    varianceX = varianceY = 0.0f;
    rSeed = ofRandom(360);
    
    brushType = 0;
    isDebug = false;
    drawing = true;
    
    baseFbo.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    
    //    blurX.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    //    blurY.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    //    sBlurX.load("shaders/blurX");
    //    sBlurY.load("shaders/blurY");
    
    finalFbo.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    
    mainShader.load("shaders/base");
    alphaShader.load("shaders/alpha");
    
}
//--------------------------------------------------
void ofxSoundBrush::setup(string _patch){
    patch = _patch;
    
}
//--------------------------------------------------
void ofxSoundBrush::setup(string _patch, int _bType){
    patch = _patch;
    brushType = _bType;
}

//--------------------------------------------------
void ofxSoundBrush::setup(string _patch, int _bType, string _baseShader, string _alphaShader){
    patch = _patch;
    brushType = _bType;
    string bShader = "shaders/base_" + _baseShader;
    string aShader = "shaders/alpha_" + _alphaShader;
    
    mainShader.load(bShader);
    alphaShader.load(aShader);
}

//--------------------------------------------------
void ofxSoundBrush::setVariables(float _w, ofColor _c){
    color = _c;
    size = _w;
}


//--------------------------------------------------
void ofxSoundBrush::addPoint(glm::vec2 _p){
    
    points.push_back(glm::vec3(_p, 0));
    
    line.addVertex(_p.x, _p.y, 0);
    
    //------IGNORE THIS NOW
    
//        //This makes sure the size of the vector is always 3n + 1.
//        if(points.size() == 0){
//            points.push_back(glm::vec3(_p.x, _p.y, 0));
//        } else {
//            glm::vec2 lastPoint = points[points.size() - 1];
//            float icr = 3;
//            for(int i = 1; i <= icr; i++){
//                glm::vec2 intermediate = lerp(_p, lastPoint, i/icr);
//                points.push_back(glm::vec3(intermediate.x, intermediate.y, 0));
//            }
//        }
    
    calculateDataSet();
    calculateSD();
    
    line = line.getSmoothed(1); //TODO or Not TODO? Comment 29.1 can work w/ update of a few sounds...
    
}

//--------------------------------------------------
void ofxSoundBrush::handleShaders(){
    
    if(drawing) computeMesh();
    
    int attLoc = mainShader.getAttributeLocation("myCustomAttribute");
    
    baseFbo.begin();
    ofClear(0,0);
    mainShader.begin();
    glm::vec4 c = glm::vec4(color.r/float(255), color.g/float(255), color.b/float(255), 1.0);
    mainShader.setUniform4f("c", c);
    mainShader.setUniform2f("area", width/float(ofGetWidth()), height/float(ofGetHeight()));
    mainShader.setUniform2f("screenResolution", glm::vec2(ofGetWidth(), ofGetHeight()));
    mainShader.setUniform1f("time", ofGetElapsedTimef());
    mainShader.setUniform1f("seed", rSeed);
    mainShader.setUniform1f("length", points.size());
    mainShader.setUniform1f("width", size);
    //    mainShader.setUniform1f("alpha", color.a/float(255));
    int vertices = mesh.getVertices().size();
    mesh.getVbo().setAttributeData(attLoc, &customAttributeData[0], 2, vertices * 2, GL_STATIC_DRAW, sizeof(float)*2);
    mesh.draw();
    mainShader.end();
    baseFbo.end();
    //}
    
    //    blurX.begin();
    //    sBlurX.begin();
    //    sBlurX.setUniform2f("resolution", ofGetWidth(), ofGetHeight());
    //    sBlurX.setUniform1f("bAmount", 10);
    //    baseFbo.draw(0, 0);
    //    sBlurX.end();
    //    blurX.end();
    
    finalFbo.begin();
    ofClear(0, 0);
    alphaShader.begin();
    mainShader.setUniform2f("resolution", glm::vec2(ofGetWidth(), ofGetHeight()));
    alphaShader.setUniform1f("alpha", color.a/float(255));
    alphaShader.setUniform1f("length", points.size());
    alphaShader.setUniform1f("time", ofGetElapsedTimef());
    alphaShader.setUniform1f("seed", rSeed);
    baseFbo.draw(0, 0);
    alphaShader.end();
    finalFbo.end();
    
    //    blurX.begin();
    //    sBlurX.begin();
    //    sBlurX.setUniformTexture("tex0", finalFbo.getTexture(), 0);
    //    sBlurX.setUniform1f("bAmount", size/float(100000));
    //    finalFbo.draw(0, 0);
    //    sBlurX.end();
    //    blurX.end();
    //
    //    blurY.begin();
    //    sBlurY.begin();
    //    sBlurY.setUniformTexture("tex0", blurX.getTexture(), 0);
    //    sBlurY.setUniform1f("bAmount", size/float(100000));
    //    blurX.draw(0, 0);
    //    sBlurY.end();
    //    blurY.end();
    //}
}

//--------------------------------------------------
void ofxSoundBrush::draw(){
    
    //    baseFbo.draw(0, 0);
    //    blurX.draw(0, 0);
    //    blurY.draw(0, 0);
    finalFbo.draw(0, 0);
    
    //------TESTTESTTEST
    
//    drawTestLine();
    //    //This makes sure the size of the vector is always 3n + 1.
    //    if(points.size() == 0){
    //        points.push_back(_p);
    //    } else {
    //        glm::vec2 lastPoint = points[points.size() - 1];
    //        float icr = 3;
    //        for(int i = 1; i <= icr; i++){
    //            glm::vec2 intermediate = lerp(_p, lastPoint, i/icr);
    //            points.push_back(intermediate);
    //        }
    //    }
    
//    interpolatedPoints = evalCR(points, 100);
//
//    ofPushStyle();
//    ofSetColor(color);
//
//    for(int i = 0; i<interpolatedPoints.size(); i++){
//
//        ofDrawCircle(interpolatedPoints[i], size);
//    }
//
//    ofPopStyle();
    
    
    //------------------
    
    //Below for debug.
    if(isDebug){
        ofNoFill();
        ofSetColor(ofColor::red);
        glm::vec2 topLeft = glm::vec2(left, top);
        
        ofDrawRectangle(topLeft, width, height);
        
        stringstream s1, s2;
        
        s1 << "Standard deviation in X is: " << ofToString(standardDeviationX) << " " << "Standard deviation in Y is: " << ofToString(standardDeviationY) << endl;
        
        
        s2 << "Number of vertices: " << ofToString(points.size()) << " " << "width is: " << ofToString(width) << " height is: " << " " << ofToString(height) << endl;
        
        ofDrawBitmapStringHighlight(s1.str(), topLeft);
        ofDrawBitmapStringHighlight(s2.str(), topLeft.x, topLeft.y + height);
    }
}

//--------------------------------------------------
void ofxSoundBrush::setColor(ofColor _c){
    color = _c;
}

//--------------------------------------------------
void ofxSoundBrush::setSize(float _s){
    size = _s;
}

//--------------------------------------------------
void ofxSoundBrush::setAlpha(float _a){
    color = ofColor(color, _a);
}

//--------------------------------------------------
void ofxSoundBrush::calculateDataSet(){
    
    float xSum = 0.0f;
    float ySum = 0.0f;
    
    for(int i = 0; i < points.size(); i++){
        if (points[i].x < left) left = points[i].x;
        if (points[i].x > right) right = points[i].x;
        
        xSum += points[i].x;
        
        if (points[i].y < top) top = points[i].y;
        if (points[i].y > bottom) bottom = points[i].y;
        
        ySum += points[i].y;
    }
    
    width = right - left;
    height = bottom - top;
    
    float aveX = xSum / float(points.size() - 1);
    float aveY = ySum / float(points.size() - 1);
    
    sumsXY = glm::vec2(xSum, ySum);
    average = glm::vec2(aveX, aveY);
    
}

//--------------------------------------------------
void ofxSoundBrush::calculateSD(){
    
    vector<float> xDeviationsSquare;
    vector<float> yDeviationsSquare;
    
    for(int i = 0; i < points.size(); i++){
        float xDeviationSquare = pow((points[i].x - average.x), 2);
        float yDeviationSquare = pow((points[i].y - average.y), 2);
        
        xDeviationsSquare.push_back(xDeviationSquare);
        yDeviationsSquare.push_back(yDeviationSquare);
    }
    
    varianceX = (std::accumulate(xDeviationsSquare.begin(), xDeviationsSquare.end(), 0)) / xDeviationsSquare.size();
    varianceY = (std::accumulate(yDeviationsSquare.begin(), yDeviationsSquare.end(), 0)) / yDeviationsSquare.size();
    
    standardDeviationX = sqrt(varianceX);
    standardDeviationY = sqrt(varianceY);
    
}
//--------------------------------------------------
float ofxSoundBrush::getJitterOnMinorAxis(){
    float a = 0;
    
    if(width<height){
        a = standardDeviationY;
    } else {
        a = standardDeviationX;
    }
    
    return a;
}

//---------------------------------------------------
float ofxSoundBrush::getLastDistance(){
    
    float d = 0;
    
    if(points.size() > 2){
        d = glm::distance(points[points.size()-1], points[points.size()-2]);
    }
    
    return d;
}

//---------------------------------------------------
void ofxSoundBrush::computeMesh(){
    
    switch(brushType){
        case 0:
        drawThickLine();
        break;
        case 1:
        drawWithThicknessFunction(size);
        break;
        case 2:
        drawJigglyLines(size, size/25.0);
        break;
        case 3:
        drawJigglyLinesByDist(1);
        break;
    }
}


//---------------------------------------------------
//DIFFERENT KINDS OF BRUSHES. WILL BE A SWITCH CALL
//---------------------------------------------------

//    --------------------------from ofZach/drawing-examples/thickness
//    ----------------------------------------------------------------


void ofxSoundBrush::drawThickLine(){
    
    if(drawing){
        ofVboMesh meshy;
        meshy.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
        
        float widthSmooth = 10;
        float angleSmooth;
        
        for (int i = 0;  i < line.getVertices().size(); i++){
            
            int me_m_one = i-1;
            int me_p_one = i+1;
            if (me_m_one < 0) me_m_one = 0;
            if (me_p_one ==  line.getVertices().size()) me_p_one =  line.getVertices().size()-1;
            
            ofPoint diff = line.getVertices()[me_p_one] - line.getVertices()[me_m_one];
            float angle = atan2(diff.y, diff.x);
            
            if (i == 0) angleSmooth = angle;
            else {
                
                angleSmooth = ofLerpRadians(angleSmooth, angle, 1.0);
                
            }
            
            float dist = diff.length();
            
            float w = ofMap(dist, 0, size, 40, 2, true);
            
            widthSmooth = 0.9f * widthSmooth + 0.1f * w;
            
            ofPoint offset;
            offset.x = cos(angleSmooth + PI/2) * widthSmooth;
            offset.y = sin(angleSmooth + PI/2) * widthSmooth;
            
            meshy.addVertex(  line.getVertices()[i] +  offset );
            meshy.addVertex(  line.getVertices()[i] -  offset );
            
        }
        
        ofSetColor(color);
        mesh = meshy;
        //meshy.draw();
        
    } else {
        
       // mesh.draw();
    }
    
    //    ofSetColor(100,100,100);
    //    meshy.drawWireframe();
}

//---------------------------------------------------


//    --------------------------from ofZach/drawing-examples/thickness-function
//    ----------------------------------------------------------------

void ofxSoundBrush::drawWithThicknessFunction(int thickness){
    
    if(drawing){
        ofVboMesh meshy;
        meshy.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
        customAttributeData.clear();
        
        float widthSmooth = 10;
        float angleSmooth;
        
        
        for (int i = 0;  i < line.getVertices().size(); i++){
            int me_m_one = i-1;
            int me_p_one = i+1;
            if (me_m_one < 0) me_m_one = 0;
            if (me_p_one ==  line.getVertices().size()) me_p_one =  line.getVertices().size()-1;
            ofPoint diff = line.getVertices()[me_p_one] - line.getVertices()[me_m_one];
            float angle = atan2(diff.y, diff.x);
            float dist = diff.length();
            ofPoint offset;
            offset.x = cos(angle + PI/2) * thickness;
            offset.y = sin(angle + PI/2) * thickness;
            
            auto vertexOne = line.getVertices()[i] + offset;
            meshy.addVertex(vertexOne);
            auto nIndex = fabs(float(i) - line.getVertices().size()/2.0); // absolute distance from centre of the array
            nIndex /= line.getVertices().size()/2.0; // normalized between 1 - 0.
            
            customAttributeData.push_back(nIndex);
            cout << nIndex << endl;
            customAttributeData.push_back(distance(line.getVertices()[i], vertexOne));
            
            auto vertexTwo = line.getVertices()[i] - offset;
            meshy.addVertex(vertexTwo);
            customAttributeData.push_back(nIndex);
            customAttributeData.push_back(distance(line.getVertices()[i], vertexTwo));
        }
        
        ofSetColor(color);
        mesh = meshy;
        //meshy.draw();
        
    } else {
        
       // mesh.draw();
    }
    
}

//---------------------------------------------------

void ofxSoundBrush::drawJigglyLines(int thickness, int jiggleAmount){
    
    if(drawing){
        ofVboMesh meshy;
        meshy.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
        
        auto wiggledPoints = line.getVertices();
        
        if (wiggledPoints.size() > 3){
            for(int i = 3; i < wiggledPoints.size()-3; i++){
                wiggledPoints[i].x += ofRandomf() * jiggleAmount;
                wiggledPoints[i].y += ofRandomf() * jiggleAmount;
            }
        }
        
        ofPolyline wiggledLine;
        wiggledLine.addVertices(wiggledPoints);
        
        for (int i = 0;  i < wiggledLine.getVertices().size(); i++){
            int me_m_one = i-1;
            int me_p_one = i+1;
            if (me_m_one < 0) me_m_one = 0;
            if (me_p_one ==  wiggledLine.getVertices().size()) me_p_one =  wiggledLine.getVertices().size()-1;
            ofPoint diff = wiggledLine.getVertices()[me_p_one] - wiggledLine.getVertices()[me_m_one];
            float angle = atan2(diff.y, diff.x);
            float dist = diff.length();
            ofPoint offset;
            offset.x = cos(angle + PI/2) * thickness;
            offset.y = sin(angle + PI/2) * thickness;
            meshy.addVertex(  wiggledLine.getVertices()[i] +  offset );
            meshy.addVertex(  wiggledLine.getVertices()[i] -  offset );
        }
        
        ofSetColor(color);
        mesh = meshy;
        //meshy.draw();
        
    } else {
        
        for(auto & vertex : mesh.getVertices()){
            vertex.x += ofRandomf() * jiggleAmount;
            vertex.y += ofRandomf() * jiggleAmount;
        }
        
       // mesh.draw();
    }
    
}

//---------------------------------------------------

void ofxSoundBrush::drawJigglyLinesByDist(int weight){
    
    if(drawing){
        ofVboMesh meshy;
        meshy.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
        
        
        auto wiggledPoints = line.getVertices();
        
        int midPoint = wiggledPoints.size() / 2;
        
        if(wiggledPoints.size() > 4){
            for(int i = 0; i < wiggledPoints.size(); i++){
                int steps = abs(midPoint - steps);
                int normalizedSteps = 1 - (steps / midPoint);
                
                wiggledPoints[i].x +=  ofRandom(weight) * normalizedSteps;
                wiggledPoints[i].y += ofRandom(weight) * normalizedSteps;
            }
        }
        
        ofPolyline wiggledLine;
        wiggledLine.addVertices(wiggledPoints);
        
        
        float widthSmooth = 10;
        float angleSmooth;
        
        for (int i = 0;  i < wiggledLine.getVertices().size(); i++){
            
            int me_m_one = i-1;
            int me_p_one = i+1;
            if (me_m_one < 0) me_m_one = 0;
            if (me_p_one ==  wiggledLine.getVertices().size()) me_p_one =  wiggledLine.getVertices().size()-1;
            
            ofPoint diff = wiggledLine.getVertices()[me_p_one] - wiggledLine.getVertices()[me_m_one];
            float angle = atan2(diff.y, diff.x);
            
            if (i == 0) angleSmooth = angle;
            else {
                
                angleSmooth = ofLerpRadians(angleSmooth, angle, 1.0);
                
            }
            
            float dist = diff.length();
            
            float w = ofMap(dist, 0, size, 40, 2, true);
            
            widthSmooth = 0.9f * widthSmooth + 0.1f * w;
            
            ofPoint offset;
            offset.x = cos(angleSmooth + PI/2) * widthSmooth;
            offset.y = sin(angleSmooth + PI/2) * widthSmooth;
            
            meshy.addVertex(  wiggledLine.getVertices()[i] +  offset );
            meshy.addVertex(  wiggledLine.getVertices()[i] -  offset );
            
        }
        
        ofSetColor(color);
        mesh = meshy;
        meshy.draw();
    } else {
        
        auto & vertices = mesh.getVertices();
        
        int midPoint = vertices.size() / 2;
        
        if(vertices.size() > 4){
            for(int i = 0; i < vertices.size(); i++){
                int steps = abs(midPoint - steps);
                int normalizedSteps = 1 - (steps / midPoint);
                
                vertices[i].x +=  ofRandom(-weight, weight) * normalizedSteps;
                vertices[i].y += ofRandom(-weight, weight) * normalizedSteps;
            }
        }
        
        mesh.draw();
    }
    
    
}

//--------------------------------------------------------------------------------------------

void ofxSoundBrush::drawTestLine(){
    
    if(drawing){
        ofVboMesh meshy;
        meshy.setMode(OF_PRIMITIVE_TRIANGLE_STRIP);
        
        float widthSmooth = 10;
        float angleSmooth;
        
        for (int i = 0;  i < line.getVertices().size(); i++){
            
            int me_m_one = i-1;
            int me_p_one = i+1;
            if (me_m_one < 0) me_m_one = 0;
            if (me_p_one ==  line.getVertices().size()) me_p_one =  line.getVertices().size()-1;
            
            ofPoint diff = line.getVertices()[me_p_one] - line.getVertices()[me_m_one];
            float angle = atan2(diff.y, diff.x);
            
            if (i == 0) angleSmooth = angle;
            else {
                
                angleSmooth = ofLerpDegrees(angleSmooth, angle, 1.0);
                
            }
            
            float dist = diff.length();
            
            float w = ofMap(dist, 0, size, 40 + 10 * sin(ofRadToDeg(i)), 1, true);
            
            widthSmooth = 0.5f * widthSmooth + 0.5f * w;
            
            ofPoint offset;
            offset.x = cos(angleSmooth + PI/2) * widthSmooth + 20 * ofNoise(line.getVertices()[i].x/100.0 + rSeed);
            offset.y = sin(angleSmooth + PI/2) * widthSmooth + 20 * ofNoise(line.getVertices()[i].y/100.0 + rSeed);
            
            meshy.addVertex(  line.getVertices()[i] +  offset );
            meshy.addVertex(  line.getVertices()[i] -  offset );
            
        }
        
        ofSetColor(color);
        mesh = meshy;
        meshy.draw();
        
    } else {
        
        mesh.draw();
    }
    
    //    ofSetColor(100,100,100);
    //    meshy.drawWireframe();
}
