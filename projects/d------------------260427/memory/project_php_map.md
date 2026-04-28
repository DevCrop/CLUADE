---
name: PHP non-obvious patterns
description: render() entry point, dual-track routing, imageUpload webp pattern, nb_ table list
type: project
originSessionId: 940f3c69-ab68-40c4-809f-8acca066cc76
---

# PHP non-obvious patterns

## render() entry point

- Defined at: `config/helpers.php:30`
- Signature: `render(string $template, array $data = [], ?string $viewsPath = null): string`
- Template notation: `'pages.works.view'` → `views/pages/works/view.php`

## Dual-track routing (non-obvious)

- **Public pages** — closure-based in `routes/web.php`. Adding a public page = adding a closure.
- **Admin pages** — do NOT use the closure router. **Physical file path = URL** (`/admin/pages/works/edit.php`). Adding an admin page = creating a file under `admin/pages/<area>/`.

## imageUpload() webp pattern (`inc/lib/func.php`)

jpg/jpeg/png/gif → converted to webp, **original file deleted**. The DB stores the `.webp` filename.
Bypass path: `\Core\ImageProcessor::convertToWebp($abs) ?? $original` (single API).
Image output: must go through `render_uploaded_image()` (`config/functions.php`) — no plain `<img>` or `<picture>` branching.

## nb_ table list

`nb_roles`, `nb_branches`, `nb_admin`, `nb_siteinfo`, `nb_branch_seos`, `nb_popups`, `nb_clients`, `nb_faqs`, `nb_board_manage`, `nb_board`, `nb_board_category`, `nb_board_comment`, `nb_board_lev_manage`, `nb_request`, `nb_site_tags`, `nb_works`, `nb_works_sort_no_undo`, `nb_migrations`, `nb_test`

Dropped: `nb_privacy_policy`, `nb_banners`, `nb_category`

**Why:** The dual-track pattern and imageUpload's forced webp conversion are not obvious from reading the code — missing them produces a broken admin route or leaves the original image on disk.
**How to apply:** Public route = closure. Admin route = file-based. Image storage = always go through `imageUpload()` / `convertToWebp()`.
