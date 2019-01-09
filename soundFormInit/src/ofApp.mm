#include "ofApp.h"

#import <AVFoundation/AVFoundation.h>

//--------------------------------------------------------------
void ofApp::setup(){
    
    ofSetFrameRate(120);
    ofSetVerticalSync(true);
    ofSetBackgroundColor(ofColor::white);
    ofEnableSmoothing();
    ofEnableAntiAliasing();
    
    ofRegisterTouchEvents(this);
    ofxiOSAlerts.addListener(this);
    
    //GUI stuff.
    ofxGuiSetFont("Questrial-Regular.ttf",20,true,true);
    ofxGuiSetTextPadding(8);
    ofxGuiSetDefaultWidth(300);
    ofxGuiSetDefaultHeight(50);
    
    
    gui.setup();
    gui.add(guiBrushSelector.set("Brush", 0, 0, 1));
    gui.add(guiWidth.set("Width", 1, 1, 100));
    gui.add(guiColor.set("Color",ofColor(100,100,140),ofColor(0,0),ofColor(255,255)));
    
    //Doing audio setup now.
    float sampleRate = setAVSessionSampleRate(44100);
    int ticksPerBuffer = 8;
    
    ofSoundStreamSettings settings;
    settings.numInputChannels = 1;
    settings.numOutputChannels = 2;
    settings.sampleRate = sampleRate;
    settings.bufferSize = ofxPd::blockSize() * ticksPerBuffer;
    settings.setInListener(this);
    settings.setOutListener(this);
    
    ofSoundStreamSetup(settings);
    
    if(!pd.init(2, 1, sampleRate, ticksPerBuffer-1, false)) {
        OF_EXIT_APP(1);
    }
    
    ofFilePath::getCurrentWorkingDirectory();
    pd.addToSearchPath("pd");
    
    pd.addReceiver(*this);
    
    pd.start();
    
    pinchParam = 0.5f;
    pinchDistCurrent = pinchDistLast = 0;
    
    //    pd.openPatch(brush.getPatch());
    
    //    test.setStrokeWidth(10);
    //    test.setFilled(false);
    //    test.setStrokeColor(ofColor::yellow);
    //    test.moveTo(ofGetWidth()/2, ofGetHeight()/2);
    //    test.curveTo(0, 0);
    //    test.curveTo(0, ofGetHeight());
    //    test.close();
    
    
}

//--------------------------------------------------------------
void ofApp::update(){
    
    if(pd.isQueued()) {
        pd.receiveMessages();
        //pd.receiveMidi();
    }
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    
    gui.draw();
    
    for(int i = 0; i < brushes.size(); i++){
        brushes[i].draw();
    }
    
    
    stringstream debug;
    
    debug << "Number of instances and strokes is: " << ofToString(brushPatches.size()) << " Frame rate is: " << ofGetFrameRate() << endl;
    
    ofDrawBitmapStringHighlight(debug.str(), glm::vec2(0, ofGetHeight() - 10.0f));
    
    gui.draw();
}

//--------------------------------------------------------------
void ofApp::exit(){
    ofSoundStreamStop();
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    
    ofRectangle s = gui.getShape();
    if(touch.id == 0) firstTouch = glm::vec2(touch.x, touch.y);
    if(touch.id == 1) secondTouch = glm::vec2(touch.x, touch.y);
    
    (s.inside(touch.x, touch.y)) ? bGuiMode = true : bGuiMode = false;
    
    if(!bGuiMode){
        if(init){
            //Make a new brush and add it to the vector of brushes.
            ofxSoundBrush b = ofxSoundBrush();
            b.setup("pd/dtc_mod.pd");
            b.setVariables(guiWidth, guiColor);
            brushes.push_back(b);
            //Also instantiate the pd patch for the same!
            Patch p = pd.openPatch(brushes[brushes.size() - 1].getPatch());
            brushPatches.push_back(pd.openPatch(brushes[brushes.size() - 1].getPatch()));
            //Map brush size to frequency //TODO: This needs to be handled better per brush type.
            float f = nlMap(guiWidth, 1.f, 100.f, 6000.f, 40.f, .3); //frequency mapping.
            int fm = ofMap(guiWidth, 1.f, 100.f, 70, 40); //midi mapping
            
            //Sending three floats. TODO: This has to be dependant on the type of synth engine, yolo.
            
            //This one is for sinewithamp, needs three floats.
            /*
             pd.startMessage();
             pd.addFloat(f);
             pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 500, 0, 1, true));
             pd.addFloat(22.1f);
             pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
             */
            
            
            //DTC Init.
            pd.startMessage();
            pd.addFloat(fm);
            pd.addFloat(ofRandom(3)); //arbitrarily select the waveform.
            pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOFinit");
            
            
            
            //This is for detune-chorus, int (MIDI), float (index), float (frequency?), int (wavetable).
            //            pd.startMessage();
            //            pd.addFloat(fm);
            //            pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 500, 0, 100, true));
            //            pd.addFloat(10);
            //            pd.addFloat(1);
            //            pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
            
            
            //pd.sendFloat(brushPatches[brushPatches.size() - 1].dollarZeroStr()+"-fromOF", f); //The last float value is being sent.
            init = false;
            bWasTouching = true;
        }
    }
    
    if (touch.numTouches == 2){
        float d = ofDist(firstTouch.x, firstTouch.y, secondTouch.x, secondTouch.y);
        pinchDistLast = pinchDistCurrent = d;
        pinchParam = 0.5;
    }
    
    
}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){
    
    if(touch.id == 0) firstTouch = glm::vec2(touch.x, touch.y);
    if(touch.id == 1) secondTouch = glm::vec2(touch.x, touch.y);
    
    if(touch.id == 1){
    pinchDistCurrent = ofDist(firstTouch.x, firstTouch.y, secondTouch.x, secondTouch.y);

    if(pinchDistCurrent > pinchDistLast) {
        pinchParam += 0.01;
        pinchDistLast = pinchDistCurrent;
    } else if (pinchDistCurrent < pinchDistLast) {
        pinchParam -= 0.01;
        pinchDistLast = pinchDistCurrent;
    }
    }
    
    
    if(brushes.size() > 0 && bWasTouching){
        //Add points to the last brush instance.
        brushes[brushes.size() - 1].addPoint(firstTouch);
        //Keep updating //TODO: HOW? //This is one option!
        
        float f = nlMap(guiWidth, 1.f, 100.f, 6000.f, 80.f, .3);
        int fm = ofMap(guiWidth, 1.f, 100.f, 127, 0); //midi mapping
        
        
        //        pd.startMessage();
        //        pd.addFloat(f);
        //        pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 500, 0, 1, true));
        //        pd.addFloat(22.1f);
        //        pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
        
        pd.startMessage();
        pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 700, 200, 500, true));
        pd.addFloat(ofMap(brushes[brushes.size()-1].getJitterOnMinorAxis(), 0, 800, 0.1, 0.3, true));
        pd.addFloat(ofClamp(pinchParam, 0.1, 1));
        pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
        
        //        pd.sendFloat(brushPatches[brushPatches.size() - 1].dollarZeroStr()+"-fromOF", touch.x);
    }
    
    
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    
    if(brushes.size() > 0 && bWasTouching){
        //pd.sendFloat(brushPatches[brushPatches.size() - 1].dollarZeroStr()+"-fromOF", touch.x);
        init = true;
        bWasTouching = false;
    }
    
    if(touch.id == 0){
        pinchParam = 0.5;
        pinchDistCurrent = pinchDistLast = 0.0f;
    }
    
    
}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs & touch){
    
    ofRectangle s = gui.getShape();
    
    if(s.inside(touch)){
        for(int i = 0; i<brushPatches.size(); i++){
            pd.closePatch(brushPatches[i]);
        }
        
        brushes.clear();
        brushPatches.clear();
    }
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::lostFocus(){
    
}

//--------------------------------------------------------------
void ofApp::gotFocus(){
    
}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning(){
    
}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation){
    
}

//--------------------------------------------------------------
void ofApp::audioReceived(float * input, int bufferSize, int nChannels) {
    pd.audioIn(input, bufferSize, nChannels);
}

//--------------------------------------------------------------
void ofApp::audioRequested(float * output, int bufferSize, int nChannels) {
    pd.audioOut(output, bufferSize, nChannels);
}

//--------------------------------------------------------------
void ofApp::print(const std::string& message) {
    cout << message << endl;
}

//--------------------------------------------------------------
// set the samplerate the Apple approved way since newer devices
// like the iPhone 6S only allow certain sample rates,
// the following code may not be needed once this functionality is
// incorporated into the ofxiOSSoundStream
// thanks to Seth aka cerupcat
float ofApp::setAVSessionSampleRate(float preferredSampleRate) {
    
    NSError *audioSessionError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // disable active
    [session setActive:NO error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // set category
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker error:&audioSessionError];
    if(audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // try to set the preferred sample rate
    [session setPreferredSampleRate:preferredSampleRate error:&audioSessionError];
    if(audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // *** Activate the audio session before asking for the "current" values ***
    [session setActive:YES error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    ofLogNotice() << "AVSession samplerate: " << session.sampleRate << ", I/O buffer duration: " << session.IOBufferDuration;
    
    // our actual samplerate, might be differnt aka 48k on iPhone 6S
    return session.sampleRate;
}
