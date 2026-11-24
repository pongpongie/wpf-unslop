# XAML 구현 방법

각 pass의 결정을 WPF XAML로 옮기는 방법입니다. .NET Framework 4.x와 .NET 6 이상에서 모두 동작하는 방법만 적습니다. 다르게 동작하는 곳은 따로 표시합니다.

## 토큰 사전 구성

- 토큰은 `Themes/` 아래 사전 하나(작으면) 또는 `Colors.xaml`, `Typography.xaml`, `Controls.xaml`(크면)로 나눕니다. 프로젝트에 이미 `Themes/` 구조가 있으면 그것을 따릅니다.
- `App.xaml`의 `MergedDictionaries`에 넣습니다. 색 사전이 먼저, 그것을 참조하는 스타일 사전이 나중입니다. `StaticResource`는 앞에 정의된 키만 찾기 때문입니다.
- 출발점으로 `assets/Theme.Graphite.Dark.xaml`을 복사해 씁니다. 키 이름 규칙은 `Color.*`(`Color`), `Brush.*`(`SolidColorBrush`), `Font.*`, `FontSize.*`, `Space.*`, `Radius.*`, `Motion.*`, `Text.*`(`TextBlock` 스타일), `Button.*`입니다.
- 테마를 실행 중에 바꾸는 앱이면 화면에서 `DynamicResource`로 참조합니다. 테마가 하나뿐이면 `StaticResource`가 더 빠르고 오타를 빌드 단계에서 잡아 줍니다.
- `Style`의 `BasedOn`으로 공통값을 한곳에 둡니다. 예: `Text.Secondary`는 `Text.Body`를 기반으로 크기와 색만 바꿉니다.
- 키 없는 암시적 스타일(`<Style TargetType="Button">`)은 사전 범위 안의 모든 버튼에 적용됩니다. 기존 화면에 예상하지 못한 영향을 주므로, 기존 프로젝트에서는 키가 있는 스타일로 시작하고 화면마다 명시적으로 적용합니다.

## 색과 brush

- 화면 XAML에서는 `Background="{StaticResource Brush.Card}"`처럼 brush 키를 씁니다. `Color` 키는 brush를 만들거나 `ColorAnimation`의 `To`에 쓸 때만 참조합니다.
- 반투명 색은 `#AARRGGBB`입니다. hairline 8%는 `#14EDEDED`입니다. `Opacity` 속성으로 투명도를 주면 자식 요소까지 함께 투명해지므로, 테두리만 흐리게 하려면 색의 알파를 씁니다.
- code-behind에서 색을 만드는 코드(`new SolidColorBrush(Color.FromRgb(...))`, `Brushes.Purple`)는 `(Brush)FindResource("Brush.Accent")` 또는 `Application.Current.Resources["Brush.Accent"]`로 바꿉니다.
- 무채색 안의 톤 변화만 gradient로 허용합니다.
  ```xml
  <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#2B2B2B" Offset="0"/>
      <GradientStop Color="#1F1F1F" Offset="1"/>
  </LinearGradientBrush>
  ```

## 깊이와 그림자

- 어두운 테마는 그림자 대신 표면 단계를 씁니다. 창 배경 `Brush.Window` 위에 카드 `Brush.Card`, 그 안의 활성 행 `Brush.Raised`입니다. 경계는 `BorderBrush="{StaticResource Brush.Hairline}" BorderThickness="1"`입니다.
- WPF에는 inset shadow가 없습니다. 위쪽 1px 하이라이트는 안쪽에 겹친 `Border`로 만듭니다.
  ```xml
  <Border Background="{StaticResource Brush.Raised}" CornerRadius="6">
      <Grid>
          <Border BorderBrush="{StaticResource Brush.TopHighlight}" BorderThickness="0,1,0,0" CornerRadius="6"/>
          <ContentPresenter Margin="12,0"/>
      </Grid>
  </Border>
  ```
- **텍스트를 담은 요소에 `Effect`(`DropShadowEffect`, `BlurEffect`)를 걸지 않습니다.** `Effect`가 걸린 요소는 비트맵으로 그려진 뒤 효과가 적용되므로, 그 안의 텍스트가 ClearType 대신 grayscale anti-aliasing으로 바뀌어 흐려지고, 매 프레임 다시 그리는 비용도 늘어납니다.
- 밝은 테마에서 그림자가 필요하면 내용과 형제인 별도 `Border`에만 겁니다.
  ```xml
  <Grid>
      <Border Background="White" CornerRadius="12">
          <Border.Effect>
              <DropShadowEffect BlurRadius="24" ShadowDepth="8" Direction="270" Opacity="0.08" Color="Black"/>
          </Border.Effect>
      </Border>
      <Border Background="White" CornerRadius="12" Padding="20">
          <!-- 내용 -->
      </Border>
  </Grid>
  ```
- 색이 있는 `DropShadowEffect`(`ShadowDepth="0"`에 보라색 `Color`)는 glow입니다. 지웁니다.

## 반경과 자르기

- `ClipToBounds="True"`는 사각형으로 자르므로 둥근 모서리 밖으로 자식이 삐져나옵니다. 이미지나 꽉 찬 내용을 둥글게 자르려면 `Border.Clip`에 `RectangleGeometry`의 `RadiusX`/`RadiusY`를 주거나 `OpacityMask`에 `VisualBrush`를 씁니다. 크기가 바뀌는 요소는 code-behind의 `SizeChanged`에서 `Clip`을 갱신해야 하므로, 가능하면 안쪽 요소에도 같은 반경을 주는 방법(중첩 반경 계산)으로 해결합니다.
- 중첩 반경: 바깥 `CornerRadius="12"`, `Padding="8"`이면 안쪽은 `CornerRadius="4"`입니다.

## 텍스트 렌더링

| 상황 | 설정 |
| --- | --- |
| 14 이하 본문, 라벨, 버튼 | `TextOptions.TextFormattingMode="Display"` (.NET 4.x에서 작은 글자가 선명해짐) |
| 20 이상 제목, 숫자 | `TextOptions.TextFormattingMode="Ideal"` (기본값, 큰 글자 모양이 정확함) |
| 창 전체 | `UseLayoutRounding="True"` (반 픽셀 위치로 인한 번짐 방지). `Window`에 한 번 지정 |
| 1px 선과 테두리 | `SnapsToDevicePixels="True"` |
| 투명 배경 창(`AllowsTransparency`) | ClearType이 꺼지고 grayscale이 됨. `TextOptions.TextRenderingMode="Grayscale"`로 명시해 두면 일관됨 |

- `LineHeight`를 쓸 때는 `LineStackingStrategy="BlockLineHeight"`를 함께 지정합니다. 기본값(`MaxHeight`)은 큰 글자가 섞이면 줄 간격을 늘려 버립니다.
- 고정폭 숫자: `Typography.NumeralAlignment="Tabular"`. code-behind에서는 `System.Windows.Documents.Typography.SetNumeralAlignment(textBlock, FontNumeralAlignment.Tabular)`입니다. `Typography` 클래스가 `System.Windows.Documents` namespace에 있어서, 그 `using`이 없는 파일에서는 전체 이름을 써야 빌드됩니다. 글꼴이 OpenType `tnum`을 지원해야 동작합니다. Segoe UI는 숫자가 기본적으로 고정폭에 가깝고, Pretendard, Inter, IBM Plex는 `tnum`을 지원합니다. 맑은 고딕은 지원 여부를 렌더링으로 확인합니다.
- 숫자 형식은 바인딩의 `StringFormat`으로 통일합니다. 예: `Text="{Binding Total, StringFormat={}{0:N0}원}"`. 문화권이 필요하면 `ConverterCulture=ko-KR`을 붙입니다.
- 자간 속성이 없습니다. 대문자 사이에 공백을 넣은 흉내는 지웁니다.

## 글꼴 포함

1. 글꼴 파일(`.ttf`, `.otf`)을 `Fonts/` 폴더에 넣습니다. 한글 글꼴은 용량이 크므로 필요한 굵기(400, 500, 600)만 넣습니다.
2. `.csproj`에서 빌드 동작을 `Resource`로 지정합니다.
   ```xml
   <ItemGroup>
     <Resource Include="Fonts\Pretendard-Regular.otf" />
     <Resource Include="Fonts\Pretendard-Medium.otf" />
   </ItemGroup>
   ```
   SDK 스타일이 아닌 .NET Framework 프로젝트는 각 파일을 이렇게 나열해야 합니다. SDK 스타일 프로젝트는 와일드카드(`Fonts\*.otf`)를 쓸 수 있습니다.
3. `#` 뒤에는 파일 이름이 아니라 **글꼴 패밀리 이름**을 씁니다.
   ```xml
   <FontFamily x:Key="Font.Ui">pack://application:,,,/MyApp;component/Fonts/#Pretendard</FontFamily>
   ```
   `MyApp` 자리에 앱의 어셈블리 이름(`.csproj`의 `AssemblyName`, 없으면 프로젝트 이름)을 씁니다. `pack://application:,,,/Fonts/#Pretendard`처럼 어셈블리 이름을 빼도 앱 실행에는 문제가 없지만, `render-window.ps1`처럼 다른 프로그램이 앱을 불러와 그릴 때는 그 프로그램의 어셈블리를 찾게 되어 시스템 글꼴로 그려집니다.
   Pretendard 정적 OTF는 굵기마다 파일이 따로 있지만 패밀리 이름은 모두 `Pretendard`이고, WPF가 굵기별로 알맞은 파일을 고릅니다. Pretendard는 한글과 라틴을 모두 담고 있으므로 대체 글꼴을 이어 쓸 필요가 없습니다.
   창의 `FontFamily`에 이 키를 지정하면 하위 요소가 상속합니다. 코드에서 `FormattedText`로 직접 그리는 차트는 상속받지 않으므로 `FindResource("Font.Ui")`로 가져와 씁니다.
4. 글꼴 라이선스(SIL OFL 등)를 확인하고 라이선스 파일을 함께 둡니다.

`.csproj`를 바꾸는 작업이므로 사용자 허락을 받은 뒤 진행합니다.

## 아이콘

### 아이콘 글꼴 (기본)

```xml
<TextBlock Style="{StaticResource Text.Icon}" Text="&#xE80F;"/>  <!-- Home -->
```

- `Font.Icon`은 `Segoe Fluent Icons, Segoe MDL2 Assets`입니다. Windows 11에는 Fluent Icons가, Windows 10에는 MDL2 Assets가 있으며 대부분의 코드 포인트가 같습니다.
- 코드 포인트는 Microsoft 문서 "Segoe Fluent Icons font"의 표에서 찾습니다. 자주 쓰는 값: Home `E80F`, Settings `E713`, Search `E721`, Add `E710`, Delete `E74D`, Edit `E70F`, Calendar `E787`, Clock `E823`, Pin `E718`, More `E712`, ChevronRight `E76C`, Cancel `E711`.
- 아이콘 상자 폭을 고정해서(`Width="16"`, `TextAlignment="Center"`) 모든 행에서 라벨이 정렬되게 합니다.
- 앱에 키 없는 전역 `TextBlock` 스타일이 있고 그 스타일이 `FontFamily`를 지정하면, `Button`에 `FontFamily`를 주고 `Content`에 아이콘 문자열을 넣어도 아이콘 글꼴이 적용되지 않습니다. 버튼 안에 자동으로 만들어지는 `TextBlock`이 전역 스타일의 글꼴을 쓰기 때문이고, 결과는 글꼴에 없는 문자를 나타내는 빈 상자입니다. 아이콘은 `TextBlock`에 `FontFamily`를 직접 지정해서 넣고, trigger로 바꿀 때도 그 `TextBlock`의 `Text`를 바꿉니다.

### lucide를 Path로 (선 아이콘이 방향에 맞을 때)

lucide는 24×24 좌표의 선 아이콘입니다. SVG의 `path`, `line`, `circle`, `rect`를 하나의 path data로 합쳐 `Geometry` 리소스로 둡니다.

- `line x1 y1 x2 y2` → `M x1,y1 L x2,y2`
- `circle cx cy r` → `M cx-r,cy A r,r 0 1 0 cx+r,cy A r,r 0 1 0 cx-r,cy`
- `rect x y w h rx` → 네 변과 모서리 호를 `M`, `H`, `V`, `A`로 풀어 씁니다.

```xml
<Geometry x:Key="Icon.Search">M11,3 A8,8 0 1 0 11,19 A8,8 0 1 0 11,3 M21,21 L16.65,16.65</Geometry>

<Path Data="{StaticResource Icon.Search}" Width="16" Height="16" Stretch="Uniform"
      Stroke="{StaticResource Brush.Text.Secondary}" StrokeThickness="1.5"
      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
```

- `Stretch="Uniform"`으로 16에 맞추면 선 굵기는 줄지 않으므로, 24 기준 1.5가 아니라 16 크기에서 보이는 굵기 그대로 1.5가 됩니다. 원본 비율을 지키려면 `Viewbox` 안에 24×24 `Canvas`를 두고 `StrokeThickness="2"`를 쓰는 방법도 있습니다. 한 화면 안에서는 한 방법만 씁니다.
- lucide는 ISC 라이선스입니다. 아이콘을 옮겨 쓰면 프로젝트에 라이선스 고지를 남깁니다.

## 컨트롤 템플릿

- `Background`만 바꾼 기본 `Button`은 hover에서 Windows 기본색이 다시 나옵니다. 상태를 직접 그리려면 `ControlTemplate`을 정의해야 합니다. 예시는 `assets/Theme.Graphite.Dark.xaml`의 `Button.Primary`, `Button.Secondary`, `Button.Ghost`입니다.
- 각 상호작용 컨트롤이 갖춰야 할 상태:

| 컨트롤 | 상태 |
| --- | --- |
| `Button` | `IsMouseOver`, `IsPressed`, keyboard focus, `IsEnabled=False` |
| `ToggleButton`, `CheckBox`, `RadioButton` | 위 상태 + `IsChecked` |
| `ListBoxItem`, `ListViewItem`, `TreeViewItem` | `IsMouseOver`, `IsSelected`, `IsSelected`+창 비활성(`Selector.IsSelectionActive=False`), keyboard focus |
| `TextBox`, `PasswordBox`, `ComboBox` | `IsMouseOver`, `IsKeyboardFocused`, `IsEnabled=False`, 오류(`Validation.HasError`) |
| `DataGridRow`, `DataGridCell` | hover, 선택, 현재 셀 focus, 헤더 |
| `TabItem`, `MenuItem` | `IsMouseOver`/`IsHighlighted`, `IsSelected`/`IsChecked`, `IsEnabled=False` |

- **Keyboard focus**: 버튼 같은 컨트롤은 `FocusVisualStyle`로 표시합니다. 이 스타일은 Tab 키로 이동할 때만 보이고 마우스로 누를 때는 보이지 않습니다. `IsKeyboardFocused` trigger로 그리면 마우스로 눌러도 테두리가 남으므로 버튼에는 쓰지 않습니다. 입력 상자는 마우스로 눌러도 focus 표시가 필요하므로 `IsKeyboardFocused` trigger를 씁니다.
- **상태 색 animate**: 템플릿 안에서 `Border.Background`에 새 `SolidColorBrush`를 직접 만들고, trigger의 `EnterActions`/`ExitActions`에서 `ColorAnimation`으로 `(Border.Background).(SolidColorBrush.Color)`를 바꿉니다. `ExitActions`에서 `To`를 생략하면 원래 값으로 돌아갑니다. `Setter`로 `StaticResource` brush를 지정한 뒤 그 brush를 animate하면 freeze된 객체라서 예외가 납니다.
- **입력 상자 템플릿**: `TextBox`와 `PasswordBox`는 `Padding`을 내부 텍스트 영역에 직접 적용합니다. 템플릿의 `PART_ContentHost`에 `Margin="{TemplateBinding Padding}"`을 또 걸면 여백이 두 배가 되어 입력칸이 높아지고 글자가 안쪽으로 밀립니다. `PART_ContentHost`에는 `Margin`을 주지 않습니다.
- **상속한 버튼의 hover**: `Primary`가 `Flat`을 `BasedOn`으로 상속하고 `Flat` 템플릿 trigger가 `TargetName`으로 배경을 바꾸면, `Primary`의 hover도 `Flat`의 밝은 색이 되어 흰 글자가 보이지 않습니다. hover와 pressed 색은 템플릿 trigger 대신 `Style.Triggers`에서 `Background` 속성으로 바꾸고, 템플릿은 `Background="{TemplateBinding Background}"`로 받게 합니다. 그러면 파생 스타일이 자기 `Style.Triggers`로 색을 덮을 수 있습니다.
- **팝업**: `ComboBox`, `ContextMenu`, `ToolTip`의 팝업에도 같은 표면(`Brush.Card`), hairline, 반경을 줍니다. 팝업은 별도 창이라 `Window`의 리소스가 아니라 `App.xaml` 리소스에서 스타일을 찾게 둡니다.

## code-behind에서 만드는 UI

목록, 카드, 열처럼 데이터에 따라 code-behind가 요소를 만드는 화면이 많습니다. 이런 화면은 XAML만 고쳐서는 바뀌지 않습니다.

- `new Thickness(...)`, `FontSize = ...`, `FontWeights.*`, `new CornerRadius(...)`도 같은 토큰 규칙을 따릅니다. `audit-xaml.ps1`은 숫자 리터럴로 적은 `Thickness`, `FontSize`, 굵기만 찾습니다. 상수나 계산식으로 만든 값은 직접 확인합니다.
- 색은 `SetResourceReference(Border.BackgroundProperty, "Brush.Card")`처럼 리소스 참조로 연결합니다. 테마를 바꿀 때 함께 바뀝니다.
- 이벤트 처리기가 `sender is Border { Tag: ... }`처럼 요소 종류와 `Tag`에 의존하는 경우가 많습니다. 구조를 바꿀 때는 가장 바깥 요소의 종류와 `Tag`를 유지하고, 안쪽에 `Grid`를 끼워 넣는 방식으로 바꿉니다.
- 누를 수 있는 `Border`(카드, 행)는 `Button`이 아니므로 hover 상태가 저절로 생기지 않습니다. `MouseEnter`/`MouseLeave`에서 테두리나 배경 리소스를 바꿔 hover를 만듭니다.
- 테두리 한 변만 색을 바꾸는 것은 `Border` 하나로 할 수 없습니다. `BorderBrush`는 네 변에 모두 적용되기 때문입니다. 왼쪽 막대 같은 표시는 안쪽에 폭 3의 `Border`를 따로 두고, 반경은 바깥 반경에서 테두리 두께를 뺀 값으로 줍니다(예: `new CornerRadius(5, 0, 0, 5)`).

## 레이아웃

- 디자이너 드래그 흔적(`HorizontalAlignment="Left" VerticalAlignment="Top" Margin="37,112,0,0"`)은 `Grid`의 `RowDefinitions`/`ColumnDefinitions`와 `Auto`/`*` 크기로 바꿉니다.
- 반복되는 항목은 `ItemsControl`과 `ItemTemplate`으로 만들어 행 높이와 간격을 한곳에서 정합니다. 수동으로 복사한 행은 값이 조금씩 어긋나기 쉽습니다.
- WPF `StackPanel`에는 간격 속성이 없습니다. 항목 간격은 `ItemContainerStyle`의 `Margin` 또는 각 항목의 아래쪽 `Margin`(마지막 항목 제외)으로 줍니다. 위아래를 반씩 나눠 주면 그룹 경계에서 간격이 두 배가 됩니다.
- 창 크기에 따라 늘어나야 하는 영역에 고정 `Width`를 두지 않습니다. 최소 크기는 `Window.MinWidth`/`MinHeight`로 지킵니다.

## 창 틀

- 제목 표시줄을 직접 그리려면 `WindowStyle="None"`과 `AllowsTransparency="True"` 대신 `WindowChrome`(`System.Windows.Shell`, .NET 4.5 이상)을 우선 씁니다.
  ```xml
  <WindowChrome.WindowChrome>
      <WindowChrome CaptionHeight="36" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  ```
  - 제목 영역 안의 버튼은 `WindowChrome.IsHitTestVisibleInChrome="True"`를 줘야 눌립니다.
  - 창 이동, 크기 조절, Aero Snap, 작업 표시줄 동작이 유지됩니다.
- `AllowsTransparency="True"`는 layered window를 만들어서 렌더링 비용이 크고, ClearType이 꺼지고, 일부 환경에서 하드웨어 가속이 제한됩니다. 둥근 모양의 위젯이나 말풍선처럼 투명한 창이 꼭 필요한 경우에만 남깁니다. 이미 쓰고 있다면 바꾸기 전에 사용자에게 묻습니다. 창 동작이 바뀌기 때문입니다.
- 최대화된 `WindowChrome` 창은 화면 밖으로 몇 픽셀 넘칩니다. `WindowState`가 `Maximized`일 때 바깥 `Border`에 `Margin="7"` 정도를 주는 trigger로 보정합니다(값은 DPI에 따라 확인).

## 움직임

```xml
<Storyboard x:Key="Enter.FadeRise">
    <DoubleAnimation Storyboard.TargetProperty="Opacity" From="0" To="1"
                     Duration="{StaticResource Motion.Enter}" EasingFunction="{StaticResource Motion.Ease}"/>
    <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" From="8" To="0"
                     Duration="{StaticResource Motion.Enter}" EasingFunction="{StaticResource Motion.Ease}"/>
</Storyboard>
```

- 대상 요소에는 `RenderTransform`으로 `TranslateTransform`을 미리 둬야 합니다.
- stagger는 각 항목 storyboard의 `BeginTime`을 40~60ms씩 늘려서 만듭니다. 최대 6개까지만 둡니다.
- `RepeatBehavior="Forever"`는 실시간 상태(녹화 중, 동기화 중)를 나타낼 때만 남깁니다.
- `LayoutTransform`은 animate하지 않습니다. 매 프레임 layout을 다시 계산합니다.
- 숫자 tween이 필요하면 code-behind나 ViewModel의 값 변경이 필요합니다. 보고서에 제안으로 적습니다.

## 오른쪽에서 왼쪽으로 쓰는 언어

- 최상위 요소에 `FlowDirection="RightToLeft"`를 지정하면 레이아웃이 좌우 반전됩니다.
- 방향 아이콘은 반전되어야 하고, 이미지나 미디어 컨트롤은 반전되면 안 됩니다. 반전되면 안 되는 요소에는 `FlowDirection="LeftToRight"`를 다시 지정합니다.

---

unslop(Damir Sokolovsky, [@heydamir](https://x.com/heydamir), CC BY 4.0)을 WPF용으로 변형한 wpf-unslop의 일부입니다.
