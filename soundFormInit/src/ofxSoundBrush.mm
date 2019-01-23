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
    
    brushType = 1;
    isDebug = false;
    
    baseFbo.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    
    blurX.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    blurY.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    sBlurX.load("shaders/blurX");
    sBlurY.load("shaders/blurY");

    finalFbo.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    
    mainShader.load("shaders/base");
    alphaShader.load("shaders/alpha");
    
    /*
     int totalVertices = 100;
     float yInc = (ofGetHeight()-100)/totalVertices;
     for (int i = 0; i<= totalVertices; i++) {
     pointsF.push_back(ofDefaultVec3(ofGetWidth()* ofRandomuf(), ofGetHeight() * ofRandomuf(), 0));
     ofFloatColor c; c.setHsb(ofRandom(1), 1, 1 );
     colors.push_back(c);
     weights.push_back(10);
     }
     
     fatLine.setCapType(OFX_FATLINE_CAP_ROUND);
     fatLine.setJointType(OFX_FATLINE_JOINT_ROUND);
     
     fatLine.setFeather(2);
     fatLine.add(pointsF, colors, weights);
     */
    
}
//--------------------------------------------------
void ofxSoundBrush::setup(string _patch){
    patch = _patch;
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
    
    calculateDataSet();
    calculateSD();
    
    line = line.getSmoothed(1); //TODO or Not TODO?
    
    baseFbo.begin();
    ofClear(0,0);
    mainShader.begin();
    glm::vec4 c = glm::vec4(color.r/float(255), color.g/float(255), color.b/float(255), 1.0);
    mainShader.setUniform4f("c", c);
    mainShader.setUniform2f("resolution", glm::vec2(ofGetWidth(), ofGetHeight()));
//    mainShader.setUniform1f("alpha", color.a/float(255));
    switch(brushType){
        case 0:
            drawThickLine();
            break;
        case 1:
            drawWithThicknessFunction(size);
            break;
        case 2:
            drawJigglyLines(size, 10);
            break;
        case 3:
            drawJigglyLinesByDist(10);
            break;
    }
    mainShader.end();
    baseFbo.end();
    
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
    alphaShader.setUniform1f("alpha", color.a/float(255));
    baseFbo.draw(0, 0);
    alphaShader.end();
    finalFbo.end();

}

//--------------------------------------------------
void ofxSoundBrush::draw(){
    
//    baseFbo.draw(0, 0);
//    blurX.draw(0, 0);
    finalFbo.draw(0, 0);
    
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
//DIFFERENT KINDS OF BRUSHES. WILL BE A SWITCH CALL
//---------------------------------------------------

//    --------------------------from ofZach/drawing-examples/thickness
//    ----------------------------------------------------------------


void ofxSoundBrush::drawThickLine(){
    
    ofMesh meshy;
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
    meshy.draw();
    
    //    ofSetColor(100,100,100);
    //    meshy.drawWireframe();
}

//---------------------------------------------------


//    --------------------------from ofZach/drawing-examples/thickness-function
//    ----------------------------------------------------------------

void ofxSoundBrush::drawWithThicknessFunction(int thickness){
    ofMesh meshy;
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
        float dist = diff.length();
        ofPoint offset;
        offset.x = cos(angle + PI/2) * thickness;
        offset.y = sin(angle + PI/2) * thickness;
        meshy.addVertex(  line.getVertices()[i] +  offset );
        meshy.addVertex(  line.getVertices()[i] -  offset );
    }
    
    ofSetColor(color);
    meshy.draw();
    
}

//---------------------------------------------------

void ofxSoundBrush::drawJigglyLines(int thickness, int jiggleAmount){
    ofMesh meshy;
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
    meshy.draw();
    
    
}

//---------------------------------------------------

void ofxSoundBrush::drawJigglyLinesByDist(int weight){
    ofMesh meshy;
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
    meshy.draw();
    
    
}
