# Paperlet

메모 보드와 바탕화면 메모 창을 제공하는 macOS 메모 앱입니다. 메모는 이 기기에 자동 저장됩니다.

## 주요 기능

- 색상별 메모 작성, 검색, 정렬 및 보드 상단 고정
- Markdown 형식의 제목, 목록, 할 일과 미리보기
- 메모를 바탕화면 창으로 열고 편집 잠금 또는 항상 위에 표시 설정
- 고정 메모, 할 일 메모, 바탕화면에 열린 메모와 색상별 필터

메모는 기기의 앱 설정 저장소에 보관됩니다. 삭제한 메모는 앱에서 복구할 수 없습니다.

## 요구 사항 및 실행

- macOS 27 이상으로 설정된 프로젝트와 해당 SDK를 지원하는 Xcode

```sh
git clone https://github.com/INT31302/Paperlet.git
cd Paperlet
open 'Untitled Project.xcodeproj'
```

Xcode에서 공유 스킴 **MyApp**과 My Mac을 선택해 실행하세요. 보드의 **새 메모** 버튼으로 메모를 만들고, 메모 메뉴에서 **바탕화면에 띄우기**를 선택할 수 있습니다.

## 프로젝트 구성

- `MyApp/`: 메모 보드, 편집기 및 바탕화면 메모 창
- `Untitled Project.xcodeproj/`: Xcode 프로젝트와 공유 스킴
