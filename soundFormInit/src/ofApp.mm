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
    //    ofSetOrientation(OFXIOS_ORIENTATION_LANDSCAPE_LEFT);
    
    
    ofRegisterTouchEvents(this);
    ofxiOSAlerts.addListener(this);
    
    
    //DATGUISTUFF.
    gBrushOptions = {"Across", "Line", "Three Waves", "Kar+Paint", "Particles", "Crackler", "Gesture"};
    gBrushSelector = new ofxDatGuiDropdown("Brush selector", gBrushOptions);
    gBrushSelector->setPosition(0, 20);
    //    gBrushSelector->setWidth(100);
    gBrushSelector->select(gBrushOptions.size() - 1);
    gBrushSelector->setTheme(new ofxDatGuiThemeSoundingBrush());
    gBrushSelector->onDropdownEvent(this, &ofApp::onDropDownEvent);
    selectedBrushFromGui = 6; //placeholder -> make sure this corresponds to gBrushSelector->select(index) otherwise nasty things will happen /s
    
    hue = 127;
    sat = 127;
    bright = 127;
    
    colorFromGui = ofColor::fromHsb(hue, sat, bright);
    
    gColorSelectorF = new ofxDatGuiFolder("Color Selector", ofColor::white);
    gColorSelectorF->addSlider("Hue", 0, 360, 180);
    gColorSelectorF->addSlider("Saturation", 0, 100, 50);
    gColorSelectorF->addSlider("Brightness", 0, 1, 0.5);
    gColorSelectorF->setPosition(550, 20);
    gColorSelectorF->setTheme(new ofxDatGuiThemeSoundingBrush());
    gColorSelectorF->onSliderEvent(this, &ofApp::onSliderEvent);
    
    //    gColorPicker = new ofxDatGuiColorPicker("Select Color!", ofColor::yellow);
    //    gColorPicker->setPosition(600, 0);
    //    gColorPicker->ofxDatGuiComponent::setWidth(100, 100);
    //    gColorPicker->onColorPickerEvent(this, &ofApp::onColorPickerEvent);
    
    brushWidthFromGui = 20.0;
    gBrushWidth = new ofxDatGuiSlider("Character", 1, 100);
    gBrushWidth->setPosition(1100, 20);
    //    gBrushWidth->setWidth(100, 100);
    gBrushWidth->onSliderEvent(this, &ofApp::onSliderEvent);
    gBrushWidth->setValue(brushWidthFromGui);
    gBrushWidth->setTheme(new ofxDatGuiThemeSoundingBrush());
    
    /*
     gClearScreen = new ofxDatGuiButton("Clear canvas");
     gClearScreen->setPosition(1650, 0);
     gClearScreen->setWidth(ofGetWidth() - 1650);
     //    gClearScreen->setTheme(new ofxDatGuiThemeSoundingBrush());
     gClearScreen->onButtonEvent(this, &ofApp::onButtonEvent);
     */
    
    gBrushErasers = new ofxDatGuiFolder("Erase", ofColor::yellow);
    gBrushErasers->addButton("Last");
    gBrushErasers->addButton("Palette");
    gBrushErasers->addButton("Canvas");
    gBrushErasers->setPosition(1650, 20);
    gBrushErasers->setTheme(new ofxDatGuiThemeSoundingBrush());
    gBrushErasers->setWidth(ofGetWidth() - 1650);
    gBrushErasers->onButtonEvent(this, &ofApp::onButtonEvent);
    
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
    tuningRange = {0 , 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19, 20, 22, 24};
    rootNote = 45;
    
    //Let's load up the sampleSynth patch.
    Patch p = pd.openPatch("pd/SampleSynth.pd");
    brushPatches.push_back(p);
    
    dollarIndexes.resize(8);
    storageLimits = {6, 4, 2, 4, 2, 2, 1, 1, 1};
    
    qKill = false;
    
}

//--------------------------------------------------------------
void ofApp::update(){
    ofScopedLock lock(scopeLock);
    
    gBrushSelector->update();
    //    gColorPicker->update();
    gColorSelectorF->update();
    gBrushWidth->update();
    //    gClearScreen->update();
    gBrushErasers->update();
    
    if(pd.isQueued()) {
        pd.receiveMessages();
        //pd.receiveMidi();
    }
    
    for(auto &b : brushes){
        b.update();
    }
    
    //Get the core motion data.
    coreMotion.update();
    accel = coreMotion.getAccelerometerData();
    
    if(selectedBrushFromGui == 6){
        if(bFingerDown == true){
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
    
    
    //----------------Check the status of the timer thread + killing info.
    if(qKill == true){
        if(timer.isThreadRunning()){
            //do nothing, wait for envelop to finish!
        } else {
//            cout << "Thread done counting at: " << ofGetElapsedTimeMillis() << endl;
            
            int killDString = brushPatches[qKillIndex].dollarZero();
            
//            cout << "Closing patch" << endl;
            pd.closePatch(brushPatches[qKillIndex]);
//            cout << "Erasing from vector" << endl;
            brushPatches.erase(brushPatches.begin() + qKillIndex);
//            cout << "Erasing brush" << endl;
            brushes.erase(brushes.begin() + qKillIndex - 1); //qKillIndex is always going to be offset by one thanks to the gesture brush.
            
//            cout << "Did PD + Brush routine" << endl;
            
            int x, y;
            //also find the relevant index and delete it from the dollar indexes...
            for(int i = 0; i<dollarIndexes.size(); i++){
                for(int j = 0; j < dollarIndexes[i].size(); j++){
                    if(killDString == dollarIndexes[i][j]){
                        x = i;
                        y = j;
                        //                        cout << "found x: " << x << " and y: " << y << endl;
                    }
                }
            }
            
            dollarIndexes[x].erase(dollarIndexes[x].begin() + y);
            
            //The indexes have moved by -1 now, so update the queue list, if there's stuff in there.
            for(int i = 0; i<queuedKillList.size(); i++){
                queuedKillList[i] -= 1;
            }
            
            qKill = false;
            
        }
    }
    
    if(qKill == false){
        if(queuedKillList.size() > 0){
            qKillIndex = queuedKillList[0];
            queuedKillList.erase(queuedKillList.begin());
            timer.startThread();
            qKill = true;
        }
    }
    //-------------
    
}

//--------------------------------------------------------------
void ofApp::draw(){
    
    ofSetColor(ofColor::white);
    ofDrawRectangle(0, 0, ofGetWidth(), ofGetHeight());
    
    for(auto &b : brushes){
        b.draw();
    }
    
    //    stringstream debug;
    //
    //    debug << "Number of instances and strokes is: " << ofToString(brushPatches.size()) << " Frame rate is: " << ofGetFrameRate() << endl;
    //
    //    ofDrawBitmapStringHighlight(debug.str(), glm::vec2(0, ofGetHeight() - 10.0f));
    
    gBrushSelector->draw();
    gColorSelectorF->draw();
    //    gColorPicker->draw();
    gBrushWidth->draw();
    gBrushErasers->draw();
    //    gClearScreen->draw();
    
}

//--------------------------------------------------------------
void ofApp::exit(){
    ofSoundStreamStop();
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    
    if(touch.id == 0) firstTouch = glm::vec2(touch.x, touch.y);
    if(touch.id == 1) secondTouch = glm::vec2(touch.x, touch.y);
    
    //    (s.inside(touch.x, touch.y)) ? bGuiMode = true : bGuiMode = false;
    //    bGuiMode = false; //Temporary!
    
    if((gBrushSelector->hitTest(touch)) || (gBrushErasers->hitTest(touch)) || (gColorSelectorF->hitTest(touch)) || (gBrushWidth->hitTest(touch))){
        bGuiMode = true;
    } else if ((gBrushSelector->getIsExpanded()) || (gColorSelectorF->getIsExpanded() || (gBrushErasers->getIsExpanded()))){
        bGuiMode = true;
    } else {
        bGuiMode = false;
    }
    
//    if(gBrushSelector->getIsExpanded()){
//        if (gBrushSelector->hitTest(touch) == false) gBrushSelector->collapse();
//    }
//
//    if(gBrushErasers->getIsExpanded()){
//        if (gBrushErasers->hitTest(touch) == false) gBrushErasers->collapse();
//    }
//
//    if(gColorSelectorF->getIsExpanded()){
//        if (gColorSelectorF->hitTest(touch) == false) gColorSelectorF->collapse();
//    }
    
    if(!bGuiMode) bFingerDown = true;
    if(selectedBrushFromGui == 6) return;
    
    if(!bGuiMode){
        if(init){
            //Make a new brush and add it to the vector of brushes.
            ofxSoundBrush b = ofxSoundBrush();
            
            //Setup the kind of brush depending on selection!
            switch(selectedBrushFromGui){
                case 0:
                    b.setup("pd/sinxy.pd", 2, "0", "0");
                    break;
                case 1:
                    //b.setup("pd/addsin.pd", 1);
                    b.setup("pd/sinenv.pd", 2, "0", "0");
                    break;
                case 2:
                    //                    b.setup("pd/granular-redux.pd", 0);
                    b.setup("pd/basslinergb.pd", 1, "3", "3");
                    break;
                case 3:
                    b.setup("pd/karplus.pd", 2, "1", "2");
                    break;
                case 4:
                    b.setup("pd/granular_andy.pd", 1, "4", "4");
                    brushWidthFromGui *= 1.25; //override to make fatter
                    break;
                case 5:
                    b.setup("pd/crackture.pd", 1, "5", "5");
                    brushWidthFromGui *= 1.1; //same as above
                    break;
//                case 6:
//                    b.setup("pd/BasslineR.pd", 1);
//                    break;
//                case 7:
//                    b.setup("pd/testadsr.pd", 0);
//                    break;
            }
            
            b.setVariables(brushWidthFromGui, colorFromGui); //Setup the colour and width of the brush.
            
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
            
            //store the $0-string in the vector too.
            dollarIndexes[selectedBrushFromGui].push_back(ofToInt(s));
            
            //check if there's more than set limits here and then delete accordingly!
            if(dollarIndexes[selectedBrushFromGui].size() > storageLimits[selectedBrushFromGui]){
                closePatchByDollarString(dollarIndexes[selectedBrushFromGui][0]);
                //                dollarIndexes[selectedBrushFromGui].erase(dollarIndexes[selectedBrushFromGui].begin());
            }
            
//            std::cout << "Brushpatches size is now: " << brushPatches.size() << endl;
            
            //Map brush size to frequency
            float f = nlMap(brushWidthFromGui, 1.f, 150.f, 4186.009f, 27.5f, .3); //frequency mapping.
            int fm = ofMap(brushWidthFromGui, 1.f, 150.f, 108, 21); //midi mapping
            
            //This will initialize the brush/synth combo.
            pd.startMessage();
            
            //next part depends on the kind of brush...
            //init goes to $0-fromOFinit
            switch(selectedBrushFromGui){
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
                    
                    pd.addFloat(hue/255.0);
                    pd.addFloat(sat/255.0);
                    pd.addFloat(1.0 - bright/255.0);
                    pd.addFloat(brushWidthFromGui * 10); //not 100% why I'm doing this anymore 13.2
                    break;
                case 3:
                    //Do stuff.
                    break;
                case 4:
                    pd.addFloat(ofMap(brushWidthFromGui, 1, 100, 2, 0.1, true));
                    break;
                case 5:
                    //Do stuff.
                    break;
                case 6:
                    pd.addFloat(f);
                    pd.addFloat(brushWidthFromGui * 10);
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
        
        if (selectedBrushFromGui == 6) return;
        
        if(brushes.size() > 0 && bWasTouching){
            
            ofxSoundBrush * currentBrush = &brushes[brushes.size() - 1];
            
            auto lastVertex = currentBrush->getLastVertex();
            auto distanceToLastVertex = ofDist(lastVertex.x, lastVertex.y, firstTouch.x, firstTouch.y);
            
            //Add points to the last brush instance.
            if(distanceToLastVertex > 6) currentBrush->addPoint(firstTouch);
//            cout << currentBrush->getNumVertices() << endl;
            
            //Updates go to $0-fromOF
            pd.startMessage();
            
            //Again, switch according to brush type!
            switch(selectedBrushFromGui){
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
                    pd.addFloat(ofMap(currentBrush->getLastVertex().x, 0.0, ofGetWidth(), 80, 1000));
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
//                        cout << "adding" << endl;
                        filterParam += dd;
                        filterParam *= filterParam;
                        env = 1;
                    } else {
//                        cout << "zeroing out!" << endl;
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
            
            
            if(selectedBrushFromGui != 8){
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
        switch(selectedBrushFromGui){
            case 0:
                //do stuff.
                break;
            case 1:
                float nv;
                nv = brushes[brushes.size()-1].getNumVertices();
                nv = ofClamp(nv, 100, 3000);
                pd.addFloat(nv);
                break;
            case 2:
                //do stuff.
                float v;
                v = brushes[brushes.size()-1].getNumVertices();
                pd.addFloat(v);
                break;
            case 3:
                float mappedValue, karpValue;
                //map the number of vertices to the range of notes available.
                mappedValue = brushes[brushes.size()-1].getNumVertices();
                //                cout << "RAW: " << mappedValue << endl;
                mappedValue = ofClamp(mappedValue, 5, 100);
                mappedValue = ofMap(mappedValue, 5, 100, 0, 15);
                //                cout << "MAPPED: " << mappedValue << endl;
                karpValue = rootNote + tuningRange[int(mappedValue)];
                //                karpValue = brushes[brushes.size()-1].getNumVertices();
                //                karpValue = ofMap(karpValue, 0, 1000, 40, 70);
                //                cout << "NOTE: " << karpValue << endl;
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
//    cout << "OF: Bang " << dest << endl;
}

//--------------------------------------------------------------
void ofApp::receiveFloat(const std::string& dest, float value){
    //cout << "OF: Float " << dest << ": " << value << endl;
    
    if(dest == "toOFKill"){
        for(int i = 0; i<brushes.size(); i++){
            if(ofToString(value) == brushes[i].getDollarZeroString()){
                brushes[i].disable();
            }
        }
    }
    
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
        
        if((index > 0) && (index < brushes.size())){
            if (brushes[index].drawing == false){
                float mappedValue = nlMap(values[0], 0, 100, 0, 255, 2);
                brushes[index].setAlpha(mappedValue);
            }
        }
        
    }
    
}

//--------------------------------------------------------------
void ofApp::closePatchByDollarString(int _dString){
    
    int index = -1;
    
    for(int i = 0; i < brushPatches.size(); i++){
        //        cout << brushPatches[i].dollarZeroStr() << endl;
        if(brushPatches[i].dollarZeroStr() == ofToString(_dString)){
            index = i;
            //            cout << "Index updated to: " << index << endl;
        }
    }
    
    pd.sendBang(brushPatches[index].dollarZeroStr() + "-OFKillMessage");
    //    ofSleepMillis(99);
    //    pd.closePatch(brushPatches[index]);
    
    //    brushPatches.erase(brushPatches.begin() + index);
    //    brushes.erase(brushes.begin() + index);
    //
    //    cout << "Removed element: " << index << endl;
    
//    cout << ofToString(_dString) << endl;
    
    if(timer.isThreadRunning() == false){
//        cout << "Starting timer to kill patch" << endl;
        qKillIndex = index;
        qKill = true;
        timer.startThread();
    } else {
//        cout << "Timer is running to adding to queue" << endl;
        queuedKillList.push_back(index);
    }
    
//    cout << "Thread started at: " << ofGetElapsedTimeMillis() << endl;
    
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

//--------------------------------------------------------------
//DATGUI EVENT HANDLERS.
//--------------------------------------------------------------
void ofApp::onDropDownEvent(ofxDatGuiDropdownEvent e){
    selectedBrushFromGui = e.child;
    init = true;
}

////--------------------------------------------------------------
//void ofApp::onColorPickerEvent(ofxDatGuiColorPickerEvent e){
////    cout << e.color << endl;
//}

//--------------------------------------------------------------
void ofApp::onSliderEvent(ofxDatGuiSliderEvent e){
    string label = e.target->getLabel();
    
    if (label == "Hue"){
        hue = (e.value / 360.0) * 255;
    } else if (label == "Saturation"){
        sat = (e.value / 100.0) * 255;
    } else if (label == "Brightness"){
        bright = e.value * 255;
    } else {
        brushWidthFromGui = e.value;
        rootNote = int(ofMap(e.value, 0, 100, 30, 45));
    }
    
    colorFromGui = ofColor::fromHsb(hue, sat, bright);
    gColorSelectorF->setBackgroundColor(colorFromGui);
}

//--------------------------------------------------------------
void ofApp::onButtonEvent(ofxDatGuiButtonEvent e){
    
    string label = e.target->getLabel();
    
    if(label == "Last"){
        clearLastBrush();
        gBrushErasers->collapse();
    } else if (label == "Palette"){
        clearPalette();
        gBrushErasers->collapse();
    } else if (label == "Canvas"){
        clearCanvas();
        gBrushErasers->collapse();
        
        //        if (timer.isThreadRunning() == true){
        //            timer.stopThread();
        //            qKill = false;
        //            queuedKillList.clear();
        //        }
        //
        //        if(brushPatches.size() > 0){
        //            for(int i = 0; i<brushPatches.size(); ++i){
        //                pd.closePatch(brushPatches[i]);
        //            }
        //
        //            dollarIndexes.clear();
        //            dollarIndexes.resize(8);
        //            brushes.clear();
        //            brushPatches.clear();
        //            std::cout << "All patches cleared!" << endl;
        //        }
        
    }
    
}

//--------------------------------------------------------------
void ofApp::clearPalette(){
    
    //    if (timer.isThreadRunning() == true){
    //        timer.stopThread();
    //        qKill = false;
    //        queuedKillList.clear();
    //    }
    
    if (selectedBrushFromGui == 6) return;
    
    for(int i = 0; i < dollarIndexes[selectedBrushFromGui].size(); i++){
        closePatchByDollarString(dollarIndexes[selectedBrushFromGui][i]);
    }
    
    //    dollarIndexes[selectedBrushFromGui].clear();
    
//    cout << "Palette cleared" << endl;
}

//--------------------------------------------------------------
void ofApp::clearLastBrush(){
    
    if (dollarIndexes[selectedBrushFromGui].size() == 0) return;
    if (selectedBrushFromGui == 6) return;
    
    //    if (timer.isThreadRunning() == true){
    //        timer.stopThread();
    //        qKill = false;
    //        queuedKillList.clear();
    //    }
    
    int dollarString = dollarIndexes[selectedBrushFromGui][dollarIndexes[selectedBrushFromGui].size() - 1];
    
    closePatchByDollarString(dollarString);
    
    //    dollarIndexes[selectedBrushFromGui].pop_back();
    
//    cout << "Last brush cleared" << endl;
    
}
//--------------------------------------------------------------
void ofApp::clearCanvas(){
    for(int i = 1; i<brushPatches.size(); i++){
        closePatchByDollarString(brushPatches[i].dollarZero());
    }
}

