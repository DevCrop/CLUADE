# /cors-test/ 양방향 API + 리소스 동기화 테스트 코드베이스

## Context

보안 컴플라이언스 요구사항 (전금법/ISMS-P류) — **일반 사용자 서비스와 관리자 서비스를 분리된 서버/도메인/포트로 운영해야 하며, admin 도메인은 추측 불가 경로 + 내부망/VPN ACL** — 을 만족시키기 위한 사전 검증 단계의 코드베이스를 만든다.

**운영 중 사이트에 배포하므로 영향 zero가 최우선**. 두 호스팅(`bluesquare.kr`, `www.noltheater-daehakro.com`)이 현재 실서비스 중이며, 이게 성공하면 각 도메인별 ADMIN 전용 호스팅 2개를 추가할 예정. 테스트 코드가 운영 트래픽·DB·세션·htaccess·디스크에 어떤 영향도 줘서는 안 된다.

테스트로 검증할 것:
1. 두 호스팅 사이의 **HMAC + 타임스탬프 + IP 화이트리스트(옵션)** 기반 서버-서버 API 동작
2. **파일 리소스가 admin 도메인 노출 없이** 사용자 도메인에서만 서빙되는 흐름
3. **외부 origin 브라우저 fetch는 CORS 차단** + 위조/리플레이/path traversal/대용량/IP 미허용 거부

두 도메인은 별개 eTLD+1 (`.kr` vs `.com`)이라 쿠키/CORS 격리 환경으로 이상적.

**확정된 결정사항**:
- 양방향 (둘 다 서로의 admin이자 user). 같은 코드 + `config.local.php`만 다름.
- 별도 `/cors-test/` 디렉토리. 운영 코드 require/include 0건.
- self-contained (noltheater에 없는 `/inc/lib/*` 의존 금지).

---

## 0. 운영 서비스 격리 보장 (Service Isolation Guarantees) ★최우선★

### 0.1 경로 격리
- 모든 신규/수정 파일은 **`/cors-test/` 단일 디렉토리 안에만**. 외부 파일 추가/수정 0건.
- 운영 코드 require/include 0건. cors-test는 자체 helper만 사용.
- 진입 가능한 외부 URL은 다음 6개로 한정:
  - `/cors-test/whoami.php` (GET)
  - `/cors-test/api/upload.php` (POST, ADMIN_TOKEN)
  - `/cors-test/api/receive.php` (POST, HMAC)
  - `/cors-test/api/list.php` (GET, HMAC|TOKEN)
  - `/cors-test/api/file.php` (GET/PUT/DELETE)
  - `/cors-test/ui/*` (수동 검증용)
- 배포 전 점검: 양쪽 호스팅에 `/cors-test/` 경로가 이미 존재하지 않는지 확인.

### 0.2 DB 격리
- 신규 테이블 prefix `cors_test_*`만 사용. 기존 테이블 절대 안 건드림.
- **별도 DB user 생성 강력 권장** (`cors_test_user`):
  - 권한: `cors_test_*` 두 테이블에만 SELECT/INSERT/UPDATE/DELETE
  - 다른 테이블/스키마 접근 불가
- DB user 분리 불가 시 (호스팅 제약), 기존 user 사용하되 cors-test 코드는 **테이블명 화이트리스트** (`cors_test_files`, `cors_test_sync_log`만 SQL에 등장하는지 grep 자동 검증).
- 배포 전 점검: `SHOW TABLES LIKE 'cors\_test\_%'` 결과 비어있어야 함.
- 운영 DB 영향 모니터: 배포 전후 운영 핵심 테이블 5개의 `SELECT COUNT(*)` 캡처해 변화 없음 확인.

### 0.3 Apache / .htaccess 격리
- 루트 `.htaccess`는 **절대 수정 X**.
- `/cors-test/.htaccess`의 모든 디렉티브는 자기 디렉토리에만 적용 (RewriteRule 외부 영향 없도록 검증).
- `<IfModule>` 가드로 모듈 부재 시 무동작.
- 배포 전 점검: 핵심 페이지 baseline curl 캡처 → 배포 후 동일 응답 확인.

### 0.4 세션 / 쿠키 격리
- `session_start()` **금지**. cors-test는 stateless.
- 인증은 `X-Admin-Token` 헤더 또는 HMAC만.
- 쿠키 set 0건. 운영 세션 영향 0.

### 0.5 검색엔진 / 외부 노출 격리
- `/cors-test/robots.txt` 자체 배치 (루트 robots.txt 수정 X) — `User-agent: *\nDisallow: /`.
- 모든 HTML/PHP 응답에 `X-Robots-Tag: noindex, nofollow` 헤더.
- 외부 링크 0건. 사이트맵 미포함.

### 0.6 자원 사용 격리
- 업로드 한도 100MB. 호스팅 디스크 여유 ≥ 5GB 사전 확인.
- `/cors-test/storage/` cleanup 정책 명시 (테스트마다 reset 또는 매일 cron).
- 로그 rotate (1MB 초과 시 `.1`로 archive, 5세대 유지).
- PHP error_log 별도 파일 (`/cors-test/logs/error.log`) — 운영 error_log 미오염.

### 0.7 KILL_SWITCH (즉시 차단 스위치)
- `config.local.php`에 `define('KILL_SWITCH', false)`. true 토글 시 `bootstrap.php`가 모든 요청에 503 maintenance 응답 (DB 미접속).
- 모든 엔드포인트 첫 줄에서 KILL_SWITCH 체크.

---

## 1. 디렉토리 구조

```
/cors-test/
├── config.php                        # dispatcher
├── config.local.php                  # gitignore. SECRET, DB, peer, IP, KILL_SWITCH
├── config.local.php.example
├── .htaccess                         # 자기 디렉토리 한정 deny rules
├── robots.txt                        # User-agent: * / Disallow: /
│
├── lib/
│   ├── bootstrap.php                 # KILL_SWITCH 체크, config, helpers, X-Robots-Tag
│   ├── db.php                        # PDO 싱글톤
│   ├── http.php                      # respondJson, readRawBody, headerOrNull
│   ├── hmac.php                      # sign(), verify(), canonicalString()
│   ├── upload.php                    # safeBasename, mimeCheck (finfo), sha256OfFile, sizeGuard
│   ├── peer.php                      # pushToPeer() — outbound + HMAC
│   ├── audit.php                     # logSync()
│   └── guard.php                     # validateInbound() — IP+TS+HMAC 게이트
│
├── api/
│   ├── upload.php                    # POST. 로컬 admin form → 저장 + peer push
│   ├── receive.php                   # POST. peer 푸시 수신 (HMAC)
│   ├── list.php                      # GET. 메타 목록
│   ├── file.php                      # GET/PUT/DELETE. 단일 파일 CRUD
│   └── whoami.php                    # GET. 환경 진단
│
├── ui/
│   ├── upload-form.html              # multipart POST → /api/upload.php
│   └── dashboard.php                 # 자기/peer 목록 비교
│
├── tests/
│   ├── _common.sh                    # SECRET, BASE_A/B, sign() bash, assertEquals()
│   ├── 00_preflight.sh               # 운영 영향 0 사전 점검
│   ├── 01_normal_upload.sh
│   ├── 02_normal_upload_reverse.sh
│   ├── 03_bad_signature.sh
│   ├── 04_replay_old_ts.sh
│   ├── 05_path_traversal.sh
│   ├── 06_oversized.sh
│   ├── 07_wrong_ip.sh
│   ├── 99_postcheck.sh               # 운영 baseline 회귀 검증
│   ├── reset.sh                      # 테스트 잔여 cleanup
│   ├── run_all_tests.sh              # preflight → 01~07 → postcheck 자동 실행
│   ├── 05_cors_browser.html          # 외부 origin fetch 차단 확인
│   └── fixtures/
│       ├── small.png                 # ~10KB 테스트 이미지
│       ├── schema.sql                # cors_test_files + cors_test_sync_log DDL
│       └── baseline_urls.txt         # 운영 핵심 URL 목록 (응답 비교용)
│
├── storage/                          # .htaccess Deny + RemoveHandler .php
│   └── .htaccess
└── logs/                             # .htaccess Deny + RemoveHandler .php
    └── .htaccess
```

### admin/user 분리 방식

테스트 단계: role flag 없이 엔드포인트 의미로만 구분.

| 엔드포인트 | 호출 주체 | 인증 |
|---|---|---|
| `api/upload.php` | 로컬 사람 | `X-Admin-Token` |
| `api/receive.php` | peer | HMAC |
| `api/list.php`, `api/file.php` GET | 양쪽 | HMAC 또는 TOKEN |
| `api/file.php` PUT/DELETE | admin → peer 전파 | HMAC + TOKEN |

운영 전환 시 `config.local.php`에 `ROLE='ADMIN'|'USER'|'BOTH'` 추가 → bootstrap에서 비활성 엔드포인트 405.

---

## 2. 데이터 모델 (MySQL 8.0)

### 2.1 `cors_test_files`
```sql
CREATE TABLE cors_test_files (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  filename      VARCHAR(255)    NOT NULL,
  original_name VARCHAR(512)    NOT NULL,
  mime          VARCHAR(127)    NOT NULL,
  size          BIGINT UNSIGNED NOT NULL,
  sha256        CHAR(64)        NOT NULL,
  source_host   VARCHAR(255)    NOT NULL,
  synced_at     DATETIME        NULL,
  created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_sha256_source (sha256, source_host),
  KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.2 `cors_test_sync_log`
```sql
CREATE TABLE cors_test_sync_log (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ts               DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  direction        ENUM('IN','OUT') NOT NULL,
  action           VARCHAR(32)     NOT NULL,
  signature_hash   CHAR(16)        NULL,
  source_ip        VARCHAR(45)     NULL,
  peer_url         VARCHAR(512)    NULL,
  http_status      SMALLINT        NULL,
  response_excerpt VARCHAR(1024)   NULL,
  ok               TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_ts (ts),
  KEY idx_action (action, direction)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 DB user 별도 생성 (권장)
```sql
CREATE USER 'cors_test_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT SELECT, INSERT, UPDATE, DELETE ON <dbname>.cors_test_files TO 'cors_test_user'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON <dbname>.cors_test_sync_log TO 'cors_test_user'@'%';
FLUSH PRIVILEGES;
```

---

## 3. API 엔드포인트 명세

공통 응답: `{ok: bool, data, error, message}`.
공통 헤더 (HMAC): `X-Timestamp`, `X-Signature`, `X-Source-Host`.

### 3.1 `POST /api/upload.php`
- 헤더: `X-Admin-Token`
- body: multipart `file`
- 처리: TOKEN 검증 → safeBasename → finfo MIME → size guard → move_uploaded_file → sha256_file → DB INSERT(synced_at=NULL) → pushToPeer → audit OUT
- 실패: 400/401/413/502

### 3.2 `POST /api/receive.php` (JSON wrapper 방식)
```
Content-Type: application/json
Body: {"original_name":"x.png","sha256":"...","source_host":"bluesquare.kr","content_b64":"..."}
```
검증 순서 (`guard.php::validateInbound`):
1. IP 화이트리스트 (옵션) → 403 `ip_not_allowed`
2. timestamp ±300초 → 401 `stale_timestamp`
3. HMAC `hash_equals` → 401 `bad_signature`
4. JSON 파싱 + 필드 검증
5. `original_name` basename + 정규식 `/^[A-Za-z0-9._-]{1,200}$/` → 400 `invalid_filename`
6. base64 decode → 임시파일 → finfo MIME → 화이트리스트
7. content sha256 vs meta sha256 → 400 `content_hash_mismatch`
8. size guard (`MAX_UPLOAD_BYTES`)
9. `realpath()` prefix 검증 (storage 외부 차단)
10. INSERT IGNORE (UNIQUE 충돌 시 `data.duplicate=true`)
11. audit IN
12. 200 + `{id}`

base64 100MB → ~133MB. `php://temp` 스트리밍으로 메모리 회피.

### 3.3 `GET /api/list.php`
`?limit=50&offset=0&source_host=`. HMAC 또는 TOKEN. 외부 비인증 노출 X.

### 3.4 `GET /api/file.php?id=N`
200 + meta 또는 404.

### 3.5 `PUT /api/file.php`
JSON `{id, original_name?}`. `?propagate=1` 옵션 시 peer UPDATE.

### 3.6 `DELETE /api/file.php`
JSON `{id}`. unlink + DB DELETE. `?propagate=1` 시 peer DELETE.

### 3.7 `GET /whoami.php` (인증 불필요)
```json
{"ok":true,"data":{
  "host":"bluesquare.kr","php_version":"7.4.x",
  "peer_url":"https://www.noltheater-daehakro.com/cors-test",
  "peer_reachable":true,"peer_response_ms":142,
  "server_time_unix":1761552000,
  "secret_fingerprint":"ab12cd34"
}}
```
`secret_fingerprint = substr(sha256(SYNC_SECRET), 0, 8)`. 시크릿 자체 노출 X.

---

## 4. HMAC 서명 명세

### 4.1 Canonical
```
canonical = X-Timestamp + "\n" +
            UPPER(method) + "\n" +
            request_path_with_query + "\n" +
            lowercase_hex(sha256(raw_body))
```
- `\n` = LF (0x0A) 단일
- 빈 body: `sha256("")`= `e3b0c44...b855`

### 4.2 PHP
```php
function sign(string $secret, string $ts, string $method, string $path, string $body): string {
    $bodyHash = hash('sha256', $body);
    $canonical = $ts . "\n" . strtoupper($method) . "\n" . $path . "\n" . $bodyHash;
    return hash_hmac('sha256', $canonical, $secret);
}
function verify(string $secret, array $h, string $method, string $path, string $body): array {
    $ts = $h['X-Timestamp'] ?? null; $sig = $h['X-Signature'] ?? null;
    if (!$ts || !$sig) return ['ok'=>false,'error'=>'missing_auth'];
    if (!ctype_digit((string)$ts)) return ['ok'=>false,'error'=>'bad_ts_format'];
    if (abs(time()-(int)$ts) > 300) return ['ok'=>false,'error'=>'stale_timestamp'];
    if (!hash_equals(sign($secret,$ts,$method,$path,$body), $sig))
        return ['ok'=>false,'error'=>'bad_signature'];
    return ['ok'=>true];
}
```

### 4.3 SECRET
```bash
openssl rand -hex 32   # 64자 hex (256-bit)
```
양쪽 호스팅 동일. 변경 시 두 호스팅 동시 배포.

---

## 5. CORS / 외부 차단 검증 (`tests/05_cors_browser.html`)

```html
<!DOCTYPE html><html><body>
<h1>External-origin CORS test</h1>
<button id="a">Call bluesquare</button>
<button id="b">Call noltheater</button>
<pre id="r"></pre>
<script>
async function call(u){
  try{
    const resp = await fetch(u,{method:'GET',credentials:'omit'});
    r.textContent = 'UNEXPECTED OK '+resp.status+': '+(await resp.text());
  }catch(e){ r.textContent = 'BLOCKED (expected): '+e.message; }
}
a.onclick=()=>call('https://bluesquare.kr/cors-test/api/list.php');
b.onclick=()=>call('https://www.noltheater-daehakro.com/cors-test/api/list.php');
</script></body></html>
```

서버 측: `Access-Control-Allow-Origin` 절대 출력 X. `OPTIONS` → 405. → 브라우저 `Failed to fetch` 차단해야 정상.

---

## 6. 자동화 테스트 + 자동 검증

### 6.1 `_common.sh` (공통 헬퍼)
```bash
export BASE_A="https://bluesquare.kr/cors-test"
export BASE_B="https://www.noltheater-daehakro.com/cors-test"
export SECRET="<64-hex>"
export ADMIN_TOKEN_A="..." ADMIN_TOKEN_B="..."

sign() {  # ts method path body_file
  local h=$(openssl dgst -sha256 -hex < "$4" | awk '{print $2}')
  printf '%s\n%s\n%s\n%s' "$1" "$2" "$3" "$h" \
    | openssl dgst -sha256 -hmac "$SECRET" -hex | awk '{print $2}'
}

# assert helpers
PASS=0; FAIL=0
assert_eq() {  # expected actual label
  if [ "$1" = "$2" ]; then echo "  PASS $3"; PASS=$((PASS+1));
  else echo "  FAIL $3 expected=$1 actual=$2"; FAIL=$((FAIL+1)); fi
}
assert_status() {  # url expected_code label [extra curl args...]
  local u="$1" exp="$2" lbl="$3"; shift 3
  local got=$(curl -sS -o /tmp/_out -w '%{http_code}' "$@" "$u")
  assert_eq "$exp" "$got" "$lbl"
}
summary() {
  echo "=========================================="
  echo " PASS=$PASS  FAIL=$FAIL"
  [ $FAIL -eq 0 ] && exit 0 || exit 1
}
```

### 6.2 `00_preflight.sh` (운영 영향 0 사전 점검)
```bash
. ./_common.sh
echo "[preflight]"
# 1. cors-test 경로 충돌 (404 기대 — 이미 존재하면 STOP)
assert_status "$BASE_A/whoami.php" 404 "A: /cors-test absent before deploy"
assert_status "$BASE_B/whoami.php" 404 "B: /cors-test absent before deploy"
# 2. 운영 핵심 페이지 baseline 캡처
while IFS= read -r u; do
  curl -sS -o "/tmp/baseline_$(echo $u|md5sum|cut -c1-8).html" -w "$u %{http_code} %{time_total}\n" "$u"
done < fixtures/baseline_urls.txt | tee /tmp/baseline.txt
echo "Baseline saved to /tmp/baseline.txt"
summary
```

### 6.3 `99_postcheck.sh` (배포 후 회귀 검증)
```bash
. ./_common.sh
echo "[postcheck]"
# 운영 핵심 페이지 응답 동일성 확인
while IFS= read -r u; do
  hash=$(echo $u|md5sum|cut -c1-8)
  before=$(stat -c %s "/tmp/baseline_$hash.html" 2>/dev/null || echo 0)
  curl -sS -o /tmp/after.html -w "%{http_code}" "$u" > /tmp/after_status
  after=$(stat -c %s /tmp/after.html)
  code=$(cat /tmp/after_status)
  # ±5% 차이까지 허용 (동적 페이지 변동)
  diff=$(awk -v b=$before -v a=$after 'BEGIN{print (b==0)?0:(a-b)*100/b}')
  echo "$u code=$code size_diff=${diff}%"
  assert_eq 200 "$code" "$u still 200"
done < fixtures/baseline_urls.txt
summary
```

### 6.4 `reset.sh` (테스트 사이 cleanup)
```bash
. ./_common.sh
# cors-test 파일/로그/DB만 정리. 운영 데이터 0 영향.
curl -sS -X DELETE "$BASE_A/api/file.php" -H "X-Admin-Token: $ADMIN_TOKEN_A" -d '{"all":true,"confirm":"RESET"}'
curl -sS -X DELETE "$BASE_B/api/file.php" -H "X-Admin-Token: $ADMIN_TOKEN_B" -d '{"all":true,"confirm":"RESET"}'
echo "reset done"
```
> `confirm:"RESET"` 가드: file.php에 `?all=1&confirm=RESET` + ADMIN_TOKEN 시에만 자기 storage/cors_test_files 전부 비움. 운영 테이블 절대 안 건드림 (테이블명 하드코딩).

### 6.5 7가지 테스트 시나리오 + 자동 assert

각 스크립트는 **status 코드 + sync_log 행 + 부수효과** 3중 검증.

| # | 스크립트 | 트리거 | 기대 | 부수효과 검증 |
|---|---|---|---|---|
| 1 | `01_normal_upload.sh` | A→B 정상 push | upload 200, peer 200 | B의 list에 sha256 일치 row 존재, source_host=bluesquare.kr |
| 2 | `02_normal_upload_reverse.sh` | B→A 정상 | 200/200 | A list에 도착, source_host=noltheater 표시 |
| 3 | `03_bad_signature.sh` | 위조 X-Signature | 401 `bad_signature` | sync_log IN row ok=0, signature_hash 기록, **storage에 파일 미생성** |
| 4 | `04_replay_old_ts.sh` | 6분 전 TS + 정상 sig | 401 `stale_timestamp` | 동일 |
| 5 | `05_path_traversal.sh` | original_name=`../../etc/passwd` | 400 `invalid_filename` | `find storage/ -name passwd -o -name etc` 비어있음 |
| 6 | `06_oversized.sh` | 110MB | 413 (또는 post_max_size 차단 400) | storage에 110MB 파일 미존재 (`du -sh storage`) |
| 7 | `07_wrong_ip.sh` | 화이트리스트 외 IP에서 정상 HMAC | 403 `ip_not_allowed` | 동일 |

각 스크립트 끝에 자동 진단 (실패 시):
```bash
if [ $FAIL -gt 0 ]; then
  echo "--- error.log tail ---"
  curl -sS "$BASE_B/api/whoami.php?dump_err=1" -H "X-Admin-Token: $ADMIN_TOKEN_B"
  echo "--- sync_log last 5 ---"
  curl -sS "$BASE_B/api/list.php?log=1&limit=5" -H "X-Admin-Token: $ADMIN_TOKEN_B"
fi
```

### 6.6 `run_all_tests.sh`
```bash
#!/bin/bash
. ./_common.sh
set -e
echo "=== Phase 0: preflight ==="
bash 00_preflight.sh
echo "=== Phase 1: positive ==="
bash 01_normal_upload.sh
bash 02_normal_upload_reverse.sh
echo "=== Phase 2: negative ==="
bash 03_bad_signature.sh
bash 04_replay_old_ts.sh
bash 05_path_traversal.sh
bash 06_oversized.sh
[ -n "$ENABLE_IP_TEST" ] && bash 07_wrong_ip.sh
echo "=== Phase 3: postcheck (운영 회귀) ==="
bash 99_postcheck.sh
echo "=== Phase 4: cleanup ==="
bash reset.sh
echo "ALL DONE"
```

`07_wrong_ip.sh`는 IP 화이트리스트 활성화한 환경에서만 (`ENABLE_IP_TEST=1` env로 토글).

---

## 7. 설정 파일

### `config.php` (양쪽 동일)
- `config.local.php` require_once (없으면 fatal)
- 공통 상수: `MAX_UPLOAD_BYTES=104857600`, `ALLOWED_MIME=['image/jpeg','image/png','image/gif','image/webp','application/pdf']`, `ALLOWED_FILENAME_REGEX='/^[A-Za-z0-9._-]{1,200}$/'`, `TIMESTAMP_SKEW_SEC=300`
- 디렉토리: `STORAGE_DIR=__DIR__.'/storage'`, `LOGS_DIR=__DIR__.'/logs'`

### `config.local.php` (호스팅별, gitignore)
```php
<?php
define('THIS_HOST',     'bluesquare.kr');
define('PEER_BASE_URL', 'https://www.noltheater-daehakro.com/cors-test');
define('SYNC_SECRET',   '<64-hex, 양쪽 동일>');
define('ADMIN_TOKEN',   '<32+ chars>');
define('ALLOWED_PEER_IPS', []);     // 빈 배열이면 IP 검증 skip
define('DB_HOST', '...'); define('DB_NAME', '...');
define('DB_USER', 'cors_test_user'); define('DB_PASS', '...');
define('ROLE', 'BOTH');
define('KILL_SWITCH', false);       // true면 즉시 503
```

### `.htaccess` (cors-test 루트)
```apache
<Files "config.local.php">
  Require all denied
</Files>
<FilesMatch "\.(log|sql|md|sh|example)$">
  Require all denied
</FilesMatch>
Options -Indexes
Header set X-Robots-Tag "noindex, nofollow"
```

`storage/.htaccess`, `logs/.htaccess`:
```apache
Require all denied
RemoveHandler .php .phtml
php_flag engine off
```

---

## 8. 운영 단계 전환 시 변경점

코드 변경 없음. `config.local.php` 수정만:

| 항목 | bluesquare.kr (USER) | bluesquare-admin.* (ADMIN, 신설) |
|---|---|---|
| `ROLE` | `USER` | `ADMIN` |
| `PEER_BASE_URL` | (admin 호스팅) | `https://bluesquare.kr/cors-test` |
| `ALLOWED_PEER_IPS` | `[<admin outbound IP>]` | `[]` |
| 활성 엔드포인트 | `receive.php`, `list.php`, `file.php` GET | `upload.php`, `file.php` PUT/DELETE |

**ADMIN 도메인 권장**: 별도 eTLD+1 신규 (`bsq-console.net` 등). 같은 eTLD+1 서브도메인은 쿠키 격리 약함.

---

## 9. 보안 체크리스트

1. HTTPS only. cURL `CURLOPT_SSL_VERIFYPEER=true`, `VERIFYHOST=2`.
2. `storage/`, `logs/` 직접 접근 차단 + .php 실행 차단.
3. SECRET git 제외, .htaccess deny, 권한 600.
4. DB user 권한 분리 (cors_test_user, 두 테이블만).
5. SECRET 256-bit, `openssl rand -hex 32`로만 생성.
6. Path traversal 다층: `basename()` + 정규식 + `realpath()` prefix 검증.
7. MIME finfo 검증, 확장자 별도 화이트리스트.
8. 모든 시크릿 비교 `hash_equals()`.
9. 외부 응답 에러 코드만, 상세는 `error_log()`.
10. 재귀 push 방지: receive 경로는 push 호출 X.

추가:
- 로그에 SECRET/full-signature 평문 금지 (앞 16자만).
- `OPTIONS` 메소드 명시적 405.
- (선택) sync_log 활용 rate limit (IP당 1분 N회 초과 → 429).

---

## 10. 단계별 롤아웃 (Phased Rollout) ★테스트 프로세스 핵심★

각 Phase 사이에 **운영 트래픽/응답 모니터링** 후 다음 진행. 문제 시 직전 Phase로 즉시 롤백.

### Phase A — 사전 준비 (양쪽 호스팅 영향 0)

**목표**: 코드 0줄 배포. 환경/권한/baseline 만 확보.

A1. baseline 캡처 (로컬에서):
```bash
# fixtures/baseline_urls.txt 작성 — 양쪽 호스팅 핵심 페이지 10~20개
# 예: https://bluesquare.kr/, https://bluesquare.kr/category, ...
bash tests/00_preflight.sh
# /tmp/baseline.txt 와 baseline_*.html 저장됨
```

A2. 호스팅 패널 정보 수집:
- 디스크 여유 ≥ 5GB 확인
- PHP 버전 (7.4.x), `post_max_size`, `upload_max_filesize`, `memory_limit` 메모
- DB user 새로 만들 수 있는지, DDL 권한 있는지

A3. **운영팀/이해관계자 공지** (배포 시간, 영향 없음 보장 내용, 비상 차단 절차).

A4. SECRET 생성:
```bash
openssl rand -hex 32   # 양쪽 호스팅 config.local.php에 동일 값
openssl rand -hex 16   # ADMIN_TOKEN_A
openssl rand -hex 16   # ADMIN_TOKEN_B
```
패스워드 매니저 또는 `D:\.claude\projects\d-----------------260427\memory\` 외 안전한 곳에 보관.

### Phase B — KILL_SWITCH ON 상태로 코드 배포

**목표**: 코드는 올라가지만 모든 요청 즉시 503. 외부 영향 0 검증.

B1. `config.local.php` 작성 (KILL_SWITCH=true).

B2. cors-test 디렉토리 통째로 양쪽 호스팅 업로드 (FTP/SFTP):
```
/cors-test/
├── config.php, config.local.php, .htaccess, robots.txt
├── lib/, api/, ui/, storage/(빈), logs/(빈)
└── tests/는 로컬에만 보관 (호스팅 업로드 X)
```

B3. 외부에서 헬스체크:
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://bluesquare.kr/cors-test/whoami.php
# 기대: 503 (KILL_SWITCH)
curl -s -o /dev/null -w "%{http_code}\n" https://bluesquare.kr/cors-test/api/upload.php
# 기대: 503
```

B4. **운영 페이지 회귀 검증**:
```bash
bash tests/99_postcheck.sh   # baseline_urls 전부 200 + size 비교
```
실패 시 즉시 Phase B 전체 롤백 (`/cors-test/` 디렉토리 삭제).

B5. 24시간 모니터링 (트래픽/에러로그/디스크). 이상 없으면 Phase C.

### Phase C — DB 스키마 생성

C1. 양쪽 호스팅 phpMyAdmin 또는 SSH:
```sql
SHOW TABLES LIKE 'cors\_test\_%';   -- 비어있어야 함 (충돌 확인)
SOURCE tests/fixtures/schema.sql;   -- 또는 GUI 임포트
SHOW TABLES LIKE 'cors\_test\_%';   -- cors_test_files, cors_test_sync_log 두 개 확인
```

C2. DB user 별도 생성 (가능 시). config.local.php 업데이트.

C3. 운영 테이블 변화 0 확인:
```sql
-- 사전에 메모해둔 운영 핵심 테이블 5개 COUNT 비교
SELECT COUNT(*) FROM <prod_table_1>;  -- 변화 없어야 함
```

### Phase D — KILL_SWITCH OFF + 헬스체크

D1. `config.local.php`의 `KILL_SWITCH=false`로 토글 (양쪽).

D2. 외부 헬스체크:
```bash
curl -sS https://bluesquare.kr/cors-test/whoami.php | jq
# 기대: ok:true, peer_reachable:true
curl -sS https://www.noltheater-daehakro.com/cors-test/whoami.php | jq
```

D3. **secret_fingerprint 양쪽 동일 확인** (다르면 SECRET 불일치 → 즉시 KILL_SWITCH 다시 ON).

D4. 운영 회귀 재검증:
```bash
bash tests/99_postcheck.sh
```

### Phase E — 정상 시나리오 (테스트 1, 2)

E1. `bash tests/01_normal_upload.sh` → A 업로드, B 도착.
E2. `bash tests/02_normal_upload_reverse.sh` → 반대.
E3. `cors_test_sync_log` 검토 (양쪽).
E4. **운영 응답시간 영향 모니터링** (cors-test 호출 중 운영 페이지 TTFB 평균 +20% 이내).

### Phase F — 부정 시나리오 (테스트 3~6)

F1. `bash tests/03_bad_signature.sh` → 401 + sync_log IN ok=0
F2. `bash tests/04_replay_old_ts.sh` → 401 stale
F3. `bash tests/05_path_traversal.sh` → 400 + storage clean
F4. `bash tests/06_oversized.sh` → 413 + storage clean

각 테스트 후 `reset.sh`로 잔여 정리.

### Phase G — IP 화이트리스트 (옵션)

G1. noltheater `config.local.php`에 `ALLOWED_PEER_IPS=['<bluesquare outbound IP>']` 추가.
G2. `whoami.php`로 bluesquare outbound IP 확인 (`peer_reachable` 응답 + 호스팅이 logging해주면 logs에서).
G3. `bash tests/07_wrong_ip.sh` (다른 IP에서) → 403.
G4. 정상 케이스 재실행 → 200 유지.
G5. 운영 단계까지 활성 유지 권장.

### Phase H — CORS 브라우저 검증

H1. 로컬 PC에서 `tests/05_cors_browser.html` file:// 열기.
H2. 두 버튼 클릭 → 콘솔 `Failed to fetch`. 페이지에 응답 미표시.

### Phase I — 최종 회귀 검증 + 보고

I1. `bash tests/99_postcheck.sh` (운영 baseline 변화 없음).
I2. PASS/FAIL 집계 보고 (`run_all_tests.sh` 결과).
I3. 호스팅 패널에서 24시간 트래픽/에러 그래프 캡처.

### Phase J — 정리 (또는 운영 전환)

**옵션 1 — 테스트 종료 후 제거**:
```bash
# 양쪽 호스팅
rm -rf /cors-test/
# DB
DROP TABLE cors_test_files, cors_test_sync_log;
DROP USER 'cors_test_user'@'%';
```

**옵션 2 — 운영 전환**:
- 8장 표대로 `config.local.php`만 수정
- ADMIN 호스팅 신설 후 동일 코드 배포
- 운영 사이트는 `ROLE='USER'`로 전환

---

## 11. 비상 차단 / 롤백 절차

| Level | 트리거 | 조치 | 소요 |
|---|---|---|---|
| L1 (Soft) | 응답시간 +20% 또는 sync_log 비정상 폭증 | `config.local.php`에 `KILL_SWITCH=true` 토글 → 1초 내 모든 cors-test 503 | ~10초 (FTP) |
| L2 (Block) | KILL_SWITCH 미반응 또는 직접 차단 | `/cors-test/.htaccess`에 `Require all denied` 한 줄 추가 → 즉시 403 | ~30초 |
| L3 (Remove) | 코드 자체 문제 의심 | `/cors-test/` 디렉토리 통째 삭제 | ~1분 |
| L4 (DB) | 스키마/데이터 이상 | `DROP TABLE cors_test_*` | ~10초 |

**모든 Level은 운영 코드 영향 0**. cors-test는 외부 require가 없으므로 디렉토리/테이블 제거가 운영에 미치는 영향은 0.

---

## 12. 모니터링 체크리스트 (배포 직후 ~ 24h)

운영 서비스 영향을 확인할 핵심 지표:

- [ ] 핵심 페이지 응답코드 (`baseline_urls.txt` 전부) — 5분 간격 curl
- [ ] 응답시간 (TTFB) — 평균 +20% 초과 시 L1 차단
- [ ] 호스팅 패널 CPU/메모리/디스크 그래프
- [ ] PHP error_log 새 에러 (cors-test 외 path)
- [ ] `cors_test_sync_log` 비정상 IP/실패 패턴
- [ ] storage/ 디스크 사용량 (5GB 초과 시 reset)
- [ ] 운영 DB 핵심 테이블 row count 변화 (0이어야 함)
- [ ] 외부 검색엔진 색인 (`site:bluesquare.kr cors-test` 0건이어야 함)

24h 통과 후 정상 운영으로 간주.

---

## Critical Files (구현 순서)

신규 작성 (모두 `/cors-test/` 하위):
1. `config.php` — dispatcher, 공통 상수
2. `config.local.php.example` — 템플릿
3. `.htaccess`, `robots.txt`
4. `lib/bootstrap.php` — KILL_SWITCH 체크, X-Robots-Tag, 에러핸들러
5. `lib/db.php` — PDO 싱글톤
6. `lib/http.php` — respondJson, readRawBody
7. `lib/hmac.php` — **HMAC single source of truth**
8. `lib/upload.php` — basename, finfo, sha256
9. `lib/peer.php` — pushToPeer + cURL
10. `lib/audit.php` — sync_log 기록
11. `lib/guard.php` — **inbound 검증 게이트, 보안 핵심**
12. `api/whoami.php` — Phase B 단독 배포 가능
13. `api/receive.php` — **inbound 흐름 종합**
14. `api/upload.php` — outbound + 로컬 admin
15. `api/list.php`, `api/file.php`
16. `ui/upload-form.html`, `ui/dashboard.php`
17. `storage/.htaccess`, `logs/.htaccess`
18. `tests/fixtures/schema.sql`, `tests/fixtures/baseline_urls.txt`, `tests/fixtures/small.png`
19. `tests/_common.sh`, `tests/00_preflight.sh`, `tests/99_postcheck.sh`, `tests/reset.sh`, `tests/run_all_tests.sh`
20. `tests/01~07_*.sh`, `tests/05_cors_browser.html`

참고 (직접 require 안 함, 패턴 차용):
- `inc/lib/db.php` — PDO 싱글톤 패턴
- `app/api.php` — `respondJson` 패턴
- `inc/lib/func.php` — `uploadImage` (finfo + basename + sha256 강화하여 재작성)

---

## 부록: pushToPeer

```php
// lib/peer.php
function pushToPeer(string $method, string $path, array $payload): array {
    $rawBody = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $ts  = (string)time();
    $sig = sign(SYNC_SECRET, $ts, $method, $path, $rawBody);
    $url = PEER_BASE_URL . $path;

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_POSTFIELDS     => $rawBody,
        CURLOPT_HTTPHEADER     => [
            'Content-Type: application/json',
            "X-Timestamp: $ts",
            "X-Signature: $sig",
            'X-Source-Host: ' . THIS_HOST,
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 30,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $body   = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    logSync('OUT', actionFromPath($path), substr($sig, 0, 16), null, $url, $status, substr((string)$body, 0, 1024), $status >= 200 && $status < 300);
    return ['status' => $status, 'body' => $body, 'ok' => $status >= 200 && $status < 300];
}
```
