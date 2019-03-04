#include "ofMain.h"
#include "ofxPd.h"

class ThreadTest : public ofThread{
public:
    void setup(){
        cout << "Thread setup!" << endl;
    }
    
    void threadedFunction(){
        cout << "thread running?" << endl;
        ofSleepMillis(5000);
        cout << "thread closing?" << endl;
    }
    
    ~ThreadTest(){
        cout << "closing!" << endl;
    }
    
    ofxPd * pd;
};
