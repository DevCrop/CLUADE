---
name: PHP 비자명 패턴
description: render() 진입점, 이중 트랙 라우팅, imageUpload webp 패턴, nb_ 테이블 목록
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# PHP 비자명 패턴

## render() 진입점

- 정의: `config/helpers.php:30`
- 시그니처: `render(string $template, array $data = [], ?string $viewsPath = null): string`
- 템플릿 표기: `'pages.works.view'` → `views/pages/works/view.php`

## 이중 트랙 라우팅 (비자명)

- **공개 페이지** — `routes/web.php` closure 기반. 새 공개 페이지 = closure 추가.
- **Admin 페이지** — closure 라우터 사용 안 함. **물리 경로 PHP 파일 = URL** (`/admin/pages/works/edit.php`). 새 admin 페이지 = `admin/pages/<area>/` 파일 생성.

## imageUpload() webp 패턴 (`inc/lib/func.php`)

jpg/jpeg/png/gif → webp 변환 후 **원본 삭제**. DB에 `.webp` 파일명 저장.
우회 시: `\Core\ImageProcessor::convertToWebp($abs) ?? $original` (단일 API).
이미지 출력: 반드시 `render_uploaded_image()` (`config/functions.php`) 경유 — plain `<img>`, `<picture>` 분기 없음.

## nb_ 테이블 목록

`nb_roles`, `nb_branches`, `nb_admin`, `nb_siteinfo`, `nb_branch_seos`, `nb_popups`, `nb_clients`, `nb_faqs`, `nb_board_manage`, `nb_board`, `nb_board_category`, `nb_board_comment`, `nb_board_lev_manage`, `nb_request`, `nb_site_tags`, `nb_works`, `nb_works_sort_no_undo`, `nb_migrations`, `nb_test`

드롭됨: `nb_privacy_policy`, `nb_banners`, `nb_category`

**Why:** 이중 트랙 패턴과 imageUpload webp 강제 변환은 코드를 봐도 비자명 — 모르면 admin 라우팅을 잘못 만들거나 원본 이미지가 남음.
**How to apply:** 공개 라우트 = closure. admin 라우트 = 파일 기반. 이미지 저장 = `imageUpload()` / `convertToWebp()` 반드시 경유.
