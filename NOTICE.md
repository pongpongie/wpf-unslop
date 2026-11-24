# 출처와 라이선스

## 출처

wpf-unslop은 Damir Sokolovsky([@heydamir](https://x.com/heydamir))가 만든 [unslop](https://github.com/heydamir/unslop)을 WPF용으로 변형한 **비공식** 작업입니다. 원작자와 관계없으며, 원작자가 승인하거나 관리하지 않습니다. unslop은 CC BY 4.0으로 배포됩니다.

## 라이선스

| 대상 | 라이선스 | 전문 |
| --- | --- | --- |
| 아래 `scripts/`를 뺀 전체 (`SKILL.md`, `references/`, `assets/`, `README.md` 등) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [LICENSE](LICENSE) |
| `skills/wpf-unslop/scripts/` (`audit-xaml.ps1`, `capture-window.ps1`, `render-window.ps1`, `render-window/`) | MIT, Copyright (c) 2026 Sihyun Lee | [skills/wpf-unslop/scripts/LICENSE](skills/wpf-unslop/scripts/LICENSE) |

`scripts/`의 스크립트는 unslop에 없던 코드로 이 저장소에서 새로 작성했습니다. 점검 항목은 unslop의 판단 기준을 참고했지만, 코드는 원본에서 가져오지 않았습니다.

## 변경 사항

unslop 대비 바꾼 내용입니다.

- 대상을 웹(React, Tailwind, HTML/CSS)에서 WPF XAML로 바꿨습니다.
- 지침과 참고 문서를 한국어로 다시 썼고, XAML 사례와 WPF 고유 항목(컨트롤 템플릿 상태, 텍스트 렌더링, 창 틀, `Effect`)을 추가했습니다.
- 토큰 값을 XAML 형식(`#AARRGGBB`, `CornerRadius`, `QuinticEase`)으로 옮기고, 데스크톱 앱에 맞게 반경과 버튼 크기를 조정했습니다.
- landing page hero, 이미지 생성 절차, story video, 라이브 사이트 snapshot 기능을 뺐습니다.
- 원본의 참고 이미지 중 대시보드 결과(`references/refs/unslop-dashboard-after.webp`)는 바꾸지 않고 그대로 가져왔습니다. 원본 `references/refs.md`의 설명은 한국어로 옮기고 WPF 구현 표를 더해 `references/refs.md`를 만들었습니다. 랜딩 페이지용 참고 이미지는 가져오지 않았습니다.
- 방향에 글꼴 줄을 더해 여섯 줄로 만들었습니다. WPF는 글꼴을 포함하려면 프로젝트 파일을 바꿔야 하기 때문입니다.
- 한글 글꼴 후보(Pretendard 등)를 추가했습니다. 원본 후보는 라틴 글꼴뿐입니다. 시스템 글꼴의 굵기 제약(`맑은 고딕`에 500, 600이 없음)과 그에 따른 굵기 규칙의 예외도 추가했습니다.
- XAML 정적 점검 스크립트(`audit-xaml.ps1`), 창 캡처 스크립트(`capture-window.ps1`), 시작용 테마 사전(`Theme.Graphite.Dark.xaml`)을 새로 만들었습니다.

## 다시 배포할 때

복사하거나 다시 변형할 때는 위 원저작자 표기, 이 파일, 각 라이선스 전문을 유지합니다.
