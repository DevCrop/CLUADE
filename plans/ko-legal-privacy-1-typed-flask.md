# Plan: 마케팅처리방침 페이지 분리 및 영문 대응

## Context

`views/pages/legal/privacy-body.php` (lines 302–330)에 하드코딩된 "마케팅 정보 활용 방침" 섹션을 독립 페이지로 분리한다. 푸터에 개인정보처리방침 링크 옆 형제 링크로 노출하고, 콘텐츠는 `ko.php` / `en.php`에서만 관리한다.

> **기존 `legal.marketing` 페이지 (`/ko/legal/marketing`)** 는 "마케팅 약관"(수신 동의 정책) 페이지로 별도 존재함 — 건드리지 않음.

---

## Files to Modify

| File | Action |
|------|--------|
| `views/pages/legal/privacy-body.php` | lines 302–330 마케팅 섹션 제거 |
| `routes/web.php` | 새 라우트 추가 |
| `views/components/footer.php` | 푸터 링크 추가 |
| `lang/ko.php` | 콘텐츠 키 + 푸터 레이블 추가 |
| `lang/en.php` | 영문 콘텐츠 키 + 푸터 레이블 추가 |

## Files to Create

| File | Purpose |
|------|---------|
| `views/pages/legal/marketing-policy.php` | 마케팅처리방침 뷰 (12-line wrapper) |

---

## Implementation Steps

### 1. `views/pages/legal/privacy-body.php`
Lines 302–330 (`<!-- 마케팅 정보 활용 방침 -->` div 전체) 삭제.

### 2. `routes/web.php`
`/legal` group에 추가:
```php
$r->get('/marketing-policy', fn() => render('pages.legal.marketing-policy'))->name('legal.marketing-policy');
```

### 3. `views/pages/legal/marketing-policy.php` (신규)
```php
<?php section('content') ?>

<?= include_view('components.legal-document', [
    'pageKey'      => 'pages.legal.marketing_policy',
    'currentRoute' => 'legal.marketing-policy',
    'showNav'      => false,
]) ?>

<?php end_section() ?>

<?php section('portal') ?>
<?= include_view('components.popup'); ?>
<?php end_section() ?>
```

### 4. `lang/ko.php`
**footer 섹션** (line ~25 `privacy_policy` 아래):
```php
'marketing_policy' => '마케팅처리방침',
```

**pages.legal 섹션** (`cookies` 키 위에) — `pages.legal.marketing_policy` 신규:
```php
'marketing_policy' => [
    'sub_visual' => [
        'title'       => '마케팅처리방침',
        'headline'    => '마케팅처리방침',
        'description' => '에버큐라의 마케팅 정보 수집 및 이용에 관한 방침입니다.',
    ],
    'updated_label' => '현행',
    'updated_at'    => '2026년 04월 01일 시행',
    'intro'         => '',
    'summary_title' => '',
    'summary_items' => [],
    'sections' => [
        [
            'title' => '1. 개인 정보수집 및 이용 목적',
            'body'  => ['고객의 서비스 이용에 대한 통계, 각종 정보 및 이벤트 관련 사항 소개 및 안내'],
        ],
        [
            'title' => '2. 수집 항목',
            'body'  => ['개인 식별 정보: 성명, 회사명, 전화번호, 이메일 등'],
        ],
        [
            'title' => '3. 보유 기간',
            'body'  => ['1년'],
        ],
        [
            'title' => '4. 약관 개정',
            'body'  => ['약관은 타당한 사유가 있을 시 개정될 수 있으며, 회사는 이 경우 당사 홈페이지를 통해 이를 공지합니다.'],
        ],
    ],
    'contact_title' => '',
    'contact_body'  => '',
],
```

### 5. `lang/en.php`
동일 구조로 영문 추가:

**footer:**
```php
'marketing_policy' => 'Marketing Policy',
```

**pages.legal.marketing_policy:**
```php
'marketing_policy' => [
    'sub_visual' => [
        'title'       => 'Marketing Policy',
        'headline'    => 'Marketing Policy',
        'description' => 'EverCura\'s policy on the collection and use of marketing information.',
    ],
    'updated_label' => 'Effective',
    'updated_at'    => 'April 1, 2026',
    'intro'         => '',
    'summary_title' => '',
    'summary_items' => [],
    'sections' => [
        [
            'title' => '1. Purpose of Collection and Use',
            'body'  => ['Statistics on customer service usage, and introduction and guidance on various information and event-related matters.'],
        ],
        [
            'title' => '2. Items Collected',
            'body'  => ['Personal identification information: name, company name, phone number, email address, etc.'],
        ],
        [
            'title' => '3. Retention Period',
            'body'  => ['1 year'],
        ],
        [
            'title' => '4. Policy Amendments',
            'body'  => ['These terms may be amended when there is a valid reason to do so, in which case the Company will notify users through the official website.'],
        ],
    ],
    'contact_title' => '',
    'contact_body'  => '',
],
```

### 6. `views/components/footer.php`
Line 83–84 기존 privacy 링크 **바로 뒤**에 형제 `<a>` 추가:
```php
<a href="<?= e(route('legal.marketing-policy')) ?>"
    class="no-footer__legal-link"><?= e(__('footer.marketing_policy')) ?></a>
```

---

## Verification

1. `/ko/legal/marketing-policy` 접속 → "마케팅처리방침" 페이지 정상 렌더
2. `/en/legal/marketing-policy` 접속 → 영문 페이지 정상 렌더
3. `/ko/legal/privacy` → 개인정보처리방침에서 마케팅 섹션 사라졌는지 확인
4. 푸터에 `개인정보처리방침 | 마케팅처리방침` 링크 나란히 노출 확인
5. 기존 `/ko/legal/marketing` (마케팅 약관) 페이지 정상 유지 확인
