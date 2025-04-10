import { View, Text, ViewStyle, TextInput, TouchableOpacity, TextStyle, KeyboardAvoidingView, ScrollView, Platform, Alert } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { SettingsStackParamList } from '../../navigation/SettingsStackNavigator';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../../styles/theme';
import { useState } from 'react';
import { useUser } from '../../context/UserContext';
import DateTimePicker, { DateTimePickerEvent } from '@react-native-community/datetimepicker';
import Modal from 'react-native-modal';

type SettingsNavigationProp = NativeStackNavigationProp<SettingsStackParamList, 'Profile'>;

const ProfileScreen = () => {
  const settingsNavigation = useNavigation<SettingsNavigationProp>();
  const maxLength = 2000;
  const { userData, updateUserData } = useUser();
  
  const [selectedDate, setSelectedDate] = useState(userData.birthdate || new Date());
  const [name, setName] = useState(userData.name || '');
  const [selfStory, setSelfStory] = useState(userData.selfStory || '');
  
  const [showDatePicker, setShowDatePicker] = useState(false);

  const onChangeDate = (event: DateTimePickerEvent, date?: Date) => {
    if (date) {
      setSelectedDate(date);
      if (Platform.OS === 'android') {
        setShowDatePicker(false);
      }
    } else {
      if (Platform.OS === 'android') {
        setShowDatePicker(false);
      }
    }
  };

  const closeDatePickerModal = () => {
    setShowDatePicker(false);
  };

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
              <TextInput 
                value={name}
                onChangeText={setName}
                style={{
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
              <TouchableOpacity onPress={() => {
                setShowDatePicker(true);
              }} style={{
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
                }}>{selectedDate.toLocaleDateString('ko-KR')}</Text>
              </TouchableOpacity>
              <Modal
                isVisible={showDatePicker}
                onBackdropPress={closeDatePickerModal}
                onSwipeComplete={closeDatePickerModal}
                swipeDirection="down"
                style={styles.bottomSheetModal}
              >
                <View style={styles.modalContent}>
                  <DateTimePicker
                    value={selectedDate}
                    mode="date"
                    display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                    onChange={onChangeDate}
                    locale="ko-KR"
                  />
                  {Platform.OS === 'ios' && (
                    <TouchableOpacity onPress={closeDatePickerModal} style={styles.confirmButton}>
                       <Text style={styles.confirmButtonText}>확인</Text>
                    </TouchableOpacity>
                  )}
                </View>
              </Modal>
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
                  value={selfStory}
                  onChangeText={setSelfStory}
                />
                <View style={styles.characterCount}>
                  <Text style={styles.characterCountText}>
                    {selfStory.length}/{maxLength}
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
              onPress={() => {
                updateUserData({
                  name: name,
                  birthdate: selectedDate,
                  selfStory: selfStory,
                });
                settingsNavigation.goBack();
              }}
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
  bottomSheetModal: ViewStyle;
  modalContent: ViewStyle;
  confirmButton: ViewStyle;
  confirmButtonText: TextStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
    backgroundColor: colors.light,
  },
  content: {
    flex: 1,
    width: '100%',
    paddingHorizontal: 20,
    justifyContent: 'space-between',
  },
  inputTitle: {
    fontSize: 16,
    fontWeight: '500',
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
  bottomSheetModal: {
    justifyContent: 'flex-end',
    margin: 0,
  },
  modalContent: {
    backgroundColor: 'white',
    padding: 20,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    gap: 20,
  },
  confirmButton: {
    backgroundColor: colors.primary,
    padding: 16,
    borderRadius: 999,
    borderWidth: 1,
    justifyContent: 'center',
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    height: 56,
    marginBottom: 20,
  },
  confirmButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
};

export default ProfileScreen;