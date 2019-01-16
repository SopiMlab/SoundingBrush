#pragma once
#include "ofMain.h"

//TODO: Patch names? Methods of sending params?

class ofxSoundBrush{
public:
    ofxSoundBrush(); //default contructor
    
    void setup(string _patch); //constructor with patch name!
    
    void setVariables(float _w, ofColor _c);
    
    void addPoint(glm::vec2 _p);
    
    void draw();
    
    void setColor(ofColor _c);
    void setSize(float _s);
    void setAlpha(float _a);
    
    void calculateDataSet();
    void calculateSD();
    
    string getPatch() {return patch;};
    int getNumVertices() {return points.size();};
    float getJitterOnMinorAxis();
    
    void setDollarZeroString(string _dZero);
    string getDollarZeroString() {return dollarZeroString;};
    
private:
    string patch;
    ofColor color;
    float size;
    vector<glm::vec2> points;

    float left, right, top, bottom;
    float width, height;
    
    float standardDeviationX, standardDeviationY;
    float varianceX, varianceY;
    
    glm::vec2 sumsXY;
    glm::vec2 average;
    
    string dollarZeroString;
    
//    ofPath path;
};
