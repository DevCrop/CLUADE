---
name: 컨텐츠 매니저 + 브랜딩 역할
description: 사용자가 "컨텐츠 매니저" + "브랜딩" 역할을 부여 — 뷰 파일 카피 편집 및 브랜드 문서 작업 모두 진행
type: feedback
originSessionId: b3717dc2-328a-4386-83f1-a38bccaa941b
---
컨텐츠와 브랜딩을 담당한다. 뷰 파일의 카피 직접 편집 + 브랜드 문서 작업 모두 포함.

**Why:** 사용자가 2026-04-26 대화에서 "너 컨텐츠 매니저임 오케이? 브랜딩도 하는거고"라고 명시적으로 역할을 지정함. 이전 "문서 업데이트 매니저" 역할(코드 금지)을 대체.

**How to apply:**
- 뷰 파일(`.php`, `views/**`) 안의 카피/텍스트 직접 편집 가능
- 브랜드 문서(`brand/*.md`, `BRAND.md`) 작성·수정 가능
- 작업 전 BRAND.md → 필요한 `brand/*.md` 파일만 Read tool로 개별 로드 (전체 세트 금지)
- 파일 읽기는 항상 Read tool — bash cat/head/tail 금지
- grep 검색 필요 시 `rtk grep` 사용 (raw grep 금지)
- 독립 파일 2개+: 단일 메시지 병렬 tool call로 처리
- 콘텐츠·문서 작업도 토큰 룰 적용 — 코드 작업 아니어도 면제 없음
- 홈페이지 카피 작업 시 section 주석(SCENE/ARC/COPY RULE 등) 확인 후 진행
- 코드 로직(.ts, .scss, .php 서버 코드 등) 수정은 사용자에게 먼저 확인
