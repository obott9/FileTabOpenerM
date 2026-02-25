[English](README.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [繁體中文](README_zh_TW.md) | [简体中文](README_zh_CN.md)

# File Tab Opener (macOS 네이티브)

폴더를 Finder 탭으로 일괄 열기 위한 macOS 네이티브 SwiftUI 애플리케이션입니다.

[file_tab_opener](https://github.com/obott9/file_tab_opener)(Python/Tk 버전)의 macOS 네이티브 버전으로, SwiftUI와 Accessibility API를 사용하여 빠르고 안정적인 Finder 탭 제어를 구현합니다.

## 기능

- **탭 그룹 관리** - 탭 그룹 생성, 이름 변경, 복사, 삭제, 순서 변경
- **원클릭 열기** - 탭 그룹의 모든 폴더를 하나의 Finder 윈도우에 탭으로 열기
- **클래식 / 모던 레이아웃** - 기존 버튼 기반 레이아웃과 모던 사이드바 + 상세 패널 레이아웃 전환 가능
- **폴더 기록** - 최근 열었던 폴더 기록 (고정 지원)
- **윈도우 위치 저장** - 탭 그룹별로 Finder 윈도우 위치 및 크기 저장·복원
- **고속 탭 제어** - AX API + AppleScript 하이브리드 방식 (10개 탭을 약 3초에 열기)
- **다크 모드** - macOS 테마 설정에 자동 대응
- **다국어 지원** - 영어, 일본어, 한국어, 번체 중국어, 간체 중국어
- **경로 검증** - 추가 시 경로 존재 확인 및 중복 검사
- **드래그 앤 드롭** - 경로 입력 필드에 폴더를 드롭하여 추가

## 시스템 요구 사항

- macOS 12 Monterey 이상
- Xcode 15 이상 (소스에서 빌드하는 경우)
- 손쉬운 사용 권한 (첫 실행 시 확인 대화 상자가 표시됩니다)

## 빌드

1. Xcode에서 `FileTabOpenerM.xcodeproj` 열기
2. `FileTabOpenerM` 스킴 선택
3. 빌드 및 실행 (Cmd+R)

## 사용 방법

1. 애플리케이션 실행
2. 손쉬운 사용 권한 허용 (Finder 탭 제어에 필요)
3. **+ 탭 추가**로 탭 그룹 생성
4. 경로 입력 필드, **찾아보기...** 또는 드래그 앤 드롭으로 폴더 경로 추가
5. **탭으로 열기**를 클릭하여 모든 폴더를 Finder 탭으로 열기

### 동작 원리

본 애플리케이션은 Finder 탭 제어에 하이브리드 방식을 채택합니다:

1. **AX API** (Accessibility API) - Finder의 "새 탭" 버튼을 프로그래밍 방식으로 눌러 새 탭 생성. 캐시된 AXUIElement 참조와 경량 자식 요소 수 폴링으로 성능 확보.
2. **AppleScript** - `set target of front Finder window`로 각 탭의 경로 설정. 사전 컴파일된 NSAppleScript 핸들러 호출로 재컴파일 오버헤드 제거.
3. **폴백** - 탭 생성 실패 시 나머지 경로를 별도 Finder 윈도우로 열기.

탭 준비 완료 감지는 고정 딜레이가 아닌 AXUIElement 자식 요소 수 변화 모니터링을 사용하므로 Mac 하드웨어 성능에 관계없이 안정적으로 동작합니다.

## 설정

설정은 JSON 형식으로 다음 위치에 저장됩니다:

```
~/Library/Application Support/FileTabOpenerM/config.json
```

설정 파일은 Python 버전(file_tab_opener)과 호환됩니다.

## 로그

로그는 다음 위치에 기록됩니다:

```
~/Library/Logs/FileTabOpenerM/app.log
```

로그 파일은 1 MB를 초과하면 자동 로테이션되며 최대 3세대 백업(`app.log.1`, `app.log.2`, `app.log.3`)이 유지됩니다.

## 프로젝트 구조

```
FileTabOpenerM/
  FileTabOpenerMApp.swift       # 앱 진입점, 윈도우 위치 저장·복원
  ContentView.swift             # 메인 UI (클래식·모던 레이아웃)
  FinderTabController.swift     # AX API + AppleScript Finder 탭 제어
  ConfigManager.swift           # JSON 설정 관리
  TabGroup.swift                # 데이터 모델 (Codable, Python 버전 호환)
  Localization.swift            # 다국어 지원 (5개 언어, 53개 키)
  AppLogger.swift               # 파일 로거 (3세대 로테이션)
  Assets.xcassets/              # 앱 아이콘·색상 에셋
```

## 라이선스

[MIT License](LICENSE)
