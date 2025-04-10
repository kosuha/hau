import React, { createContext, useState, useContext, ReactNode } from 'react';

// 온보딩 데이터 타입 정의
interface UserData {
  birthdate?: Date;
  name?: string;
  selfStory?: string;
  voice?: string;
  callTime?: string;
}

// Context 값 타입 정의
interface UserContextProps {
  userData: UserData;
  updateUserData: (data: Partial<UserData>) => void;
}

// Context 생성 (기본값은 undefined 또는 기본 객체)
const UserContext = createContext<UserContextProps | undefined>(undefined);

// Provider 컴포넌트 생성
interface UserProviderProps {
  children: ReactNode;
}

export const UserProvider: React.FC<UserProviderProps> = ({ children }) => {
  const [userData, setUserData] = useState<UserData>({
    birthdate: new Date(),
    name: '',
    selfStory: '',
    voice: 'Beomsoo',
    callTime: '',
  });

  const updateUserData = (data: Partial<UserData>) => {
    setUserData(prevData => ({ ...prevData, ...data }));
    console.log('User data updated:', { ...userData, ...data }); // 데이터 확인용 로그
  };

  return (
    <UserContext.Provider value={{ userData, updateUserData }}>
      {children}
    </UserContext.Provider>
  );
};

// Context 사용을 위한 커스텀 훅
export const useUser = (): UserContextProps => {
  const context = useContext(UserContext);
  if (!context) {
    throw new Error('useUser must be used within an UserProvider');
  }
  return context;
}; 