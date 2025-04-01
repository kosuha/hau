import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { View, Text, StyleSheet, ViewStyle, TouchableOpacity, TextStyle } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { LinearGradient } from 'expo-linear-gradient';
import { SafeAreaView, SafeAreaProvider } from 'react-native-safe-area-context';
import { colors, gradients } from '../../styles/theme';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../../navigation/AppNavigator';
import { Ionicons } from '@expo/vector-icons';

type NavigationProp = NativeStackNavigationProp<RootStackParamList, 'Settings'>;

const SettingsHeader = ({ onPress, title }: { onPress: () => void, title?: string }) => {
  return (
    <View style={{
      flexDirection: 'row',
      justifyContent: 'center',
      alignItems: 'center',
      paddingHorizontal: 20,
      height: 60
    }}>
      <TouchableOpacity onPress={onPress} style={{ position: 'absolute', left: 20 }}>
        <Ionicons name="chevron-back" size={24} color="black" />
      </TouchableOpacity>
      {title && (
        <Text style={{ alignSelf: 'center', fontSize: 18, fontWeight: 'bold' }}>{title}</Text>
      )}
    </View>
  );
};

const SettingsItem = ({ title, onPress }: { title: string, onPress: () => void }) => {
  return (
    <TouchableOpacity onPress={onPress}>
      <Text style={{ fontSize: 16 }}>{title}</Text>
    </TouchableOpacity>
  );
};

const SettingsScreen = () => {
  const navigation = useNavigation<NavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <SettingsHeader onPress={() => navigation.goBack()} />
        <View style={styles.content}>
          <View style={{
            flexDirection: 'row',
            justifyContent: 'space-between',
            alignItems: 'center',
            paddingHorizontal: 20,
            height: 78,
            backgroundColor: colors.secondaryLight,
            borderRadius: 16,
            width: '100%',
          }}>
            <Text style={{ fontSize: 18, fontWeight: 'bold' }}>나의 멤버십</Text>
            <Text style={{ fontSize: 14 }}>1개월</Text>
          </View>
          
          <View style={{
            
          }}>
            <View style={{ gap: 16, marginBottom: 16 }}>
              <Text style={{ fontSize: 18, fontWeight: 'bold' }}>설정</Text>
              <View style={styles.divider} />
            </View>
            <View style={styles.menu}>
              <SettingsItem title="프로필" onPress={() => {}} />
              <SettingsItem title="통화 시간 설정" onPress={() => {}} />
              <SettingsItem title="목소리 설정" onPress={() => {}} />
            </View>
          </View>

          <View style={{
            
          }}>
            <View style={{ gap: 16, marginBottom: 16 }}>
              <Text style={{ fontSize: 18, fontWeight: 'bold' }}>기타</Text>
              <View style={styles.divider} />
            </View>
            <View style={styles.menu}>
              <SettingsItem title="오픈소스 라이브러리" onPress={() => {}} />
              <SettingsItem title="문의하기" onPress={() => {}} />
              <SettingsItem title="이용약관" onPress={() => {}} />
              <SettingsItem title="개인정보처리방침" onPress={() => {}} />
            </View>
          </View>


        </View>
      </SafeAreaView>
      <StatusBar style="dark" />
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
  header: ViewStyle;
  title: TextStyle;
  content: ViewStyle;
  divider: ViewStyle;
  menu: ViewStyle;
}

const styles = StyleSheet.create<Style>({
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
    gap: 40,
  },
  menu: {
    flexDirection: 'column',
    gap: 20,
    width: '100%',
  },
  divider: {
    height: 1,               
    backgroundColor: colors.text, 
    width: '100%',  
  },
});

export default SettingsScreen;