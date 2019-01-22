#pragma once

//Core
#include "ofMain.h"
#include "ofxiOS.h"
#include "ofxiOSExtras.h"

//Addons
#include "ofxPd.h"
#include "ofxGui.h"

//Classes
#include "ofxSoundBrush.h"

using namespace pd;

class ofApp : public ofxiOSApp, public PdReceiver, public PdMidiReceiver {
	
    public:
        void setup();
        void update();
        void draw();
        void exit();
	
        void touchDown(ofTouchEventArgs & touch);
        void touchMoved(ofTouchEventArgs & touch);
        void touchUp(ofTouchEventArgs & touch);
        void touchDoubleTap(ofTouchEventArgs & touch);
        void touchCancelled(ofTouchEventArgs & touch);

        void lostFocus();
        void gotFocus();
        void gotMemoryWarning();
        void deviceOrientationChanged(int newOrientation);
    
    //--------------------ofxPdStuff here.
    // audio callbacks
    void audioReceived(float * input, int bufferSize, int nChannels);
    void audioRequested(float * output, int bufferSize, int nChannels);
    
    
    // pd message receiver callbacks
    void print(const std::string& message);
    
    /*
    void receiveBang(const std::string& dest);
    void receiveFloat(const std::string& dest, float value);
    void receiveSymbol(const std::string& dest, const std::string& symbol);
    void receiveList(const std::string& dest, const List& list);
    void receiveMessage(const std::string& dest, const std::string& msg, const List& list);
    
    // pd midi receiver callbacks
    void receiveNoteOn(const int channel, const int pitch, const int velocity);
    void receiveControlChange(const int channel, const int controller, const int value);
    void receiveProgramChange(const int channel, const int value);
    void receivePitchBend(const int channel, const int value);
    void receiveAftertouch(const int channel, const int value);
    void receivePolyAftertouch(const int channel, const int pitch, const int value);
    
    void receiveMidiByte(const int port, const int byte);
     */
    
    void receiveBang(const std::string& dest);
    void receiveFloat(const std::string& dest, float value);
    void receiveList(const std::string& dest, const List& list);
    
    float setAVSessionSampleRate(float preferredSampleRate);
    
    //----------------------------ofxGuiStuff here.
    ofParameter<float> guiWidth;
    ofParameter<ofColor> guiColor;
    ofParameter<int> guiBrushSelector;
    ofxPanel gui;
    
//    int guiBrushSelector;
    
    //*******************************************************
    //App Stuff Below!
    
    ofxPd pd;
    
    vector<ofxSoundBrush> brushes;
    vector<Patch> brushPatches;
    
    bool init = true;
    bool bGuiMode = false;
    bool bWasTouching = false;
    
    glm::vec2 firstTouch;
    glm::vec2 secondTouch;
    
    void closePatchByDollarString(int _dString);
    
    
    //Should the pinch geesture be made into a proper thing?
    float pinchParam;
    float pinchDistLast, pinchDistCurrent;
    bool bSecondFinger;
    
    //TODO: SETUP AND STORE A STRUCT FOR INFO BEING SENT.
    
    
    //======================================Other important tidbits.
    //Non linear mapping function.
    float nlMap(float in, float inMin, float inMax, float outMin, float outMax, float shaper){
        
        // (1) convert to pct (0-1)
        float pct = ofMap(in, inMin, inMax, 0, 1, true);
        
        // raise this number to a power
        pct = powf(pct, shaper);
        float out = ofMap(pct, 0,1, outMin, outMax, true);
        return out;
    }
    
    //------------------------------------------------------------
    
    /*
     
     From Zach on oF Forum:
     If shaper is 1, you get linear output like ofMap.
     
     If not, you can shape the output.
     Shaper > 1 means you'll have non linear steps weighted towards the start.
     If shaper is < 1 and > 0 you can get non linear range weighted towards the end.
     There are plenty of other shaper functions that take a pct (a number between 0 and 1) and output a pct, which might help.
     */

};


