# AI 티 목록 (WPF)

모든 그룹을 확인하고, 찾은 항목을 위치와 함께 적습니다. 각 줄은 "증상 → 고치는 방법" 형식입니다. `[자동]` 표시가 붙은 항목은 `scripts/audit-xaml.ps1`이 일부를 찾아 줍니다. 스크립트가 찾지 못하는 경우도 있으므로, 표시가 없는 항목과 함께 직접 보고 판단합니다.

## 표면과 색

- `[자동]` 배경, 카드, 버튼, 활성 항목에 쓴 보라-파랑, 보라-분홍 `LinearGradientBrush` → 무채색 표면 하나, 의미가 있는 곳에만 강조색
- gradient 텍스트(`TextBlock.Foreground`에 `LinearGradientBrush`) → 단색 primary 텍스트
- `[자동]` 색이 있는 glow(`DropShadowEffect`의 `ShadowDepth="0"`에 보라·파랑·분홍 `Color`, 큰 `BlurRadius`) → 제거, 깊이는 표면 단계와 hairline으로
- `[자동]` 내용 뒤의 `RadialGradientBrush` 색 번짐, `BlurEffect`를 건 색 `Ellipse` → 제거
- 네온 또는 대비가 강한 색 테두리 → 6~10% 불투명도의 hairline
- 텍스트에 쓴 같은 색상의 비슷한 색 다섯 가지 → 한 무채색 단계의 텍스트 역할 셋
- 모든 요소를 강조해서 아무것도 눈에 띄지 않음 → 화면당 한두 번만 쓰는 강조색 하나
- 흰 안쪽 하이라이트와 색 그림자를 가진 유리 카드(반투명 흰색 `Background` + `DropShadowEffect`) → hairline이 있는 평범한 올라온 표면
- `[자동]` 화면 XAML의 요소마다 직접 적은 `#RRGGBB`, code-behind의 `Color.FromRgb`, `new SolidColorBrush(...)`, `Brushes.Purple` → 토큰 사전의 `StaticResource`/`DynamicResource`
- 같은 역할에 서로 다른 값(카드 배경이 창마다 `#1E1E2E`, `#1F1F2F`, `#202030`) → 토큰 하나

## 글꼴

- `[자동]` `FontWeight="Bold"`, `ExtraBold`, `Black`, `Heavy`인 제목 → `Normal`~`Medium`, 위계는 크기로
- `[자동]` `NAVIGATION`, `PAID THIS MONTH` 같은 대문자 라벨, 글자 사이 공백으로 흉내 낸 자간(`N A V`) → 문장형 대소문자, 공백 제거
- 한 화면에 크기와 굵기가 너무 많음 → 척도에서 몇 개, 굵기 400과 500
- `$48,210` 옆에 `$124,860.40`, `07` 같은 섞인 숫자 형식 → 형식 하나, 고정폭 숫자
- `[자동]` 강조용 `FontStyle="Italic"` → 색이나 굵기로
- 요소마다 다른 `FontFamily` 지정 → `Window`나 공용 `Style`에서 한 번 지정
- 작은 텍스트가 흐리거나 색 번짐이 보임 → `TextOptions.TextFormattingMode="Display"`, 텍스트를 담은 요소의 `Effect` 제거, `UseLayoutRounding="True"`

## 아이콘

- `[자동]` 내비게이션 아이콘, 라벨 장식, 상태 표시로 쓴 이모지(🏠 📥 🚀 💰 ⚠️ 📈 🔥 ✨)가 `Content`, `Text`, `Header`, code-behind 문자열에 있음 → 아이콘 세트 하나 또는 없음
- 알약과 개수 안의 이모지(`18 👤`) → 숫자만
- 아이콘 크기와 색이 제각각(`FontSize` 14, 16, 20이 섞임, 아이콘마다 다른 `Foreground`) → 크기 하나, 텍스트 역할 색
- 아이콘이 열에서 벗어남(행마다 아이콘 상자 폭이 다름) → 모든 행에서 같은 아이콘 상자 폭
- AI 기능마다 붙은 반짝이 ✨ → 제거, 설명이 필요한 곳에만 평범한 아이콘
- 이모지 글꼴(`Segoe UI Emoji`)과 기호 글꼴(`Segoe MDL2 Assets`)과 이미지 아이콘이 섞임 → 세트 하나

## 여백

- `[자동]` 4의 배수가 아닌 `Margin`, `Padding`, `Width`, `Height`(`Margin="7,13,0,0"`, `Height="31"`) → 4px 척도의 값
- `[자동]` 디자이너에서 끌어다 놓은 절대 배치(`HorizontalAlignment="Left"`, `VerticalAlignment="Top"`, 큰 왼쪽·위 `Margin`) → `Grid` 행·열 또는 패널과 간격
- `Canvas`로 일반 레이아웃을 만듦 → `Grid`, `StackPanel`, `DockPanel`
- 한 목록의 행 높이나 간격이 다름 → 높이 하나, 간격 하나
- 그룹이 자기 항목보다 이웃에 더 가까움 → 그룹 안 간격은 작게, 그룹 사이 간격은 크게
- 나란한 카드의 `Padding`이 다름 → `Padding` 하나
- 섹션 위에 큰 빈 공간, 아래는 비좁음 → 균형 잡힌 리듬

## 문구

- 인사 제목(`안녕하세요, 지민님! 👋`, `Welcome back! 👋`) → 화면 이름이나 기간을 제목으로
- `[자동]` 느낌표와 `!!` → 평서문
- 비교 대상이 없는 변화량(`+12%!!`, `3개 줄었어요!!`) → `지난달보다 12% 증가`
- 장황한 placeholder(`무엇이든 검색해 보세요...`) → `검색`
- 과장된 단어(혁신적인, 강력한, 마법 같은, 완벽한, supercharge, seamless) → 실제로 하는 일
- 라벨과 버튼 끝의 마침표 → 없음
- 한 화면에 `~합니다`와 `~해요`가 섞임 → 어미 하나
- 가짜처럼 보이는 데이터(`123,456`, `[X]`, `홍길동` 반복) → 그럴듯한 숫자와 이름
- `MessageBox`에 이모지와 느낌표가 들어간 안내(`저장 완료! 🎉`) → 평서문, 이모지 없음

## 컴포넌트

- 개수, 등급, 단축키, 상태를 나타내는 빛나는 알약 → 조용한 mono 텍스트나 키캡
- 곳곳의 `PRO`, `New ✨`, `Beta 🚀` 배지 → 제거 또는 조용한 텍스트 배지 하나
- 검색창부터 버튼, 카드까지 모두 알약 모양(`CornerRadius`가 높이의 절반) → 크기별 반경, 중첩 반경 계산
- 무지개 막대, 빛나는 막대, 알약 모양 막대, 대문자 요일 라벨의 차트 → 계열 한두 개, muted grid와 mono 라벨, 강조색 하나
- 모든 통계 카드에 붙인 sparkline, 미니 막대 → 숫자, 라벨, 변화량
- 같은 내용의 같은 폭 카드가 나란히 → 주 차트 하나, 작은 통계, 다양한 폭
- gradient 타일 위의 반짝이 로고, gradient 워드마크 → 텍스트로 쓴 제품 이름과 단순한 평면 표식
- 번들거리는 구, gradient 공, 빛나는 점 로고 표식 → 단색 평면 글리프 또는 워드마크만

## WPF 기본값과 템플릿 흔적

- 기본 Aero 버튼(Windows 테마에 따라 파란 hover, 회색 gradient)과 직접 꾸민 컨트롤이 한 화면에 섞임 → 모든 버튼에 같은 `Style`과 `ControlTemplate`
- `Background`만 바꾼 기본 `Button`(hover에서 기본 파란색이 다시 나옴) → `ControlTemplate`을 직접 정의하고 상태 trigger 추가
- 기본 점선 focus 사각형(`FocusVisualStyle` 미지정) → 반경이 맞는 focus 테두리
- hover나 pressed 상태가 없는 직접 만든 버튼(`Border` + `MouseLeftButtonUp`) → `Button`과 템플릿, 상태 trigger
- 기본 회색 스크롤바가 어두운 테마 안에 있음 → 얇은 `ScrollBar` 템플릿
- 기본 `DataGrid` 격자선과 파란 선택 행 → 가로 hairline만, 팔레트 안의 선택과 hover
- `ComboBox`, `ContextMenu`, `ToolTip`의 기본 흰 팝업이 어두운 창 위에 뜸 → 팝업에도 같은 표면과 hairline
- `WindowStyle="None"`으로 틀을 지웠는데 창 이동·크기 조절·Aero Snap이 동작하지 않음 → `WindowChrome`
- 그림자를 위해 `AllowsTransparency="True"`와 큰 투명 여백을 둠 → 꼭 필요한지 확인하고 가능하면 `WindowChrome`(이유는 `xaml.md`의 "창 틀")
- `MahApps`나 `MaterialDesign` 기본 테마 그대로(보라 accent, 기본 카드 그림자) → 방향에 맞게 accent와 표면 토큰 재정의

## 시각 요소

- 번들거리는 3D 덩어리, 구, 성운 이미지 배경 → 제품 자체 또는 하는 일을 보여 주는 구체적인 비유 하나
- AI 기능에 붙인 로봇, 빛나는 뇌, 회로 선, 홀로그램 → 제거하거나 AI가 실제로 만든 결과를 보여 줌
- 이미지 안에 구워 넣은 텍스트와 가짜 버튼 → XAML의 진짜 텍스트, 텍스트 없는 이미지
- 고DPI에서 흐린 비트맵 아이콘 → 벡터(`Path`, 아이콘 글꼴) 또는 2배 해상도

## 움직임

- `[자동]` 살아 있는 상태가 아닌 것에 걸린 `RepeatBehavior="Forever"` 깜빡임, 숨 쉬는 glow → 정지
- hover에서 카드와 버튼을 키우는 `ScaleTransform` → hover는 색이나 표면 변화, press는 아주 작은 축소
- `[자동]` `BackEase`, `ElasticEase`, `BounceEase` → ease-out 곡선 하나
- 창이 열릴 때 모든 것이 다른 방향에서 날아옴 → 짧은 fade와 rise 하나, 작은 stagger
- `[자동]` `Width`, `Height`, `Margin`, `Canvas.Left`, `Canvas.Top` animate → `RenderTransform`과 `Opacity`
- `DispatcherTimer`로 매 tick 위치나 크기를 바꾸는 애니메이션 → `Storyboard`와 `RenderTransform`

## 오른쪽에서 왼쪽으로 쓰는 언어

- 아랍어나 히브리어 화면인데 `FlowDirection`이 기본값 → 최상위 요소에 `FlowDirection="RightToLeft"`
- 방향 아이콘(다음, 뒤로)이 그대로 → 방향 아이콘만 좌우 반전, 미디어 컨트롤과 사물은 유지
- 한 화면에 서구 숫자와 아랍-인도 숫자가 섞임 → 숫자 체계 하나

## 템플릿 모양

AI 티는 아니지만, 아무도 결정하지 않았을 때 정리된 화면이 돌아가는 모양입니다. pass가 끝난 뒤 확인합니다.

- 순수 회색 `#161616` 창, `Segoe UI`, 흰 텍스트, 버튼 하나에 남은 옛 브랜드색. 그런데 제품의 세계는 따뜻하거나 밝음 → 세계 쪽으로 색조를 넣은 단계와 거기서 온 강조색
- 이름만 바꾸면 다른 제품에도 맞는 제목 → 이 제품의 명사로 하는 일을 말함
- Windows 11 설정 앱을 그대로 흉내 낸 화면 → 방향이 레이아웃, 글꼴, 팔레트를 정함
- 모든 제품이 같은 레이아웃, 글꼴, 팔레트를 받음 → 방향이 고르게 함

---

unslop(Damir Sokolovsky, [@heydamir](https://x.com/heydamir), CC BY 4.0)을 WPF용으로 변형한 내용입니다. 복사하거나 변형할 때 이 출처를 유지합니다.
