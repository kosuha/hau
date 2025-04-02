import { View, Text, ViewStyle } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { RootStackParamList } from '../../navigation/AppNavigator';

type AppNavigationProp = NativeStackNavigationProp<RootStackParamList, 'Main'>;

const PermissionScreen = () => {
  const AppNavigation = useNavigation<AppNavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => AppNavigation.navigate('Main')} isClose={true} />
        <View>
          <Text>권한 설정</Text>
        </View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
};

export default PermissionScreen;