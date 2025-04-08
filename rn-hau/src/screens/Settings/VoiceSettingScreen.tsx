import { View, ViewStyle, Text, TouchableOpacity, Alert } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { SettingsStackParamList } from '../../navigation/SettingsStackNavigator';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { colors } from '../../styles/theme';
import { useState } from 'react';

type SettingsNavigationProp = NativeStackNavigationProp<SettingsStackParamList, 'CallTimeSetting'>;

const VoiceItem = ({ title, description, selected, onPress }: { title: string, description: string, selected: boolean, onPress: () => void }) => {
  const borderColor = selected ? colors.primary : colors.disabled;
  const textColor = selected ? colors.dark : colors.disabled;

  return (
    <TouchableOpacity 
      style={{
        gap: 20,
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        borderWidth: 1,
        borderColor: borderColor,
        borderRadius: 20,
        padding: 20,
        height: 130,
      }} 
      onPress={onPress}>
      <Text style={{
        fontSize: 20,
        fontWeight: 'bold',
        color: textColor,
      }}>{title}</Text>
      <Text style={{
        fontSize: 14,
        color: textColor,
      }}>{description}</Text>
    </TouchableOpacity>
  );
};
const VoiceSettingScreen = () => {
  const settingsNavigation = useNavigation<SettingsNavigationProp>();
  const [selectedVoice, setSelectedVoice] = useState<string>('선호');
  
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
        }} title="목소리 설정" />
        <View style={styles.content}>
          <View style={{ gap: 50 }}>
            <Text style={{
              fontSize: 16,
              fontWeight: 'medium',
            }}>원하는 목소리로 통화할 수 있어요.</Text>
            <View style={{ gap: 20 }}>
              <VoiceItem title="범수" description="자상하고 차분한 남자 목소리" selected={selectedVoice === '선호'} onPress={() => setSelectedVoice('선호')} />
              <VoiceItem title="진주" description="친절하고 밝은 여자 목소리" selected={selectedVoice === '주연'} onPress={() => setSelectedVoice('주연')} />
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
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
  content: ViewStyle;
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
};

export default VoiceSettingScreen;

