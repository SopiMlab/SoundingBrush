#include "ofApp.h"

#import <AVFoundation/AVFoundation.h>

//--------------------------------------------------------------
void ofApp::setup(){
    
    ofSetFrameRate(60);
    ofSetVerticalSync(true);
    ofSetBackgroundColor(ofColor::white);
    ofEnableSmoothing();
    ofEnableAntiAliasing();
    ofDisableArbTex();
    //    ofEnableDepthTest();
    
    ofRegisterTouchEvents(this);
    ofxiOSAlerts.addListener(this);
    
    //GUI stuff.
    ofxGuiSetFont("Questrial-Regular.ttf",20,true,true);
    ofxGuiSetTextPadding(8);
    ofxGuiSetDefaultWidth(300);
    ofxGuiSetDefaultHeight(50);
    
    
    gui.setup();
    gui.add(guiBrushSelector.set("Brush", 0, 0, 8));
    gui.add(guiWidth.set("Width", 1, 1, 150));
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
    
    //Core Motion Setup;
    coreMotion.setupAccelerometer();
    
    cycles = 0;
    
    //Let's load up the sampleSynth patch.
    Patch p = pd.openPatch("pd/SampleSynth.pd");
    brushPatches.push_back(p);
    
    //screen.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
    
}

//--------------------------------------------------------------
void ofApp::update(){
    
    if(pd.isQueued()) {
        pd.receiveMessages();
        //pd.receiveMidi();
    }
    
    for(auto &b : brushes){
        b.update();
    }
    
    //    screen.begin();
    //    ofClear(255, 255, 255, 255);
    //    for(auto &b : brushes){
    //        b.draw();
    //    }
    //    screen.end();
    
    //Get the core motion data.
    coreMotion.update();
    accel = coreMotion.getAccelerometerData();
    
    if(guiBrushSelector == 8){
        if(bFingerDown == false){
            pd.startMessage();
            
            pd.addFloat(accel.x);
            pd.addFloat(accel.y);
            pd.addFloat(accel.z);
            pd.addFloat(bFingerDown);
            pd.addFloat(firstTouch.x);
            pd.addFloat(firstTouch.y);
            
            
            pd.finishList(brushPatches[0].dollarZeroStr()+"-fromOF");
        }
    }
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    
    ofSetColor(ofColor::white);
    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    
    for(auto &b : brushes){
        b.draw();
    }
    
    //    screen.draw(0, 0);
    
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
    
    bFingerDown = true;
    
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
                    b.setup("pd/sinxy.pd", 0);
                    break;
                case 1:
                    //b.setup("pd/addsin.pd", 1);
                    b.setup("pd/sinxy.pd", 0);
                    break;
                case 2:
//                    b.setup("pd/granular-redux.pd", 0);
                    b.setup("pd/basslinergb.pd", 1);
                    break;
                case 3:
                    b.setup("pd/karplus.pd", 2);
                    break;
                case 4:
                    b.setup("pd/granular_andy.pd", 0);
                    break;
                case 5:
                    b.setup("pd/crackture.pd", 1);
                    break;
                case 6:
                    b.setup("pd/BasslineR.pd", 1);
                    break;
                case 7:
                    b.setup("pd/testadsr.pd", 0);
                    break;
            }
            
            b.setVariables(guiWidth, guiColor); //Setup the colour and width of the brush.
            
            brushes.push_back(b);
            
            ofxSoundBrush * currentBrush = &brushes[brushes.size() - 1];
            
            currentBrush->addPoint(touch);
            
            //Also instantiate the pd patch for the same!
            Patch p = pd.openPatch(currentBrush->getPatch());
            brushPatches.push_back(p);
            
            //Get the dollar zero value from the patch to the brush.
            //This will come in handy when I'm receiving stuff from PD.
            string s = brushPatches[brushPatches.size() - 1].dollarZeroStr();
            currentBrush->setDollarZeroString(s);
            
            std::cout << "Brushpatches size is now: " << brushPatches.size() << endl;
            
            //Map brush size to frequency
            float f = nlMap(guiWidth, 1.f, 150.f, 4186.009f, 27.5f, .3); //frequency mapping.
            int fm = ofMap(guiWidth, 1.f, 150.f, 108, 21); //midi mapping
            
            //This will initialize the brush/synth combo.
            pd.startMessage();
            
            //next part depends on the kind of brush...
            //init goes to $0-fromOFinit
            switch(guiBrushSelector){
                case 0: //sinewithamp, needs just one parameter.
                    //                    pd.addFloat(f);
                    break;
                case 1: //detune chorus, need midi note, type of waveform, index and ratio.
                    //                    pd.addFloat(fm);
                    //                    pd.addFloat(ofRandom(3)); //selects waveform randomly :)
                    //                    pd.addFloat(200);
                    //                    pd.addFloat(.1); //These two are the lowest values of index and ratio, sending to initialize them.
                    //                    pd.addFloat(255.0/guiColor->r);
                    //                    pd.addFloat(255.0/guiColor->g);
                    //                    pd.addFloat(255.0/guiColor->b);
                    break;
                case 2:
                    //Do stuff.
//                    pd.addFloat(100); //???
                    
                    pd.addFloat(guiColor->r/255.0);
                    pd.addFloat(guiColor->g/255.0);
                    pd.addFloat(guiColor->b/255.0);
                    pd.addFloat(guiWidth * 10); //not 100% why I'm doing this anymore 13.2
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
                case 6:
                    pd.addFloat(f);
                    pd.addFloat(guiWidth * 10);
                    pd.addFloat(ofRandomuf());
                    break;
                case 7:
                    //do stuff.
                    filterParam = 0;
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
    
    bFingerDown = true;
    cycles ++;
    
    if(cycles%2 == 0){
        
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
            
            ofxSoundBrush * currentBrush = &brushes[brushes.size() - 1];
            
            auto lastVertex = currentBrush->getLastVertex();
            auto distanceToLastVertex = ofDist(lastVertex.x, lastVertex.y, firstTouch.x, firstTouch.y);
            
            //Add points to the last brush instance.
            if(distanceToLastVertex > 10) currentBrush->addPoint(firstTouch);
            
            //Updates go to $0-fromOF
            pd.startMessage();
            
            //Again, switch according to brush type!
            switch(guiBrushSelector){
                case 0:
                    //pd.addFloat(ofMap(currentBrush->getNumVertices(), 1, 800, 0, 1, true));
                    //pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0, ofGetWidth(), 80, 1000));
                    //pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0, ofGetWidth(), 10 * (150 - guiWidth), 30 * (150 - guiWidth)));
                    //pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0, ofGetWidth(), 10 * (150 - guiWidth), 30 * (150 - guiWidth)));
                    //pd.addFloat(ofMap(currentBrush->getLastVertex().y, 0, ofGetHeight(), 10 * (150 - guiWidth), 30 * (150 - guiWidth)));
                    pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0.0, ofGetWidth(), 80, 1000));
                    pd.addFloat(ofClamp(pinchParam, 0.1, 1));
                    break;
                case 1:
                    //pd.addFloat(ofMap(currentBrush->getNumVertices(), 1, 700, 200, 500, true));
                    //pd.addFloat(ofMap(currentBrush->getJitterOnMinorAxis(), 0, 800, 0.1, 0.3, true));
                    //pd.addFloat(ofClamp(pinchParam, 0.1, 1));
                    pd.addFloat(ofMap(currentBrush->getLastVertex().y, ofGetHeight(), 0.0, 80, 1000));
                    pd.addFloat(ofClamp(pinchParam, 0.1, 1));
                    break;
                case 2:
                    //Do stuff.
                    pd.addFloat(ofMap(currentBrush->getLastVertex().y, ofGetHeight(), 0, 80, 1000));
                    pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0.0, ofGetWidth(), 1.0, 3.0));
                    break;
                case 3:
                    //Do stuff.
                    break;
                case 4:
                    pd.addFloat(ofMap(currentBrush->getNumVertices(), 1, 1000, 0, 2000));
                    break;
                case 5:
                    pd.addFloat(ofMap(currentBrush->getNumVertices(), 1, 1000, 0, 1));
                    pd.addFloat(ofMap(currentBrush->getJitterOnMinorAxis(), 0, 800, 100, 2000, true));
                    break;
                case 6:
                    //do stuff.
                    //pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0, ofGetWidth(), 80, 1000));
//                    pd.addFloat(guiColor->getBrightness() * 4.0);
                    //                cout << guiColor->getBrightness() << endl;
                    break;
                case 7:
                    float d;
                    d = currentBrush->getLastDistance();
                    float env;
                    //                cout << d << endl;
                    
                    float dd;
                    dd = ofMap(d, 0, 100, 0, .5);
                    
                    if (d > .1){
                        cout << "adding" << endl;
                        filterParam += dd;
                        filterParam *= filterParam;
                        env = 1;
                    } else {
                        cout << "zeroing out!" << endl;
                        filterParam -= 0.1;
                        //                    filterParam = 0;
                        env = 0;
                    }
                    
                    filterParam = ofClamp(filterParam, 0.0, 20.0);
                    
                    pd.addFloat(filterParam);
                    pd.addFloat(env);
                    
                    //pd.addFloat(ofRandomf());
                    pd.addFloat(1.0); //value doesn't matter!
                    break;
                    
                case 8:
                    pd.addFloat(accel.x);
                    pd.addFloat(accel.y);
                    pd.addFloat(accel.z);
                    pd.addFloat(bFingerDown);
                    pd.addFloat(firstTouch.x);
                    pd.addFloat(firstTouch.y);
                    break;
                    
            }
            
            
            if(guiBrushSelector != 8){
                pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOF");
            } else {
                pd.finishList(brushPatches[0].dollarZeroStr()+"-fromOF");
            }
            
        }
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
                float v;
                v = brushes[brushes.size()-1].getNumVertices();
                pd.addFloat(v);
                break;
            case 3:
                float karpValue;
                karpValue = brushes[brushes.size()-1].getNumVertices();
                karpValue = ofMap(karpValue, 0, 1000, 40, 70);
                pd.addFloat(karpValue);
                break;
            case 4:
                //do stuff.
                break;
            case 5:
                //do stuff.
                break;
            case 6:
//                float v;
//                v = brushes[brushes.size()-1].getNumVertices();
//                pd.addFloat(v);
                break;
            case 7:
                pd.addFloat(1.0); //value doesn't matter.
                break;
        }
        
        pd.finishList(brushPatches[brushPatches.size()-1].dollarZeroStr()+"-fromOFeoc");
        
        init = true;
        bWasTouching = false;
        
        brushes[brushes.size() - 1].drawing = false;
    }
    
    if(touch.id == 0){
        pinchParam = 0.5;
        pinchDistCurrent = pinchDistLast = 0.0f;
    }
    
    bFingerDown = false;
    
    
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
            //need an update params function here by brush type, hmm.
        }
        
        if (brushes[index].drawing == false){
            float mappedValue = nlMap(values[0], 0, 100, 0, 255, 2);
            brushes[index].setAlpha(mappedValue);
        }
        
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
