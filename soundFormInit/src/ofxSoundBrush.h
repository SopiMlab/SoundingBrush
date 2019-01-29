#pragma once
#include "ofMain.h"

//TODO: Patch names? Methods of sending params?

#include "ofxCurve.h"

static glm::vec2 lerp( const glm::vec2 A, const glm::vec2 B, float t ){
    return A*t + B*(1.0f-t) ;
}

class ofxSoundBrush{
public:
    ofxSoundBrush(); //default contructor
    
    void setup(string _patch); //constructor with patch name!
    void setup(string _patch, int _bType);
    
    void setVariables(float _w, ofColor _c); //cam dynamic variables work? Check!
    void setBrushType(int _bType) {brushType = _bType;}; //selects the drawing algo to draw - pair with setup?
    
    void addPoint(glm::vec2 _p);
    
    void update(){handleShaders();};
    void draw();
    
    void setColor(ofColor _c);
    void setSize(float _s);
    void setAlpha(float _a);
    
    void calculateDataSet();
    void calculateSD();
    
    string getPatch() {return patch;};
    int getNumVertices() {return points.size();};
    float getJitterOnMinorAxis();
    
    void setDollarZeroString(string _dZero) {dollarZeroString = _dZero;};
    string getDollarZeroString() {return dollarZeroString;};
    
private:
    string patch;
    ofColor color;
    float size;
    vector<glm::vec3> points;
//    vector<glm::vec3> interpolatedPoints;

    float left, right, top, bottom;
    float width, height;
    
    float standardDeviationX, standardDeviationY;
    float varianceX, varianceY;
    
    glm::vec2 sumsXY;
    glm::vec2 average;
    
    string dollarZeroString;
    
    ofPolyline line;
    int brushType;
    
    void drawThickLine();
    void drawWithThicknessFunction(int thickness);
    void drawJigglyLines(int thickness, int jiggleAmount);
    void drawJigglyLinesByDist(int weight);
    
    ofShader mainShader;
    ofShader alphaShader;
    
    ofShader sBlurX, sBlurY;
    
    ofFbo baseFbo;
    ofFbo blurX, blurY;
    ofFbo finalFbo;
    
    bool isDebug;
    float rSeed;
    
    void handleShaders(); //this needs to be wrapped in an update function?
    
};
