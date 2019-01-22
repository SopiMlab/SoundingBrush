#include "ofApp.h"

#import <AVFoundation/AVFoundation.h>

//--------------------------------------------------------------
void ofApp::setup(){
    
    ofSetFrameRate(120);
    ofSetVerticalSync(true);
    ofSetBackgroundColor(ofColor::white);
    ofEnableSmoothing();
    ofEnableAntiAliasing();
    ofDisableArbTex();
    
    ofRegisterTouchEvents(this);
    ofxiOSAlerts.addListener(this);
    
    //GUI stuff.
    ofxGuiSetFont("Questrial-Regular.ttf",20,true,true);
    ofxGuiSetTextPadding(8);
    ofxGuiSetDefaultWidth(300);
    ofxGuiSetDefaultHeight(50);
    
    
    gui.setup();
    gui.add(guiBrushSelector.set("Brush", 0, 0, 5));
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
    
    pd.subscribe("toOF");
    pd.subscribe("toOFStream");
    pd.subscribe("toOFKill");
    
    ofFilePath::getCurrentWorkingDirectory();
    pd.addToSearchPath("pd");
    
    pd.addReceiver(*this);
    
    pd.start();
    
    pinchParam = 0.5f;
    pinchDistCurrent = pinchDistLast = 0;
    
    fbo.allocate(ofGetWidth(), ofGetHeight(), GL_RGB);
    shader.load("shaders/alpha.vert", "shaders/alpha.frag");
    
}

//--------------------------------------------------------------
void ofApp::update(){
    
    if(pd.isQueued()) {
        pd.receiveMessages();
        //pd.receiveMidi();
    }
    
    fbo.begin();
    ofClear(ofColor::yellow);
    shader.begin();
    shader.setUniform1f("alpha", .33);
    glm::vec3 c = glm::vec3(1.0, ofRandomf(), 0.0);
    shader.setUniform3f("col", c.x, c.y, c.z);
    ofSetColor(ofColor::blue);
    ofFill();
    ofDrawCircle(ofGetWidth()/2, ofGetHeight()/2, 300);
    shader.end();
    
    fbo.end();
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    
    fbo.draw(0, 0);
    
//    path.draw();
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
            
            //Setup the kind of brush depending on selection!
            switch(guiBrushSelector){
                case 0:
                    b.setup("pd/sinewithamp.pd");
                    break;
                case 1:
                    b.setup("pd/dtc_mod.pd");
                    break;
                case 2:
                    b.setup("pd/granular-redux.pd");
                    break;
                case 3:
                    b.setup("pd/karplus.pd");
                    break;
                case 4:
                    b.setup("pd/granular_andy.pd");
                    break;
                case 5:
                    b.setup("pd/crackture.pd");
                    break;
            }
            
            b.setVariables(guiWidth, guiColor); //Setup the colour and width of the brush.
            
            brushes.push_back(b);
            
            //Also instantiate the pd patch for the same!
            Patch p = pd.openPatch(brushes[brushes.size() - 1].getPatch());
            brushPatches.push_back(p);
            
            //Get the dollar zero value from the patch to the brush.
            //This will come in handy when I'm receiving stuff from PD.
            string s = brushPatches[brushPatches.size() - 1].dollarZeroStr();
            brushes[brushes.size() - 1].setDollarZeroString(s);
            
            std::cout << "Brushpatches size is now: " << brushPatches.size() << endl;
            
            //Map brush size to frequency
            float f = nlMap(guiWidth, 1.f, 100.f, 6000.f, 40.f, .3); //frequency mapping.
            int fm = ofMap(guiWidth, 1.f, 100.f, 70, 40); //midi mapping
            
            //This will initialize the brush/synth combo.
            pd.startMessage();
            
            //next part depends on the kind of brush...
            //init goes to $0-fromOFinit
            switch(guiBrushSelector){
                case 0: //sinewithamp, needs just one parameter.
                    pd.addFloat(f);
                    break;
                case 1: //detune chorus, need midi note, type of waveform, index and ratio.
                    pd.addFloat(fm);
                    pd.addFloat(ofRandom(3)); //selects waveform randomly :)
                    pd.addFloat(200);
                    pd.addFloat(.1); //These two are the lowest values of index and ratio, sending to initialize them.
                    break;
                case 2:
                    //Do stuff.
                    pd.addFloat(100);
                    break;
                case 3:
                    //Do stuff.
                    break;
                case 4:
                    pd.addFloat(ofMap(guiWidth, 1, 100, 2, 0.1, true));
                    break;
                case 5:
                    //Do stuff.
                    break;
            }
            
            pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOFinit");
            
            init = false;
            bWasTouching = true;
        }
    }
    
    if (touch.id == 1){ //check this!
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
        
        //Updates go to $0-fromOF
        pd.startMessage();
        
        //Again, switch according to brush type!
        switch(guiBrushSelector){
            case 0:
                pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 800, 0, 1, true));
                break;
            case 1:
                pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 700, 200, 500, true));
                pd.addFloat(ofMap(brushes[brushes.size()-1].getJitterOnMinorAxis(), 0, 800, 0.1, 0.3, true));
                pd.addFloat(ofClamp(pinchParam, 0.1, 1));
                break;
            case 2:
                //Do stuff.
                pd.addFloat(100);
                break;
            case 3:
                //Do stuff.
                break;
            case 4:
                pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 1000, 0, 2000));
                break;
            case 5:
                pd.addFloat(ofMap(brushes[brushes.size()-1].getNumVertices(), 1, 1000, 0, 1));
                pd.addFloat(ofMap(brushes[brushes.size()-1].getJitterOnMinorAxis(), 0, 800, 100, 2000, true));
                break;
        }
        
        pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
        
    }
    
    
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    
    if(brushes.size() > 0 && bWasTouching){
        //If there's an EOC to send, send it here.
        
        pd.startMessage();
        switch(guiBrushSelector){
            case 0:
                //do stuff.
                break;
            case 1:
                //do stuff.
                break;
            case 2:
                //do stuff.
                break;
            case 3:
                float karpValue;
                karpValue = brushes[brushes.size()-1].getNumVertices();
                karpValue = ofMap(karpValue, 0, 1000, 40, 70);
                pd.addFloat(karpValue);
                break;
        }
        
        pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOFeoc");
        
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
        if(brushPatches.size() > 0){
            for(int i = 0; i<brushPatches.size(); ++i){
                pd.closePatch(brushPatches[i]);
            }
            brushes.clear();
            brushPatches.clear();
            std::cout << "All patches cleared!" << endl;
        }
       //Anything else on double tap can come here!
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
void ofApp::receiveBang(const std::string& dest){
    cout << "OF: Bang " << dest << endl;
}

//--------------------------------------------------------------
void ofApp::receiveFloat(const std::string& dest, float value){
    cout << "OF: Float " << dest << ": " << value << endl;
    
    if (dest == "toOFKill") closePatchByDollarString(value);
    
}

//--------------------------------------------------------------
void ofApp::receiveList(const std::string& dest, const List& list){
    
    string dollarZero; //the first item is always going to be the dollar zero string.
    vector<float> values; //followed by the rest of the stuff!
    
    if(dest == "toOFStream"){
        
        dollarZero = ofToString(list.getFloat(0));
        
        for(int i = 1; i < list.len(); i++){
            float v = list.getFloat(i);
            values.push_back(v);
        }
    
        //TODO: This is going to be super hacky for now, so fix this later. :)
        
        //Match the dollarZero string to a brush.
        int index = -1;
        
        for(int i = 0; i<brushes.size(); i++){
            if (brushes[i].getDollarZeroString() == dollarZero) index = i;
        }
        
        brushes[index].setAlpha(values[0]);
        
    }
    
}

//--------------------------------------------------------------
void ofApp::closePatchByDollarString(int _dString){
    
    int index = -1;
    
    for(int i = 0; i < brushPatches.size(); i++){
        cout << brushPatches[i].dollarZeroStr() << endl;
        if(brushPatches[i].dollarZeroStr() == ofToString(_dString)){
            index = i;
            cout << "Index updated to: " << index << endl;
        }
    }
    
    //NOTE: This is a bit hacky as the patch itself is not closing - it's causing crashes :(
    //Might need to add in a thing in the pd patch to make sure it gets muted, not necessary for karplus though.
    
    //pd.closePatch(brushPatches[index]);
    brushPatches.erase(brushPatches.begin() + index);
    brushes.erase(brushes.begin() + index);
    
    cout << "Removed element: " << index << endl;
    
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
