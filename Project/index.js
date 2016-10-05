import React, { Component, PropTypes } from 'react';
import {
  DeviceEventEmitter, // android
  NativeAppEventEmitter, // ios
  NativeModules,
  Platform,
  StyleSheet,
  requireNativeComponent,
  View,
} from 'react-native';

const CameraManager = NativeModules.CameraManager || NativeModules.CameraModule;

function convertNativeProps(props) {
  const newProps = { ...props };
  if (typeof props.orientation === 'string') {
    newProps.orientation = Camera.Constants.Orientation[props.orientation];
  }

  if (typeof props.torchMode === 'string') {
    newProps.torchMode = Camera.Constants.TorchMode[props.torchMode];
  }

  if (typeof props.type === 'string') {
    newProps.type = Camera.Constants.Type[props.type];
  }

  return newProps;
}

export default class Camera extends Component {
  static Constants = {
    BarCodeType: CameraManager.BarCodeType,
    Type: CameraManager.Type,
    Orientation: CameraManager.Orientation,
    TorchMode: CameraManager.TorchMode
  };

  static propTypes = {
    ...View.propTypes,
    onBarCodeRead: PropTypes.func,
    barCodeTypes: PropTypes.array,
    orientation: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number
    ]),
    torchMode: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number
    ]),
    type: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number
    ])
  };

  static defaultProps = {
    type: CameraManager.Type.back,
    orientation: CameraManager.Orientation.auto,
    torchMode: CameraManager.TorchMode.off,
    barCodeTypes: Object.values(CameraManager.BarCodeType),
  };

  setNativeProps(props) {
    this.refs[CAMERA_REF].setNativeProps(props);
  }

  componentWillMount() {
    this._addOnBarCodeReadListener()
  }

  componentWillUnmount() {
    this._removeOnBarCodeReadListener()
  }

  render() {
    const style = [styles.base, this.props.style];
    const nativeProps = convertNativeProps(this.props);

    return <RCTCamera {...nativeProps} />;
  }

  _addOnBarCodeReadListener = () => {
    this.cameraBarCodeReadListener = Platform.select({
      ios: NativeAppEventEmitter.addListener('CameraBarCodeRead', this._onBarCodeRead),
      android: DeviceEventEmitter.addListener('CameraBarCodeReadAndroid',  this._onBarCodeRead),
    });
  }

  _removeOnBarCodeReadListener = () => {
    const listener = this.cameraBarCodeReadListener;

    if (listener) {
      listener.remove()
    }
  }

  _onBarCodeRead = (data) => {
    if (this.props.onBarCodeRead) {
      this.props.onBarCodeRead(data)
    }
  };
}

export const Constants = Camera.Constants;

const RCTCamera = requireNativeComponent('RCTCamera', Camera);

const styles = StyleSheet.create({
  base: {},
});
