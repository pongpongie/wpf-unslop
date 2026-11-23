# 화면 확인과 캡처

사용자는 Claude가 앱을 확인하는 동안에도 같은 PC에서 다른 작업을 합니다. 그래서 화면을 확인할 때 사용자의 포커스, 마우스, 키보드를 건드리지 않는 방법만 씁니다.

## 규칙

| 하지 않는 것 | 대신 쓰는 것 |
| --- | --- |
| `SetForegroundWindow`, `Activate`, 창을 맨 앞으로 끌어오기 | 창을 그대로 두고 `capture-window.ps1`로 캡처 |
| `SendKeys`, `SendInput`, 마우스 이동·클릭·휠 흉내 | UI Automation 패턴(`InvokePattern`, `ScrollPattern`, `SelectionItemPattern`) |
| 전체 화면 캡처(`CopyFromScreen`, 화면 스크린샷 도구) | `PrintWindow` + `PW_RENDERFULLCONTENT` 창 캡처 |
| 확인할 창 최소화 | 창을 그대로 둠. WPF는 최소화된 창을 그리지 않음 |

- **앱을 새로 실행하거나 앱 안에서 새 창(대화상자, 설정 창)을 여는 것도 포커스를 가져갑니다.** 그래서 실행하기 전에 무엇을 몇 번 띄울지 사용자에게 말하고 허락을 받습니다. 가능하면 수정 전 캡처와 수정 후 캡처를 각각 한 번의 실행으로 끝냅니다.
- 앱이 이미 실행 중이면 허락 없이 캡처해도 됩니다. 캡처는 포커스를 바꾸지 않습니다.
- hover, pressed 같은 상태는 실제 마우스로 만들지 않습니다. 템플릿의 trigger를 코드로 읽어서 확인하고, 필요하면 아래 "오프스크린 렌더링"으로 상태별 모습을 만들어 봅니다.

## 실행 중인 앱의 창 캡처

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill 폴더>/scripts/capture-window.ps1" -ProcessName <프로세스 이름> -OutDir <저장 폴더>
```

| 옵션 | 뜻 |
| --- | --- |
| `-ProcessName` | 확장자 없는 프로세스 이름. 예: `Catcretary` |
| `-ProcessId` | 프로세스 ID. 이름이 겹칠 때 씀 |
| `-Title` | 창 제목에 포함된 문자열로 거름. 생략하면 보이는 창을 모두 캡처 |
| `-OutDir` | PNG 저장 폴더. 없으면 만듦 |

출력 줄의 의미:

| 출력 | 뜻 |
| --- | --- |
| `SAVED: <경로> (<폭>x<높이>)` | 저장 완료. 이미지를 읽어서 확인 |
| `SKIP_MINIMIZED` | 최소화된 창이라 건너뜀. 사용자에게 창을 복원해 달라고 요청 |
| `NOT_RUNNING` (exit 2) | 프로세스 없음. 실행하려면 허락 필요 |
| `NO_WINDOW` (exit 3) | 조건에 맞는 보이는 창 없음 |

- 저장 폴더는 프로젝트 밖(임시 폴더나 scratchpad)으로 잡거나, 프로젝트 안이면 `unslop-captures/before`, `unslop-captures/after`처럼 나누고 `.gitignore` 여부를 사용자에게 확인합니다.
- 화면 배율이 100%가 아니어도 실제 픽셀 크기로 저장됩니다. 비교할 때는 같은 모니터, 같은 배율에서 찍은 것끼리 비교합니다.
- `AllowsTransparency="True"` 창은 투명한 부분이 검은색으로 저장됩니다. 실제 화면에서는 바탕화면이 비쳐 보이므로, 가장자리 색은 그 점을 감안해서 판단합니다.
- 다른 창에 가려져 있어도 캡처됩니다.

## 앱 빌드와 실행

1. 빌드 명령은 프로젝트의 README, 빌드 스크립트, `.csproj`/`.sln`에서 찾습니다. 찾지 못하면 사용자에게 묻습니다.
2. 실행 중인 앱이 있으면 빌드 출력 파일이 잠겨서 빌드가 실패할 수 있습니다. 앱을 종료하는 것도 사용자 작업에 영향을 주므로 먼저 묻습니다.
3. 실행할 때는 몇 번 띄울지 말하고 허락을 받습니다. 예: "수정 후 확인을 위해 앱을 한 번 실행합니다. 첫 창이 포커스를 가져갑니다."
4. 실행 후 창이 뜰 때까지 기다리는 동안 `Start-Sleep`을 반복하지 않고, 짧은 간격으로 `capture-window.ps1`의 exit code를 확인합니다.
5. 서버나 파일에서 데이터를 비동기로 불러오는 앱은 창이 뜬 직후의 캡처가 비어 있을 수 있습니다. 캡처한 이미지를 열어 내용이 채워졌는지 보고, 비어 있으면 몇 초 뒤 다시 캡처합니다. 이 재캡처는 렌더링 확인 횟수에 세지 않습니다.
6. 실행 경로를 다룰 때는 절대 경로를 씁니다. PowerShell의 `Set-Location`은 `[IO.File]` 같은 .NET API의 현재 폴더를 바꾸지 않으므로, 상대 경로로 파일을 쓰면 엉뚱한 폴더의 파일이 바뀔 수 있습니다.
7. 시험이 끝나면 사용자가 원래 쓰던 앱 상태로 되돌립니다. 확인하려고 종료한 앱이 있으면 원래 실행 파일로 다시 실행합니다.

## 오프스크린 렌더링

앱을 실행하지 않고 스타일이나 작은 화면 조각을 확인할 때 씁니다. 창을 띄우지 않으므로 포커스와 무관합니다. 사전 파일이 문법적으로 맞는지 검증하는 데도 씁니다.

```powershell
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$rd = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText('Themes\Theme.xaml'))
$panel = New-Object Windows.Controls.StackPanel
$panel.Resources = $rd
$panel.Background = $rd['Brush.Window']
$b = New-Object Windows.Controls.Button; $b.Content = '저장'; $b.Style = $rd['Button.Primary']; $b.Margin = '8'
[void]$panel.Children.Add($b)
$panel.Measure([Windows.Size]::new(240, 120)); $panel.Arrange([Windows.Rect]::new(0, 0, 240, 120)); $panel.UpdateLayout()
$bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 240, 120, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
$bmp.Render($panel)
$enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
$fs = [IO.File]::Create('preview.png'); $enc.Save($fs); $fs.Close()
```

- Windows PowerShell 5.1은 .NET Framework에서 돌기 때문에 .NET 6 이상으로 빌드한 프로젝트 어셈블리를 불러올 수 없습니다. 그런 프로젝트의 창은 scratchpad에 작은 렌더링 프로그램을 만들어 그립니다. `net8.0-windows` WPF 콘솔 프로젝트에서 대상 어셈블리를 `Reference`로 참조하고, `[STAThread] Main`에서 아래 순서로 처리합니다.
  1. `new App()`과 `InitializeComponent()`로 앱 리소스를 불러옵니다. `Run()`은 호출하지 않습니다.
  2. 창 객체를 만들고 `Show()` 없이 `Content`를 떼어 냅니다.
  3. 떼어 낸 내용을 배경 `Border`에 넣고 `Measure`/`Arrange`한 뒤 `RenderTargetBitmap`으로 그립니다.

  창을 띄우지 않으므로 포커스와 무관합니다. 생성자가 다른 창을 인자로 받는 경우처럼 만들기 어려운 창은 앱을 실행해서 확인합니다.
- 이 방법은 `pack://` URI, 프로젝트의 사용자 정의 클래스(`xmlns:local`), converter를 해석하지 못합니다. 그런 화면은 앱을 실행해서 확인합니다.
- `x:Class`가 있는 `Window` XAML은 그대로 parse되지 않습니다. 확인할 부분만 떼어서 렌더링합니다.

---

wpf-unslop(unslop by Damir Sokolovsky, CC BY 4.0의 WPF 변형)의 일부입니다.
