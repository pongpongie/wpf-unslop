# 참고 이미지

방향을 정하기 전과 Visuals pass 전에 봅니다. 결과물이 얼마나 풍부해야 하는지 맞추는 기준입니다. 이미지의 성질(틀의 절제, 강조 지점의 밀도, 색의 의미, 물건의 재질)만 가져오고 주제, 팔레트, 배치는 가져오지 않습니다. 모든 제품은 자기 화면을 가져야 합니다.

| 파일 | 보여 주는 것 | 왜 잘 되는가 |
| --- | --- | --- |
| [unslop-dashboard-after.webp](refs/unslop-dashboard-after.webp) | 결제 카드 2장을 렌더링한 통계 카드와, 계열마다 색이 다른 부드러운 곡선 위에 회색 비교 곡선을 거울처럼 놓은 매출 차트가 있는 금융 대시보드 | 틀은 graphite로 조용하고, 색은 두 강조 지점에 모두 모였습니다. 하나는 진짜처럼 보이는 물건이고, 하나는 모든 색이 계열을 뜻하는 차트입니다 |

## 이 이미지에서 볼 것

| 요소 | 이미지에서 | WPF에서 옮기는 방법 |
| --- | --- | --- |
| 틀 | 배경, 사이드바, 카드가 모두 graphite 단계. 선택 항목만 한 단계 밝은 표면 | [tokens.md](tokens.md)의 graphite 단계, `NavButton` 선택 상태 |
| 의미 있는 색 | 요금제마다 색 점이 있고, 같은 색이 차트 계열에 쓰임 | 분류 색을 토큰으로 정의하고 목록의 점과 차트에 같은 키를 씀 |
| 물건 | 통계 숫자 옆에 그 숫자가 세는 결제 카드를 진짜 재질로 그림 | `Border`, 부드러운 gradient, 칩 `Path`, `RotateTransform`, 형제 요소 그림자 |
| 차트 | 부드러운 곡선, 아래쪽에 회색 비교 곡선 | `StreamGeometry`의 `BezierTo`로 곡선, 비교 계열은 무채색 |
| 숫자와 메타 | 큰 숫자, mono 글꼴의 비교 문구, 회색으로 낮춘 연도 | 숫자는 `Typography.NumeralAlignment="Tabular"`, 메타는 mono, 보조 부분은 secondary 색 |

원본 unslop에는 랜딩 페이지용 참고 이미지(장면 hero, 판화, 3D footer)와 story video 프레임도 있습니다. 데스크톱 앱 화면에는 해당하지 않아서 포함하지 않았습니다. 원본 저장소의 `skills/unslop/references/refs.md`에 있습니다.

---

`unslop-dashboard-after.webp`와 이 문서의 표 첫 부분은 unslop(Damir Sokolovsky, [@heydamir](https://x.com/heydamir), CC BY 4.0)의 `references/refs.md`와 `references/refs/unslop-dashboard-after.webp`에서 가져왔습니다. 이미지는 바꾸지 않았고, 설명은 한국어로 옮기고 WPF 구현 표를 더했습니다. 복사하거나 변형할 때 이 출처를 유지합니다.
