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
//    path.clear();
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
    points.push_back(_p);
    calculateDataSet();
    calculateSD();
}

//--------------------------------------------------
void ofxSoundBrush::draw(){
    
    ofPushStyle();
    ofSetColor(color);
    ofFill();
    
    
    for(int i = 0; i< points.size(); i++){
        ofDrawCircle(points[i], size);
    }
    
    ofSetLineWidth(size);
    if(points.size() > 2){
        for(int i = 0; i < points.size() - 1; i++){
            ofDrawLine(points[i], points [i+1]);
        }
    }
    
    //Let's try drawing this w/ an ofPath, TODO: move the path formation to update() and only eval once.
    //    path.clear();
    //    path.setFilled(false);
    //
    //
    //    if (points.size() > 0) path.moveTo(points[0]);
    //
    //    if (points.size() > 1){
    //        for(int i = 1; i < points.size(); i++){
    //            path.curveTo(points[i]);
    //        }
    //        path.close();
    //        path.setStrokeColor(color);
    //        path.setStrokeWidth(100.f);
    //        path.draw();
    //
    //        //debug:
    //        auto v = path.getOutline();
    ////        v.draw();
    //    }
    
    ofPopStyle();
    
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
    float a;
    
    if(width<height){
        a = standardDeviationY;
    } else {
        a = standardDeviationX;
    }
    
    return a;
}

