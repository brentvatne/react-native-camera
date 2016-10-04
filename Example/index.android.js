import React from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View
} from 'react-native';

import Camera from 'react-native-camera';

class CameraTesting extends React.Component {
  render() {
    return (
      <View style={styles.container}>
        <Camera
          onBarCodeRead={this._handleBarCodeRead}
          style={styles.preview} />
      </View>
    );
  }

  _handleBarCodeRead = (data) => {
    alert(JSON.stringify(data));
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1
  },
  preview: {
    ...StyleSheet.absoluteFillObject,
  },
});

AppRegistry.registerComponent('Example', () => CameraTesting);
