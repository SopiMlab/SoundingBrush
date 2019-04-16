Sounding Brush is a tablet tool enabling users to express themselves by creating sound and painting at the same time. It has been developed for the iPad using Pure Data and openFrameworks.

# About this repository.
This repository contains two applications, soundformInit and Sounding Brush. SoundFormInit was the initial explorative development platform and contains various bugs and is not recommended to use. However, it is left as is in the repository for posterity, as some of the initial commits might be of interest towards how the platform has been developed and implemented. Sounding Brush is the directory containing the final application that has been used for demos and presentations.

# Dependencies.
Tested and developed on XCode 10.2, iOS 12.2, openFrameworks 0.10.1 and Pure Data 0.49.0.
Additional dependencies: ofxCoreMotion, ofxDatGui, ofxPd.
Note: ofxDatGui needs to be modified to use on the iPad, you can grab a (tested) fork with those modifications as well as some theme tweaks for this project from [here](https://github.com/sourya-sen/ofxDatGui/tree/iosfriendly).

# Installing.
If you don't have openFrameworks already, install the iOS version of openFrameworks and follow instructions from [here]().

Clone this repository and check the folder hierarchy of the app follows the openFrameworks guidelines.

Update the project with Project Generator.

Open with XCode - the project will probably need a provisioning profile as per Apple requirement, for more info check the XCode notes [here](http://mlab.taik.fi/mediacode/archives/13506).

With an iPad connected, XCode should be able to compile and install the application to the device.

# Out of the box functionality.
Select a brush, select a colour and a character and start drawing! The application is set up to be as intuitive as possible, offering multiple brushes, each with their own visual style and sound synthesis engines. Depending on the brush, the colour and character settings can have varying effects both in the audio and visual domains.

For a smoother performance, there is memory management functionality built in, which only allows as certain number of instances of each brush to exist on screen. However, this is not necessarily a restriction and still allows enough scope for audio and visual exploration, performance and composition.

Additionally, the the erase functions allow functionality to erase specific brushes (erase palette erases all the instances of the currently selected brush), the last drawn brush (erase last), or the entirety of the canvas (erase canvas).

The only unique case is the Gesture brush, which, when selected, doesn't require any drawing but makes sounds as long as there is touch input and the device is moved.

# Implementing custom brushes and synthesis engines.
Note: The gesture brush needs to be handled separately and not within the scope of the following instructions. However, it is easy enough to understand and if the custom brushes/synthesis engines are replacing any of the existing implementations, no additional steps needs to be taken. If more brushes are being added, certain arrays need to be resized and is mentioned at the end of the instructions.

As long as the gesture brush is not selected from the brush selection menu, there are three stages as to how a brush and synthesis model are executed.

## On touchDown() events.
When there is a touch down, a new brush is initialized using with the setup function of an instance of ofxSoundBrush, like so
```
ofxSoundBrush b = ofxSoundBrush()
b.setup("pd/sinxy.pd", 2, "0", "0");
```
where the string variable `"pd/sinxy.pd"` is the Pure Data patch that is loaded as part of the brush. The variable 2 selects the mesh algorithm that is used to interpolate the touch inputs to create the mesh and the last two strings are two stages of shaders (base and alpha) that are successively used on the meshes.

## A word on the mesh algorithms and shaders.
The touch inputs within the ofxSoundBrush class are stored as coordinates. However, that doesn't well towards drawing thicker lines and therefore a few different mesh algorithms are used to interpolate the coordinates and making them into nicer looking lines. The mesh algorithms only handle creating the mesh, though and then they are passed through two stages of shaders, called base and alpha. The base shader takes care of colouring the mesh and then that is passed as a texture to the alpha shader. By different combinations of the mesh algorithms, base and alpha shaders, a few different kinds of brushes can be drawn. To implement more methods, for either of the three, mesh algorithms can be added as functions in the ofxSoundBrush class, with the `computeMesh()` function dealing with the selecting and executing of the mesh. The base and alpha shaders are stored in the `bin/data/shaders` folder with each file name having a suffix corresponding to the string in the setup function. New shaders in either case can be added in the same location and the setup function automatically loads the shaders.

## On touchMoved events().
Once a brush has been initialized, moving the finger will add points to the brush and depending on the mesh and shaders that were used in the initialization, a drawing

## On touchUp() events.

## How does the Pure Data patch work?
