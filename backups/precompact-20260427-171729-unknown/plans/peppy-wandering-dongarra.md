# Plan

## Task 1: "전체 요금표 보기" → "View Full Pricing" + 화살표 아이콘

- lang/ko.php 3곳 텍스트 변경 (line 200, 508, 534)
- 템플릿에서 `e()` 이스케이프를 사용하므로 `<i>` 태그는 lang 문자열에 넣지 않고 뷰 파일에 직접 추가
  - views/pages/brands.php: `cta_view_pricing` 출력 부근에 arrow span 추가
  - views/pages/channel-partners.php: `link_text` 출력 부근에 arrow span 추가

## Task 2: 한 줄 배치

- "짧은 상담으로 현재 단계를 진단하고\n가장 효율적인 다음 경로를 찾으세요." → 한 줄로
