import { View, Text, ViewStyle, TouchableOpacity, TextStyle } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { RootStackParamList } from '../../navigation/AppNavigator';
import { colors } from '../../styles/theme';

type AppNavigationProp = NativeStackNavigationProp<RootStackParamList, 'Permission'>;

const PermissionScreen = () => {
  const AppNavigation = useNavigation<AppNavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => AppNavigation.navigate('Main')} isClose={true} />
        <View style={styles.content}>
          <View style={{
            flex: 1,
            width: '100%',
            flexDirection: 'column',
            gap: 84,
          }}>
            <View>
              <Text style={styles.title}>통화하기 위해</Text>
              <Text style={styles.title}>필요한 권한을 승인해 주세요.</Text>
            </View>
            <View style={{
              flexDirection: 'column',
              gap: 36,
            }}>
              <View style={{
                flexDirection: 'column',
                gap: 12,
              }}>
                <Text style={{
                  fontSize: 20,
                  fontWeight: 'bold',
                }}>알림</Text>
                <Text style={{
                  fontSize: 16,
                }}>주기적으로 전화 알림을 받을 수 있어요.</Text>
              </View>
              <View style={{
                flexDirection: 'column',
                gap: 12,
              }}>
                <Text style={{
                  fontSize: 20,
                  fontWeight: 'bold',
                }}>마이크</Text>
                <Text style={{
                  fontSize: 16,
                }}>통화하기 위해 필요해요.</Text>
              </View>
            </View>
          </View>
          <View>
            <TouchableOpacity 
              style={{
                backgroundColor: colors.primary,
                padding: 16,
                borderRadius: 999,
                borderWidth: 1,
                justifyContent: 'center',
                alignItems: 'center',
                flexDirection: 'row',
                gap: 6,
                height: 56,
                marginBottom: 37,
              }} 
              onPress={() => AppNavigation.navigate('Main')}
            >
              <Text style={{
                color: colors.light,
                fontSize: 16,
                fontWeight: 'bold',
              }}>승인하기</Text>
            </TouchableOpacity>
          </View>
        </View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
  content: ViewStyle;
  title: TextStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 10,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
  content: {
    flex: 1,
    width: '100%',
    flexDirection: 'column',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 26,
    fontWeight: 'bold',
  },
};

export default PermissionScreen;