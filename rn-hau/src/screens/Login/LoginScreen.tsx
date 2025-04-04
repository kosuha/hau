import { View, Text, ViewStyle, TouchableOpacity } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../../styles/theme';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Path } from 'react-native-svg';

const LoginScreen = () => {
  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <View style={{
          flex: 1,
          justifyContent: 'space-between',
          alignItems: 'center',
          width: '100%',
          marginTop: 70,
          marginBottom: 70,
        }}>
          <View style={{
            gap: 10,
            width: '100%',
            paddingHorizontal: 38,
          }}>
            <Text style={{
              fontSize: 28,
              fontWeight: 'bold',
              color: colors.primary,
            }}>How are you?</Text>
            <Text style={{
              fontSize: 24,
              color: colors.secondary,
              fontWeight: 'medium',
            }}>오늘 당신의 하루는 어떤가요?</Text>
          </View>
          <View style={{
            gap: 12,
            width: '100%',
            paddingHorizontal: 20,
          }}>
            <TouchableOpacity style={{
              backgroundColor: "#000",
              padding: 16,
              borderRadius: 999,
              borderWidth: 1,
              justifyContent: 'center',
              alignItems: 'center',
              flexDirection: 'row',
              gap: 6,
            }}>
              <Ionicons name="logo-apple" size={22} color={colors.light} />
              <Text style={{
                color: colors.light,
                fontSize: 16,
                fontWeight: 'bold',
              }}>Apple로 시작하기</Text>
            </TouchableOpacity>
            <TouchableOpacity style={{
              backgroundColor: "#fff",
              padding: 16,
              borderRadius: 999,
              borderWidth: 1,
              borderColor: colors.light,
              justifyContent: 'center',
              alignItems: 'center',
              flexDirection: 'row',
              gap: 6,
            }}>
              <Svg width={22} height={22} viewBox="0 0 48 48" fill="none">
                <Path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z" />
                <Path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z" />
                <Path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z" />
                <Path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24C44,22.659,43.862,21.35,43.611,20.083z" />
              </Svg>
              <Text style={{
                color: colors.dark,
                fontSize: 16,
                fontWeight: 'bold',
              }}>Google로 시작하기</Text>
            </TouchableOpacity>
          </View>
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
    backgroundColor: colors.quaternary,
    width: '100%',
  },
};

export default LoginScreen;