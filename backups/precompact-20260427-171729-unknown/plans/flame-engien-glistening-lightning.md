# Plan: Rocket Draco 재압축 + 캐싱 + Flame Billboard 정리

## Context

1. 유저가 Blender에서 로켓 모델을 "Apply All Transforms"(위치·크기·회전 초기화) 상태로 수정함
   → 새 GLB(v=3)의 로컬 좌표계: **+Y = 위쪽, −Y = 추력 방향** (Three.js Y-up 일치)
2. 새 GLB를 Draco 재압축 필요
3. 캐시 버스팅 버전 업
4. 이 좌표계 기준으로 flame이 항상 화면 정면을 보도록(axial billboard) 확인/수정
5. 불필요한 로직 제거

---

## Step 1 — Draco 재압축

**명령**: `npm run compress:rocket`
(package.json에 이미 정의: `npx gltf-transform optimize resource/models/rocket.glb resource/models/rocket_draco.glb --compress draco`)

→ `resource/models/rocket_draco.glb` 덮어씀

---

## Step 2 — 캐시 버전 업

**파일**: `resource/ts/config/object.config.ts`

```
modelUrl: "/resource/models/rocket_draco.glb?v=3"
         →
modelUrl: "/resource/models/rocket_draco.glb?v=4"
```

---

## Step 3 — Flame Axial Billboard 확인

**현재 구현** (`resource/ts/objects/rocket/JetEngine.ts`):

```typescript
private _axialBillboard(root, camera) {
  // rocket parent 로컬 공간에서 camera 방향 계산
  // Y 성분 제거 (thrust 축 = Y)
  // atan2(x, z) 로 Y축 회전각 산출
  root.quaternion.setFromAxisAngle(_THRUST_AXIS, angle);
}
```

Blender Apply All Transforms → GLTF Y-up 변환 → Three.js 로드 시
`rocket.localY = 세계 위쪽`, `thrust = −Y`  
→ **billboard 축 Y = (0,1,0) 가정 정확. 코드 수정 불필요.**

**`runUpdate` 첫 줄에 `_axialBillboard(root, camera)` 호출 중** ✓

---

## Step 4 — 불필요한 로직 제거

`runObject` 내부 (`resource/ts/objects/rocket/JetEngine.ts`):

```typescript
// 제거 대상
Helpers.applyRotationDeg(root, r);  // r = {x:0,y:0,z:0} → 항상 no-op
```

`object.config.ts` jetEngine 섹션:
```typescript
// 제거 대상
rotation: { x: 0, y: 0, z: 0 },  // 의미 없는 기본값
```

JetEngine 타입 정의에서 rotation이 optional이면 설정 항목만 삭제 (기본값으로 처리됨).
rotation이 required면 값만 남기고 코드 라인은 유지.

---

## Critical Files

- `resource/ts/config/object.config.ts` — modelUrl 버전 업, jetEngine rotation 항목 제거
- `resource/ts/objects/rocket/JetEngine.ts` — `Helpers.applyRotationDeg` 라인 제거
- (압축 결과) `resource/models/rocket_draco.glb` — 재생성

## Verification

1. `npm run compress:rocket` 성공 로그 확인
2. `rtk tsc --noEmit` — 오류 없음
3. `http://localhost:8888` — 로켓 상승 시 flame이 로켓 방향을 따르면서 항상 카메라 정면을 향하는지 확인
