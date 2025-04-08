import { View, Text, ViewStyle, TextInput, TouchableOpacity, TextStyle, KeyboardAvoidingView, ScrollView, Platform, Alert } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { SettingsStackParamList } from '../../navigation/SettingsStackNavigator';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../../styles/theme';
import { useState } from 'react';

type SettingsNavigationProp = NativeStackNavigationProp<SettingsStackParamList, 'Profile'>;

const ProfileScreen = () => {
  const settingsNavigation = useNavigation<SettingsNavigationProp>();
  const [text, setText] = useState('');
  const maxLength = 2000;

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => {
          Alert.alert('주의', '저장하지 않은 내용은 사라집니다.', [
            { text: '취소', style: 'cancel' },
            { text: '나가기', onPress: () => {
              settingsNavigation.goBack();
            } },
          ]);
        }} title="프로필" />
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1, width: '100%' }}
        >
          <ScrollView 
            contentContainerStyle={{ flexGrow: 1 }}
            keyboardShouldPersistTaps="handled"
          >
        <View style={styles.content}>
          <View style={{ gap: 34 }}>
            <View style={{ gap: 8 }}>
              <Text style={styles.inputTitle}>이름</Text>
              <TextInput style={{
                borderWidth: 1,
                borderColor: 'gray',
                borderRadius: 14,
                paddingHorizontal: 20,
                height: 50,
                fontSize: 16,
              }} />
            </View>
            <View style={{ gap: 8 }}>
              <Text style={styles.inputTitle}>생년월일</Text>
              <TouchableOpacity style={{
                borderWidth: 1,
                borderColor: 'gray',
                borderRadius: 14,
                paddingHorizontal: 20,
                height: 50,
                justifyContent: 'center',
                alignItems: 'flex-start',
              }}>
                <Text style={{
                  fontSize: 16,
                }}>1990.01.01</Text>
              </TouchableOpacity>
            </View>
            <View style={{ gap: 8 }}>
              <Text style={styles.inputTitle}>나의 이야기</Text>
              <Text style={{
                fontSize: 14,
                color: colors.secondary,
              }}>나의 이야기는 통화할 때 항상 기억하고 있어요.</Text>
              <View style={styles.inputContainer}>
                <TextInput
                  style={styles.input}
                  placeholder="이야기를 적어주세요."
                  multiline={true}
                  numberOfLines={8}
                  maxLength={maxLength}
                  textAlignVertical="top"
                  value={text}
                  onChangeText={setText}
                />
                <View style={styles.characterCount}>
                  <Text style={styles.characterCountText}>
                    {text.length}/{maxLength}
                  </Text>
                </View>
              </View>
            </View>
            <View style={styles.logoutContainer}>
              <TouchableOpacity>
                <Text style={styles.logoutText}>로그아웃</Text>
              </TouchableOpacity>
              <TouchableOpacity>
                <Text style={styles.logoutText}>회원탈퇴</Text>
              </TouchableOpacity>
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
              onPress={() => {}}
            >
              <Text style={{
                color: colors.light,
                fontSize: 16,
                fontWeight: 'bold',
              }}>저장하기</Text>
            </TouchableOpacity>
            </View>
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}; 

interface Style {
  container: ViewStyle;
  content: ViewStyle;
  logoutContainer: ViewStyle;
  logoutText: TextStyle;
  saveButton: ViewStyle;
  inputTitle: TextStyle;
  inputContainer: ViewStyle;
  input: TextStyle;
  characterCount: ViewStyle;
  characterCountText: TextStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
  content: {
    flex: 1,
    width: '100%',
    paddingHorizontal: 20,
    justifyContent: 'space-between',
  },
  inputTitle: {
    fontSize: 16,
    fontWeight: 'medium',
  },
  logoutContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 24,
    marginTop: 22,
    marginBottom: 32,
  },
  logoutText: {
    color: colors.disabled,
    fontSize: 16,
    textDecorationLine: 'underline',
  },
  saveButton: {
    backgroundColor: colors.primary,
    padding: 10,
    borderRadius: 14,
  },
  inputContainer: {
    borderWidth: 1,
    borderColor: 'gray',
    borderRadius: 14,
    padding: 20,
    height: 300,
  },
  input: {
    flex: 1,
    textAlignVertical: 'top',
    fontSize: 16,
  },
  characterCount: {
    position: 'absolute',
    bottom: 10,
    right: 10,
  },
  characterCountText: {
    fontSize: 12,
    color: colors.disabled,
  },
};

export default ProfileScreen;