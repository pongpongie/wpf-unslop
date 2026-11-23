# wpf-unslop

AI가 만든 티가 나는 WPF 화면을 제품의 성격이 드러나는 데스크톱 인터페이스로 다듬는 Claude Code skill입니다. 웹 UI용 skill인 [unslop](https://github.com/heydamir/unslop)의 판단 기준과 절차를 그대로 가져오고, 수정 방식과 확인 방식을 WPF XAML에 맞게 바꿨습니다. 원작자와 관계없는 비공식 변형이며, 원작자가 승인하거나 관리하지 않습니다.

| 항목 | 내용 |
| --- | --- |
| 대상 | WPF `Window`, `UserControl`, `ResourceDictionary` (.NET Framework 4.x, .NET 6 이상) |
| 실행 환경 | Claude Code, Windows, Windows PowerShell 5.1 |
| 원본 | [heydamir/unslop](https://github.com/heydamir/unslop) (CC BY 4.0) |
| 라이선스 | CC BY 4.0 ([LICENSE](LICENSE)), `scripts/`만 MIT ([scripts/LICENSE](skills/wpf-unslop/scripts/LICENSE)). 자세한 내용은 [NOTICE.md](NOTICE.md) |

## 저장소 구성

```
wpf-unslop/
├── README.md
├── LICENSE                             # CC BY 4.0 전문
├── NOTICE.md                           # 원저작자 표기, 파일별 라이선스, 변경 사항
└── skills/wpf-unslop/                  # 설치할 skill 폴더
    ├── SKILL.md                        # 절차와 9개 pass 규칙 (Claude가 읽는 본체)
    ├── references/
    │   ├── signs.md                    # AI 티 목록, XAML 사례 기준
    │   ├── tokens.md                   # 여백, 색 ramp, 글꼴, 반경, 움직임 값
    │   ├── xaml.md                     # 토큰을 XAML로 구현하는 방법
    │   └── capture.md                  # 포커스를 건드리지 않는 화면 확인 방법
    ├── assets/
    │   └── Theme.Graphite.Dark.xaml    # 시작용 테마 사전 (색, 글꼴, 버튼, 입력 상자, 스크롤바)
    └── scripts/
        ├── LICENSE                     # MIT 전문 (scripts 폴더에만 적용)
        ├── audit-xaml.ps1              # XAML, code-behind, .resx 정적 점검
        └── capture-window.ps1          # 실행 중인 창을 포커스 변화 없이 PNG로 캡처
```

## 설치

skill 폴더를 Claude Code가 읽는 위치에 복사합니다. 아래 명령은 이 저장소 루트에서 실행합니다. 설치한 뒤에는 Claude Code 세션을 새로 열어야 적용됩니다.

모든 프로젝트에서 쓰려면 사용자 skill 폴더에 복사합니다.

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse -Force .\skills\wpf-unslop "$env:USERPROFILE\.claude\skills\"
```

한 프로젝트에서만 쓰려면 그 프로젝트의 `.claude\skills\`에 복사합니다.

```powershell
New-Item -ItemType Directory -Force "<프로젝트 루트>\.claude\skills" | Out-Null
Copy-Item -Recurse -Force .\skills\wpf-unslop "<프로젝트 루트>\.claude\skills\"
```

이 저장소에서 파일을 고친 뒤에는 같은 명령으로 다시 복사해야 설치된 skill에 반영됩니다.

## 사용법

WPF 프로젝트 폴더에서 Claude Code를 열고 `/wpf-unslop` 뒤에 대상을 적습니다. 명령 없이 "이 창 AI 티 안 나게 다듬어줘"처럼 요청해도 skill이 선택됩니다.

```
/wpf-unslop BoardWindow
/wpf-unslop 위젯 창 정리해줘
/wpf-unslop 전체 테마 정리
```

### 진행 순서

| 순서 | Claude가 하는 일 | 사용자가 하는 일 |
| --- | --- | --- |
| 1. 화면 파악 | XAML, code-behind, 리소스 사전을 읽고 `audit-xaml.ps1` 실행 | 없음 |
| 2. 캡처 | 앱이 실행 중이면 `capture-window.ps1`로 캡처. 새로 실행해야 하면 횟수를 말하고 허락을 받음 | 실행 허락 여부 |
| 3. Audit | AI 티 목록을 `파일:줄`과 함께 제시 | 확인 |
| 4. 방향 | 제품, 캐릭터, 세계, 순간, 시그니처 5줄을 제안하고 멈춤. 글꼴 추가처럼 `.csproj`를 바꾸는 일도 이때 물음 | 승인 또는 수정 |
| 5. 9개 pass | spacing → color → icons → copy → type → layout → details → visuals → motion 순서로 수정 | 없음 |
| 6. 확인 | 빌드, `audit-xaml.ps1` 재실행, 허락받은 경우 재캡처, 체크리스트 | 결과 검토 |
| 7. 보고 | pass별 변경 내용, 새 리소스 키, 확인하지 못한 것 | commit 여부 결정 |

화면에 AI 티가 거의 없으면 전체를 바꾸지 않고 작은 수정 2~3개만 제안합니다.

## 스크립트 단독 실행

두 스크립트는 skill 없이 직접 실행할 수 있습니다. 파일은 UTF-8 BOM으로 저장되어 있어서 Windows PowerShell 5.1에서 한글이 깨지지 않습니다.

```powershell
# XAML 정적 점검 (파일을 수정하지 않음)
powershell -NoProfile -ExecutionPolicy Bypass -File .\skills\wpf-unslop\scripts\audit-xaml.ps1 -Path <프로젝트 폴더>

# 실행 중인 앱의 창 캡처 (포커스 변화 없음)
powershell -NoProfile -ExecutionPolicy Bypass -File .\skills\wpf-unslop\scripts\capture-window.ps1 -ProcessName <프로세스 이름> -OutDir .\captures
```

### `audit-xaml.ps1` 항목

| 항목 | 찾는 것 |
| --- | --- |
| `HUE_GRADIENT` | 색이 있는 stop을 가진 `LinearGradientBrush`/`RadialGradientBrush` |
| `GLOW` | `ShadowDepth="0"`이거나 색이 있는 `DropShadowEffect` |
| `RADIAL_WASH`, `BLUR` | 무채색 `RadialGradientBrush`, `BlurEffect` |
| `EFFECT_ON_TEXT` | 안에 텍스트가 있는 요소에 걸린 `Effect` |
| `EMOJI` | XAML 문구, code-behind, `.resx`의 이모지와 장식 기호 |
| `HARDCODED_COLOR`, `HARDCODED_COLOR_CS` | 토큰이 아닌 직접 적은 색 (XAML, C#) |
| `HEAVY_WEIGHT`, `ITALIC` | `Bold` 이상 굵기(XAML, C# `FontWeights.*`), 기울임꼴 |
| `SMALL_TEXT` | 12 미만이거나 소수인 `FontSize` (XAML, C#) |
| `OFF_GRID_CS` | C#에서 숫자로 적은 `new Thickness(...)` 중 4px grid를 벗어난 값 |
| `UPPERCASE_LABEL`, `FAKE_TRACKING` | 대문자 라벨, 공백으로 흉내 낸 자간 |
| `EXCLAMATION` | 문구의 느낌표 |
| `OFF_GRID` | 4px grid를 벗어난 `Margin`, `Padding`, `Width`, `Height` (1과 20 이하 짝수는 허용) |
| `ABSOLUTE_LAYOUT`, `CANVAS_POSITION` | 디자이너 드래그 배치, `Canvas` 좌표 배치 |
| `INFINITE_ANIMATION`, `BOUNCY_EASE`, `LAYOUT_ANIMATION` | `RepeatBehavior="Forever"`, 튀는 easing, layout 속성 animate |
| `SHADOW`, `NEUTRAL_GRADIENT` | 일반 그림자, 무채색 gradient (확인용) |
| `ILLUSTRATION` | 도형 3개 이상이 든 `Canvas` (일러스트로 보고 색·좌표 점검에서 제외) |
| `ALLOWS_TRANSPARENCY`, `NO_LAYOUT_ROUNDING` | 투명 `Window`, `UseLayoutRounding`이 없는 `Window` |

결과는 audit의 출발점입니다. 맥락에 따라 문제가 아닌 항목도 있고, 스크립트가 찾지 못하는 항목(문구의 어조, 정렬, 컨트롤 상태 누락 등)은 Claude가 `signs.md`를 기준으로 직접 확인합니다.

## 원본 unslop과의 차이

| 항목 | unslop | wpf-unslop |
| --- | --- | --- |
| 대상 | React, Vue, Svelte, Tailwind, HTML/CSS, 라이브 사이트 | WPF XAML |
| 수정 방식 | CSS 클래스, Tailwind 유틸리티 | `ResourceDictionary` 토큰, `Style`, `ControlTemplate` |
| 결과 확인 | Playwright 브라우저 스크린샷 | `PrintWindow` 창 캡처, 오프스크린 `RenderTargetBitmap` |
| 정적 점검 | 없음 | `audit-xaml.ps1` |
| WPF 고유 점검 | 없음 | 컨트롤 상태 템플릿, 텍스트 렌더링, `Effect`와 ClearType, 창 틀, 디자이너 드래그 배치 |
| 한국어 문구 규칙 | 없음 | 어미 통일, 한글 글꼴 후보, 한국어 줄 간격 |
| 제외한 기능 | | landing hero, 이미지 생성, story video, 라이브 사이트 snapshot |

## 확인한 사항

| 항목 | 결과 |
| --- | --- |
| `Theme.Graphite.Dark.xaml` | `XamlReader.Parse` 통과, 키 69개, 버튼 3종과 입력 상자 오프스크린 렌더링 확인 |
| `audit-xaml.ps1` | Catcretary `src`(파일 29개)에 실행. code-behind 점검을 추가한 뒤 `Board` 폴더 기준 수정 전 34건, 수정 후 21건 |
| `capture-window.ps1` | 실행 중인 WPF 앱 2개(SourceTree, Catcretary 창 3개) 캡처 성공 |
| skill 전체 절차 | Catcretary 사본의 상태별 보드 창에 다듬기 모드로 적용. 빌드 성공(경고 0, 오류 0), 수정 전후 캡처 비교 |

### 시험 적용에서 보완한 것

| 발견한 문제 | 반영 |
| --- | --- |
| code-behind에서 만든 카드의 여백과 작은 글자를 점검 스크립트가 찾지 못함 | `OFF_GRID_CS`, `SMALL_TEXT`, C# 굵기 점검 추가 |
| code-behind의 `Typography` 호출이 namespace 문제로 빌드 실패 | `xaml.md`에 전체 이름 사용 안내 추가 |
| 데이터를 비동기로 불러오는 앱의 첫 캡처가 비어 있음 | `capture.md`에 재캡처 안내 추가 |
| `Set-Location` 후 상대 경로로 쓴 파일이 다른 폴더를 가리킴 | `capture.md`에 절대 경로 사용 안내 추가 |
| 카드 한 변만 색을 칠하는 방법, 누를 수 있는 `Border`의 hover | `xaml.md`에 "code-behind에서 만드는 UI" 절 추가 |
| 입력 상자 템플릿에서 `Padding`이 두 번 적용됨 (`Theme.Graphite.Dark.xaml`의 `Input.Text` 포함) | 템플릿 수정, `xaml.md`에 주의 사항 추가 |
| `BasedOn`으로 상속한 `Primary` 버튼의 hover가 `Flat` 색으로 덮여 글자가 안 보임 | `xaml.md`에 `Style.Triggers` 방식 안내 추가 |
| .NET 8 프로젝트는 Windows PowerShell 5.1에서 오프스크린 렌더링을 할 수 없음 | `capture.md`에 렌더링용 작은 프로젝트를 만드는 방법 추가 |
| 전역 `TextBlock` 스타일 때문에 버튼 `Content`의 아이콘 글꼴이 무시됨 | `xaml.md` 아이콘 절에 주의 사항 추가 |

## 남은 확인 사항

- AI 티가 심한 화면(새 방향을 세우는 전체 9개 pass)에는 아직 적용해 보지 않았습니다. Catcretary의 보드, 캘린더, 말풍선, 설정 창, 보드 편집기는 다듬기 모드로만 적용했습니다.
- `Theme.Graphite.Dark.xaml` 버튼의 hover 색 animation은 실제 마우스 입력으로 확인하지 않았습니다. parse와 기본 상태 렌더링만 확인했습니다.
- `capture-window.ps1`은 화면 배율 100% 환경에서만 시험했습니다.
- 밝은 테마용 사전(`Theme.Graphite.Light.xaml`)은 아직 없습니다. 값은 `tokens.md`의 밝은 테마 표에 있습니다.
- Claude Code plugin 형식(`.claude-plugin/`)으로 배포하는 구성은 만들지 않았습니다. 지금은 폴더 복사로만 설치합니다.
