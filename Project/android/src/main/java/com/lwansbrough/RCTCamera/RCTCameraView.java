package com.lwansbrough.RCTCamera;

import android.content.Context;
import android.hardware.SensorManager;
import android.view.OrientationEventListener;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.View;

import java.util.List;

public class RCTCameraView extends ViewGroup {
    private final OrientationEventListener _orientationListener;
    private final Context _context;
    private RCTCameraViewFinder _viewFinder = null;
    private int _actualDeviceOrientation = -1;
    private String _captureQuality = "high";
    private int _torchMode = -1;

    public RCTCameraView(Context context) {
        super(context);
        this._context = context;
        RCTCamera.createInstance(getDeviceOrientation(context));

        _orientationListener = new OrientationEventListener(context, SensorManager.SENSOR_DELAY_NORMAL) {
            @Override
            public void onOrientationChanged(int orientation) {
                if (setActualDeviceOrientation(_context)) {
                    layoutViewFinder();
                }
            }
        };

        if (_orientationListener.canDetectOrientation()) {
            _orientationListener.enable();
        } else {
            _orientationListener.disable();
        }
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        layoutViewFinder(left, top, right, bottom);
    }

    @Override
    public void onViewAdded(View child) {
        if (this._viewFinder == child) return;
        // remove and readd view to make sure it is in the back.
        // @TODO figure out why there was a z order issue in the first place and fix accordingly.
        this.removeView(this._viewFinder);
        this.addView(this._viewFinder, 0);
    }

    public void setCameraType(final int type) {
        if (null != this._viewFinder) {
            this._viewFinder.setCameraType(type);
            RCTCamera.getInstance().adjustPreviewLayout(type);
        } else {
            _viewFinder = new RCTCameraViewFinder(_context, type);
            if (-1 != this._torchMode) {
                _viewFinder.setTorchMode(this._torchMode);
            }
            addView(_viewFinder);
        }
    }

    public void setTorchMode(int torchMode) {
        this._torchMode = torchMode;
        if (this._viewFinder != null) {
            this._viewFinder.setTorchMode(torchMode);
        }
    }

    public void setOrientation(int orientation) {
        RCTCamera.getInstance().setOrientation(orientation);
        if (this._viewFinder != null) {
            layoutViewFinder();
        }
    }

    public void setBarCodeTypes(List<String> types) {
        RCTCamera.getInstance().setBarCodeTypes(types);
    }

    private boolean setActualDeviceOrientation(Context context) {
        int actualDeviceOrientation = getDeviceOrientation(context);
        if (_actualDeviceOrientation != actualDeviceOrientation) {
            _actualDeviceOrientation = actualDeviceOrientation;
            RCTCamera.getInstance().setActualDeviceOrientation(_actualDeviceOrientation);
            return true;
        } else {
            return false;
        }
    }

    private int getDeviceOrientation(Context context) {
        return ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getOrientation();
    }

    private void layoutViewFinder() {
        layoutViewFinder(this.getLeft(), this.getTop(), this.getRight(), this.getBottom());
    }

    private void layoutViewFinder(int left, int top, int right, int bottom) {
        if (null == _viewFinder) {
            return;
        }
        float width = right - left;
        float height = bottom - top;
        int viewfinderWidth;
        int viewfinderHeight;
        double ratio;

        // Just fill the given space
        ratio = this._viewFinder.getRatio();
        if (ratio * height < width) {
            viewfinderHeight = (int) (width / ratio);
            viewfinderWidth = (int) width;
        } else {
            viewfinderWidth = (int) (ratio * height);
            viewfinderHeight = (int) height;
        }

        int viewFinderPaddingX = (int) ((width - viewfinderWidth) / 2);
        int viewFinderPaddingY = (int) ((height - viewfinderHeight) / 2);

        this._viewFinder.layout(viewFinderPaddingX, viewFinderPaddingY, viewFinderPaddingX + viewfinderWidth, viewFinderPaddingY + viewfinderHeight);
        this.postInvalidate(this.getLeft(), this.getTop(), this.getRight(), this.getBottom());
    }
}
