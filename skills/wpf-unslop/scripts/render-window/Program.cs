// wpf-unslop render-window: WPF 창을 띄우지 않고 PNG로 그린다. 포커스를 가져가지 않는다.
// 사용법: RenderWindow --assembly <앱.dll> --out <png> [--window MainWindow] [--width 1360] [--height 0] [--scale 2]
//   --height 0 이면 ScrollViewer 내용까지 포함한 전체 높이로 그린다.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        var opt = Parse(args);
        if (!opt.TryGetValue("assembly", out var asmArg) || !opt.TryGetValue("out", out var outArg))
        {
            Console.Error.WriteLine("사용법: --assembly <앱.dll> --out <png> [--window 이름] [--width 1360] [--height 0] [--scale 2]");
            return 1;
        }
        string asmPath = Path.GetFullPath(asmArg), outPath = Path.GetFullPath(outArg);
        double w = Num(opt, "width", 0), h = Num(opt, "height", 0), scale = Num(opt, "scale", 2);

        var dir = Path.GetDirectoryName(asmPath);
        AppDomain.CurrentDomain.AssemblyResolve += (_, e) =>
        {
            var p = Path.Combine(dir, new AssemblyName(e.Name).Name + ".dll");
            return File.Exists(p) ? Assembly.LoadFrom(p) : null;
        };
        var asm = Assembly.LoadFrom(asmPath);
        Type[] types;
        try { types = asm.GetTypes(); }
        catch (ReflectionTypeLoadException ex) { types = ex.Types.Where(t => t != null).ToArray(); }

        // 1. 앱 리소스(App.xaml)를 불러온다. Run()은 호출하지 않는다.
        var appType = types.FirstOrDefault(t => typeof(Application).IsAssignableFrom(t));
        if (appType != null)
        {
            var app = (Application)Activator.CreateInstance(appType);
            appType.GetMethod("InitializeComponent")?.Invoke(app, null);
        }

        // 2. 창을 만들되 Show()하지 않는다.
        string winName = opt.TryGetValue("window", out var wn) ? wn : "MainWindow";
        var winType = types.FirstOrDefault(t => typeof(Window).IsAssignableFrom(t) && t.Name == winName);
        if (winType == null)
        {
            Console.Error.WriteLine("ERROR: 창 클래스 " + winName + "을(를) 찾지 못했습니다. 있는 창: " +
                string.Join(", ", types.Where(t => typeof(Window).IsAssignableFrom(t)).Select(t => t.Name)));
            return 3;
        }
        Window win;
        try { win = (Window)Activator.CreateInstance(winType); }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ERROR: 창 생성자에서 예외가 났습니다. 인자가 필요한 생성자이거나 실행 시 오류입니다.");
            Console.Error.WriteLine((ex.InnerException ?? ex).ToString());
            return 4;
        }
        if (!(win.Content is UIElement content)) { Console.Error.WriteLine("ERROR: 창 Content가 비어 있습니다."); return 5; }

        // 3. 떼어 내기 전에 선택된 토글과 배경을 기록한다.
        var checkedToggles = new List<ToggleButton>();
        Collect(content, checkedToggles);
        var bg = win.Background;
        if (bg == null || (bg is SolidColorBrush s && s.Color.A == 0)) bg = new SolidColorBrush(Color.FromRgb(0x80, 0x80, 0x80));
        win.Content = null;

        // 폭: 지정하지 않으면 창의 Width, 그것도 없으면 1360
        if (w <= 0) w = !double.IsNaN(win.Width) && win.Width > 0 ? win.Width : 1360;
        var host = new Border { Background = bg, Width = w };
        // x:Name 이름 범위는 Window에 붙어 있다. 옮기지 않으면 ElementName 바인딩이 풀리지 않는다.
        var scope = NameScope.GetNameScope(win);
        if (scope != null) NameScope.SetNameScope(host, scope);
        host.Child = content;
        foreach (var key in win.Resources.Keys) host.Resources[key] = win.Resources[key];
        // Window의 FontFamily 등은 하위 요소가 상속한다. 옮기지 않으면 시스템 기본 글꼴로 그려진다.
        foreach (var dp in new DependencyProperty[] {
            TextElement.FontFamilyProperty, TextElement.FontSizeProperty, TextElement.FontWeightProperty,
            TextElement.FontStyleProperty, TextElement.FontStretchProperty, TextElement.ForegroundProperty,
            TextOptions.TextFormattingModeProperty, TextOptions.TextRenderingModeProperty, TextOptions.TextHintingModeProperty,
            FrameworkElement.FlowDirectionProperty, FrameworkElement.LanguageProperty, FrameworkElement.UseLayoutRoundingProperty })
        {
            if (win.ReadLocalValue(dp) != DependencyProperty.UnsetValue || BindingOperations.IsDataBound(win, dp))
                host.SetValue(dp, win.GetValue(dp));
        }

        // 4. 높이: 0이면 ScrollViewer 내용까지 포함한 전체 높이
        bool autoHeight = h <= 0;
        if (autoHeight)
        {
            host.Measure(new Size(w, double.PositiveInfinity));
            var sv = Find<ScrollViewer>(content);
            double need = host.DesiredSize.Height;
            if (sv?.Content is FrameworkElement fe) need = Math.Max(need, fe.DesiredSize.Height);
            h = Math.Ceiling(need);
        }
        host.Height = h;
        Layout(host, w, h);
        Pump();
        // 떼어 낸 RadioButton은 레이아웃 중에 GroupName 선택이 풀리므로 다시 지정한다.
        foreach (var t in checkedToggles) t.IsChecked = true;
        // 창을 띄우지 않으면 Loaded가 발생하지 않아 등장 애니메이션의 시작 상태(Opacity 0 등)로 그려진다.
        // Loaded로 시작하는 Storyboard를 끝 상태로 건너뛴다. 무한 반복 애니메이션은 시작하지 않는다.
        int settled = SettleLoadedAnimations(host, win.Triggers, out int skipped);
        if (settled + skipped > 0) Console.WriteLine("ANIM: 등장 애니메이션 값 " + settled + "개를 최종값으로 지정, 반복이거나 처리하지 못한 애니메이션 " + skipped + "개는 건너뜀");
        Pump(); // 애니메이션 값은 다음 처리 주기에 반영된다
        Layout(host, w, h);

        // 자동 높이: 배치해 본 뒤 세로 스크롤이 남은 ScrollViewer가 있으면 남은 만큼 높이를 늘려 다시 배치한다.
        // 첫 ScrollViewer만 보면 바깥 구조가 다른 화면에서 아래가 잘린다.
        // 높이가 고정된 카드 안의 스크롤 목록은 창을 늘려도 줄지 않으므로, 그런 ScrollViewer는 제외하고 늘린 만큼 되돌린다.
        if (autoHeight)
        {
            var fixedScrollers = new HashSet<ScrollViewer>();
            for (int i = 0; i < 8; i++)
            {
                var pending = All<ScrollViewer>(host).Where(sc => !fixedScrollers.Contains(sc) && sc.ScrollableHeight > 0.5).ToList();
                if (pending.Count == 0) break;
                var before = pending.ToDictionary(sc => sc, sc => sc.ScrollableHeight);
                double prevH = h;
                h = Math.Ceiling(h + before.Values.Max());
                host.Height = h;
                Layout(host, w, h);
                bool newlyFixed = false;
                foreach (var sc in pending)
                    if (sc.ScrollableHeight > before[sc] - 0.5) { fixedScrollers.Add(sc); newlyFixed = true; }
                if (newlyFixed)
                {
                    // 늘려도 줄지 않는 스크롤이 섞여 있었으면 이번 증가를 되돌리고, 남은 것만으로 다시 계산한다.
                    h = prevH;
                    host.Height = h;
                    Layout(host, w, h);
                }
            }
        }

        var bmp = new RenderTargetBitmap((int)(w * scale), (int)(h * scale), 96 * scale, 96 * scale, PixelFormats.Pbgra32);
        bmp.Render(host);
        var enc = new PngBitmapEncoder();
        enc.Frames.Add(BitmapFrame.Create(bmp));
        Directory.CreateDirectory(Path.GetDirectoryName(outPath));
        using (var fs = File.Create(outPath)) enc.Save(fs);
        Console.WriteLine("SAVED: " + outPath + " (" + w + "x" + h + " DIP, " + scale + "x)");
        FontReport(host);
        return 0;
    }

    static void Layout(FrameworkElement e, double w, double h)
    {
        e.Measure(new Size(w, h));
        e.Arrange(new Rect(0, 0, w, h));
        e.UpdateLayout();
    }

    static void Pump()
    {
        var frame = new DispatcherFrame();
        Dispatcher.CurrentDispatcher.BeginInvoke(DispatcherPriority.ContextIdle, new Action(() => frame.Continue = false));
        Dispatcher.PushFrame(frame);
    }

    // 화면의 TextBlock이 실제로 어떤 글꼴 파일로 그려졌는지 출력한다.
    static void FontReport(DependencyObject root)
    {
        var counts = new Dictionary<string, int>();
        void Walk(DependencyObject d)
        {
            if (d is TextBlock tb && !string.IsNullOrEmpty(tb.Text))
            {
                var tf = new Typeface(tb.FontFamily, tb.FontStyle, tb.FontWeight, tb.FontStretch);
                string file = tf.TryGetGlyphTypeface(out var g) ? Path.GetFileName(Uri.UnescapeDataString(g.FontUri.AbsolutePath)) : "?";
                string key = tb.FontFamily.Source + " / " + tb.FontWeight + " -> " + file;
                counts[key] = counts.TryGetValue(key, out var n) ? n + 1 : 1;
            }
            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(d); i++) Walk(VisualTreeHelper.GetChild(d, i));
        }
        Walk(root);
        foreach (var kv in counts.OrderByDescending(k => k.Value)) Console.WriteLine("FONT " + kv.Value.ToString().PadLeft(4) + "  " + kv.Key);
    }

    static int SettleLoadedAnimations(FrameworkElement root, TriggerCollection windowTriggers, out int skipped)
    {
        int settled = 0, skip = 0;
        var seen = new HashSet<DependencyObject>();
        void Run(FrameworkElement fe, IEnumerable<TriggerCollection> sources)
        {
            foreach (var col in sources)
            foreach (var trig in col.OfType<EventTrigger>())
            {
                if (trig.RoutedEvent != FrameworkElement.LoadedEvent) continue;
                foreach (var bs in trig.Actions.OfType<System.Windows.Media.Animation.BeginStoryboard>())
                {
                    if (bs.Storyboard == null) continue;
                    ApplyFinal(bs.Storyboard, fe, null, ref settled, ref skip);
                }
            }
        }
        // Window의 Loaded trigger(Window.Loaded)는 Window에 붙어 있으므로 따로 실행한다. 대상 이름은 옮겨 둔 이름 범위에서 찾는다.
        Run(root, new[] { windowTriggers });
        void Visit(DependencyObject d)
        {
            if (d == null || !seen.Add(d)) return;
            if (d is FrameworkElement fe)
            {
                var sources = new List<TriggerCollection> { fe.Triggers };
                if (fe.Style != null) sources.Add(fe.Style.Triggers);
                Run(fe, sources);
            }
            if (d is Visual || d is System.Windows.Media.Media3D.Visual3D)
                for (int i = 0; i < VisualTreeHelper.GetChildrenCount(d); i++) Visit(VisualTreeHelper.GetChild(d, i));
            foreach (var c in LogicalTreeHelper.GetChildren(d)) if (c is FrameworkElement o) Visit(o);
        }
        Visit(root);
        skipped = skip;
        return settled;
    }

    // 창이 없으면 애니메이션 시계가 돌지 않으므로, 각 애니메이션의 최종값(To, 없으면 From+By)을 대상 속성에 직접 지정한다.
    static void ApplyFinal(System.Windows.Media.Animation.Timeline t, FrameworkElement owner, string inheritedName, ref int settled, ref int skip)
    {
        string name = System.Windows.Media.Animation.Storyboard.GetTargetName(t) ?? inheritedName;
        if (t is System.Windows.Media.Animation.TimelineGroup g)
        {
            if (t.RepeatBehavior == System.Windows.Media.Animation.RepeatBehavior.Forever) { skip++; return; }
            foreach (var c in g.Children) ApplyFinal(c, owner, name, ref settled, ref skip);
            return;
        }
        if (IsForever(t)) { skip++; return; }
        try
        {
            object target = name != null ? owner.FindName(name) : owner;
            if (target == null && name != null) target = NameScope.GetNameScope(owner)?.FindName(name);
            var path = System.Windows.Media.Animation.Storyboard.GetTargetProperty(t);
            object value = FinalValue(t);
            if (!(target is DependencyObject obj) || path == null || value == null) { skip++; return; }

            // 경로를 의존 속성 목록으로 바꾼다. "(0).(1)" 형식이면 PathParameters, "Opacity" 형식이면 이름으로 찾는다.
            var dps = new List<DependencyProperty>();
            if (path.PathParameters.Count > 0) dps.AddRange(path.PathParameters.OfType<DependencyProperty>());
            else
            {
                Type ty = obj.GetType();
                foreach (var part in path.Path.Split('.'))
                {
                    var dpd = System.ComponentModel.DependencyPropertyDescriptor.FromName(part, ty, ty);
                    if (dpd == null) { skip++; return; }
                    dps.Add(dpd.DependencyProperty);
                    ty = dpd.PropertyType;
                }
            }
            if (dps.Count == 0) { skip++; return; }
            for (int i = 0; i < dps.Count - 1; i++)
            {
                var next = obj.GetValue(dps[i]) as DependencyObject;
                if (next is Freezable fz && fz.IsFrozen) { next = fz.Clone(); obj.SetValue(dps[i], next); }
                if (next == null) { skip++; return; }
                obj = next;
            }
            obj.SetValue(dps[dps.Count - 1], value);
            settled++;
        }
        catch (Exception) { skip++; }
    }

    static object FinalValue(System.Windows.Media.Animation.Timeline t)
    {
        var type = t.GetType();
        var to = type.GetProperty("To")?.GetValue(t);
        if (to != null) return to;
        var from = type.GetProperty("From")?.GetValue(t);
        var by = type.GetProperty("By")?.GetValue(t);
        if (from is double f && by is double b) return f + b;
        // 키 프레임 애니메이션은 마지막 키 프레임 값
        if (type.GetProperty("KeyFrames")?.GetValue(t) is System.Collections.IList frames && frames.Count > 0)
            return frames[frames.Count - 1].GetType().GetProperty("Value")?.GetValue(frames[frames.Count - 1]);
        return null;
    }

    static bool IsForever(System.Windows.Media.Animation.Timeline t)
    {
        if (t.RepeatBehavior == System.Windows.Media.Animation.RepeatBehavior.Forever) return true;
        if (t is System.Windows.Media.Animation.TimelineGroup g)
            foreach (var c in g.Children) if (IsForever(c)) return true;
        return false;
    }

    static void Collect(DependencyObject d, List<ToggleButton> acc)
    {
        if (d is ToggleButton t && t.IsChecked == true) acc.Add(t);
        foreach (var c in LogicalTreeHelper.GetChildren(d)) if (c is DependencyObject o) Collect(o, acc);
    }

    static IEnumerable<T> All<T>(DependencyObject d) where T : DependencyObject
    {
        if (d is T hit) yield return hit;
        if (!(d is Visual)) yield break;
        for (int i = 0; i < VisualTreeHelper.GetChildrenCount(d); i++)
            foreach (var x in All<T>(VisualTreeHelper.GetChild(d, i))) yield return x;
    }

    static T Find<T>(DependencyObject d) where T : class
    {
        if (d is T hit) return hit;
        foreach (var c in LogicalTreeHelper.GetChildren(d)) if (c is DependencyObject o && Find<T>(o) is T f) return f;
        return null;
    }

    static Dictionary<string, string> Parse(string[] args)
    {
        var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i + 1 < args.Length; i += 2) d[args[i].TrimStart('-')] = args[i + 1];
        return d;
    }

    static double Num(Dictionary<string, string> o, string k, double def) =>
        o.TryGetValue(k, out var v) && double.TryParse(v, System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture, out var r) ? r : def;
}
