#include "ofMain.h"
#include "ofxPd.h"

//--------------------------------------------------
class ThreadedTimer : public ofThread{
public:
    void setup(){
    }
    
    void threadedFunction(){
        sleep(100);
    }
    
    ~ThreadedTimer(){
        cout << "closing!" << endl;
    }
};
