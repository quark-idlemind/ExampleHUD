// This script is an example of how you can make your HUD movable and resizable
// without requiring going into EDIT mode.
//
// Please see https://github.com/quark-idlemind/ExampleHUD for a description of
// this script.
//
// Please do not sell this script but feel free to incorporate the logic.  It
// would be nice if you let Quark Idlemind know if you do use this script.

// Clarity over optimization was the goal for this script.  I encourage you to
// make enhancements or optimizations public.

// BackgroundName is the name of the prim that has the background of the HUD.
// Setting this to the empty string will default to the root prim.  This is only
// used if the object was not created by the "Configure Example HUD" script.
string BackgroundName = "HUD";

// ResizeArea is the boundary of the corner to resize from.
// This is based on the background texture.  The example texture
// is 512x256 pixels and the resize area is the lower left
// 64 pixels.
//
//    64/512 = 0.125
//    64/256 = 0.25
vector ResizeArea = <0.125, 0.25, 0>;

// Face is the number of the face on the HUD that is showing on the screen.
integer Face = 0;

// The variables below are automatically set.

integer glass;        // Set to the link number of the "Glass"
integer background;    // Set to the link number of the HUD background.

// TouchState is what state the touch is in.
// Negative values imply we are resizing or moving.
// Positive values are the link number that was touched.
integer TouchState;
integer Moving = -1;
integer Resizing = -2;

vector TouchOrigin;     // The initial place on the screen we touched.
vector Origin;            // Position of the HUD on the screen before moving.
float TouchSize;        // Base size of the HUD for scaling.
vector TouchLast;       // Last place we touched the HUD
float CurrentScale;        // Current scale factor of the HUD.
float MinScale;         // Smallest scale we can become.

// MapPrims finds the HUD and Glass prims.
MapPrims() {
    integer n = llGetNumberOfPrims();

    // If the "Configure Example HUD" script was used it has stored
    // the link number of the background in Linkset Data so use that.
    background =  (integer)llLinksetDataRead("BackgroundPrim");
    for (;n > 0; --n) {
        string name = llGetLinkName(n);
        if (name == "Glass") {
            glass = n;
        } else if (background == 0 && name == BackgroundName) {
            background = n;
        }
    }
    if (background == 0) {
        background = 1;
    }
}

vector GetVectorParam(integer link, integer number) {
    return llList2Vector(llGetLinkPrimitiveParams(link, [number]), 0);
}

// ResetGlass sets the Glass prim to just cover the HUD and be slightly proud.
ResetGlass() {
    vector size = GetVectorParam(background, PRIM_SIZE);
    vector pos;
    if (background != 1) {
        pos = GetVectorParam(background, PRIM_POS_LOCAL);
    }
    // Make the glass just a bit thicker than the background so you touch it
    // rather than
    // touching the background.
    size.z += .01;
    llSetLinkPrimitiveParamsFast(glass, [
        PRIM_SIZE, size,
        PRIM_POS_LOCAL, pos,
        PRIM_TEXTURE, -1, TEXTURE_TRANSPARENT, <1, 1, 0>, <0, 0, 0>, 0
    ]);
}

// EnlargeGlass make the glass cover the entire screen.
EnlargeGlass() {
    llSetLinkPrimitiveParamsFast(glass, [
        PRIM_SIZE, <10, 10, 10>
    ]);
}

// InitTouch determines what the purpose of the touch was.
// It will either return the link number touched or it will
// return Moving or Resizing.
integer InitTouch() {
    integer prim = llDetectedLinkNumber(0);
    if (prim != glass) {
        return prim;
    }
    if (llDetectedTouchFace(0) != Face) {
        return 0;
    }

    // This is where we initially touched the screen.
    TouchOrigin = llDetectedTouchPos(0);
    TouchOrigin.x = 0;
    
    vector v = GetVectorParam(background, PRIM_SIZE);
    v.z = 0;
    TouchSize = llVecMag(v);

    // This is the magic to determine if the touched the
    // resize area in the lower left corner.  Adjust this
    // as needed.
    v = llDetectedTouchUV(0);
    if (v.x < ResizeArea.x && v.y < ResizeArea.y) {
        // This is the smallest the HUD can be made without distorting.
        MinScale = llGetMinScaleFactor();
        CurrentScale = 1.0;
        return Resizing;
    }

    // This is where we started from on the screen.
    Origin = GetVectorParam(1, PRIM_POS_LOCAL);
    return Moving;
}

// HandleTouch handles the incoming stream of touch events when
// moving or resizing the HUD.
HandleTouch() {
    // v will contain the location on the screen that we touched.
    // The x coordinate is depth into the screen which we don't need.
    vector v = llDetectedTouchPos(0);
    v.x = 0;
    if (v == TouchLast) {
        return;
    }
    TouchLast = v;

    v = v - TouchOrigin;

    if (TouchState == Moving) {
        v += Origin;
        llSetLinkPrimitiveParamsFast(1, [PRIM_POSITION, v]);
        return;
    }

    float scale = llVecMag(v * 2) / TouchSize;
    // Determine if they have moved towards the center (shrinking) or away (enlarging).
    //    For resizing from the lower left:  if (v.y < 0 && v.z > 0) {
    //    For resizing from the lower right: if (v.y > 0 && v.z > 0) {
    //    For resizing from the upper left:  if (v.y < 0 && v.z < 0) {
    //    For resizing from the upper right: if (v.y > 0 && v.z < 0) {
    if (v.y < 0 && v.z > 0) {
        // We are shrinking
        scale = 1 - scale;
        if (scale < MinScale) {
            scale = MinScale;
        }
    } else {
        // We are enlarging
        scale = 1 + scale;
    }
    // CurrentScale is initialized by InitTouch to 1.0.
    llScaleByFactor(scale / CurrentScale);
    CurrentScale = scale;
}

default {
    state_entry() {
        if (BackgroundName == "") {
            BackgroundName = llGetObjectName();
        }
        MapPrims();
        ResetGlass();
    }

    changed(integer what) {
        if (what & CHANGED_LINK) {
            // Make sure our link numbers didn't change.
            MapPrims();
        }
        
    }

    touch_start(integer n) {
        TouchState = InitTouch();
        if (TouchState < 0) {
            EnlargeGlass();
            return;
        }
        llOwnerSay("Touched " + llGetLinkName(TouchState));
    }

    touch(integer n) {
        if (TouchState < 0) {
            HandleTouch();
            return;
        }
    }

    touch_end(integer n) {
        if (TouchState < 0) {
            ResetGlass();
            return;
        }
    }
}
