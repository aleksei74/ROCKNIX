# SDOJ Recomp SM8550 검은 화면 조사 기록 (테스트 112까지)

작성 시점: 2026-07-23 (KST)

## 1. 목표와 환경

- 대상: ROCKNIX SM8550 / Adreno 740 / Turnip Vulkan
- 증상: 게임은 실행되고 소리가 나오지만 화면이 검정 또는 진단용 분홍색으로 표시됨
- SDK 소스:
  `/home/aleksei/ROCKNIX/build.ROCKNIX-SM8550.aarch64/build/sdoj-recomp-sa-main/thirdparty/rexglue-sdk`
- 빌드 디렉터리:
  `/home/aleksei/ROCKNIX/build.ROCKNIX-SM8550.aarch64/build/sdoj-recomp-sa-main/.aarch64-rocknix-linux-gnu`
- 결과 라이브러리:
  `/home/aleksei/ROCKNIX/build.ROCKNIX-SM8550.aarch64/build/sdoj-recomp-sa-main/thirdparty/rexglue-sdk/out/linux-arm64/librexruntime.so`
- 기기 배포 위치: `/storage/roms/ports/sdoj/librexruntime.so`
- 기기 로그: `/storage/roms/ports/sdoj/logs/`
- 기기 사용자 데이터: `/storage/.config/sdoj-recomp`
- 셰이더 캐시:
  `/storage/.config/sdoj-recomp/cache/shaders/shareable/`

중요: 결과물을 `/usr/bin`이나 `/usr/lib`에 설치하지 않는다. `librexruntime.so`만 게임 폴더인 `/storage/roms/ports/sdoj/`에 복사한다.

## 2. 빌드 명령

```bash
PATH="/home/aleksei/ROCKNIX/build.ROCKNIX-SM8550.aarch64/toolchain/bin:$PATH" \
  ninja -C /home/aleksei/ROCKNIX/build.ROCKNIX-SM8550.aarch64/build/sdoj-recomp-sa-main/.aarch64-rocknix-linux-gnu \
  -j$(nproc)
```

기기 접속 정보:

```text
ssh root@192.168.1.9
password: linux
```

## 3. 실행 인자

사용자가 기기 런처에 적용한 주요 인자:

```bash
ARGS=(
  "--game_data_root=${GAME_DATA}"
  "--user_data_root=${CONF_DIR}"
  "--cache_path=${CONF_DIR}/cache"
  "--vulkan_readback_resolve=true"
  "--vulkan_readback_memexport=true"
  "--vulkan_async_skip_incomplete_frames=false"
  "--vsync=false"
  "--render_target_path_vulkan=fbo"
  "--fullscreen"
)
```

## 4. 지금까지 확정된 렌더링 경로

진단 결과를 종합하면 다음 경로는 정상 동작한다.

1. Vulkan WSI와 최종 present
2. presenter의 source texture sampling
3. resolve destination에서 presentation texture까지의 경로
4. EDRAM descriptor 및 resolve compute
5. graphics pipeline 생성
6. vertex/fragment shader 실행, rasterization, pixel output
7. fetch constant를 이용한 vertex 주소 계산

문제가 확인된 지점은 vertex shader가 shared-memory SSBO에서 실제 vertex 데이터를 읽는 부분이다. 계산된 주소는 0이 아니지만 `LoadUint32FromSharedMemory`를 거친 vfetch 결과가 0으로 관찰된다.

## 5. 주요 테스트 결과

### Present, resolve, EDRAM 분리

- 최종 present를 분홍색으로 강제: 분홍색 표시. WSI/present 정상.
- presenter source texture를 분홍색으로 강제: 분홍색 표시. sampling/view 정상.
- gamma 경로를 우회: 검은 화면 지속. gamma가 근본 원인은 아님.
- 92: 완료된 resolve destination을 분홍색으로 강제 → 분홍/소리.
  - shared-memory resolve destination → texture → present 경로 정상.
- 93: resolve 직전 EDRAM buffer를 분홍색으로 강제 → 분홍/소리.
  - EDRAM descriptor와 resolve compute 정상.

### Draw와 vertex position 분리

- 94, 95: pixel output을 분홍색으로 강제했지만 검정/소리.
- 97: host에서 fullscreen triangle vertex position을 생성하고 pixel을 분홍색으로 강제 → 분홍/소리.
  - draw, pipeline, rasterization, fragment output은 정상.
  - 원래 guest vertex position이 잘못되었음을 확인.
- 98: float multiply의 signed-zero 처리를 정수 비트 비교 방식으로 변경 → 검정/소리.
- 99: guest position XYZ를 사용하되 W/NDC 변환을 우회 → 검정/소리.
  - W/NDC 후처리가 아니라 guest oPos 자체가 잘못됨.
- 100: vertex buffer를 매번 invalidate/reupload → 검정/소리.
- 101: 실제 shader dump 수집 → 검정/소리.
- 102: `shaderSignedZeroInfNanPreserveFloat32` 의미 처리는 허용하되 명시적 SPIR-V capability/execution mode는 억제 → 검정/소리.
- 103: VS float constants를 draw마다 다시 업로드 → 검정/소리.
- 104: vfetch가 쓴 것으로 추정한 register를 guest ALU 이후 읽음 → 검정/소리.
  - 해당 register가 ALU에서 덮였을 수 있어 결정적이지 않았음.

### vfetch 직후 캡처

- 105/106: vfetch 직후 값을 별도 function variable에 캡처하는 진단을 만들었으나 기존 Vulkan pipeline cache 15개가 재사용되어 새 shader가 적용되지 않음.
- 107: 캐시 백업 후 새 pipeline 생성 확인, vfetch 직후 값 검사 → 검정/소리.
  - 선택한 position vfetch 결과가 0으로 보임.
- 108: vfetch 데이터 대신 계산된 dword 주소를 검사 → 분홍/소리.
  - fetch constant와 주소 계산은 정상.
- 109: 4개 descriptor 선택용 `switch + OpPhi`를 우회하고 descriptor array element 0을 직접 읽음 → 검정/소리.
  - 단순 switch/phi 문제는 아님.
- 110: 첫 draw에서 shared-memory binding 0의 128MB를 GPU `vkCmdFillBuffer(0x3F800000)`로 채움 → 검정/소리.
- Mesa를 26.2.0-rc1에서 26.1.2로 변경.
- 111: Mesa 26.1.2에서 동일한 110 라이브러리와 새 cache로 실행 → 검정/소리.
  - Mesa 26.2.0-rc1만의 회귀는 아님.
- 112: SSBO descriptor array를 제거하고 첫 128MB를 평범한 단일 `binding 0, descriptorCount=1` SSBO로 선언 → 검정/소리.

## 6. Mesa 비교 결과

기기에서 확인한 Mesa 26.1.2 정보:

```text
apiVersion = 1.4.348
deviceName = Turnip Adreno (TM) 740
driverName = turnip Mesa driver
driverInfo = Mesa 26.1.2
```

Mesa 26.2.0-rc1과 26.1.2에서 증상이 동일하므로 단순 Mesa 버전 원복만으로 해결되지는 않았다.

## 7. Shader dump에서 확인한 VS

테스트 101 dump는 `/tmp/sdoj-shaders101`에 복사해 두었다.

- `2EF78F7D2D666746`: 첫 full vfetch가 r2에 position을 기록.
- `7F4DB3BE01F6A567`: full fetch 뒤 mini fetch가 r2에 position을 기록.
- `8692E68A72AEEC16`: full vf0가 r5에 position을 기록하며 이후 ALU가 r5를 수정.
- `B771BD7FAC3539E5`: 첫 full vfetch가 r1에 position을 기록.
- `E523B07B4311E783`, `683...`: 대부분 cnop인 placeholder/memexport 계열로 추정.

## 8. 현재 소스에 남아 있는 진단 변경

현재 SDK 소스는 깨끗한 최종 수정본이 아니라 여러 진단 변경이 누적된 상태다.

### `spirv_translator.h/.cpp`

- `var_main_diagnostic_vfetch_` function variable 추가.
- 알려진 SDOJ vertex shader hash에 대해 vfetch 직후 값을 보존.
- 보존된 값의 raw bit가 하나라도 0이 아니면 테스트 97에서 검증된 fullscreen triangle position을 출력.
- 테스트 112를 위해 shared memory를 descriptor array가 아닌 단일 SSBO로 임시 선언.
- 테스트 109/112를 위해 `LoadUint32FromSharedMemory`와 `StoreUint32ToSharedMemory`의 binding count를 임시로 0 처리.
- 원래 4분할 descriptor용 switch/phi 코드는 아래쪽에 남아 있지만 현재 진단 return 때문에 load에서는 도달하지 않음.

### `spirv_translator_fetch.cpp`

- shader hash와 destination register를 기준으로 position-bearing vfetch를 선택.
- `StoreResult` 직후 register 전체를 `var_main_diagnostic_vfetch_`에 저장.

### `spirv_translator_rb.cpp`

- fragment output을 분홍색으로 강제하는 진단이 활성화되어 있음.

### `vulkan/command_processor.cpp`

- shared-memory/EDRAM descriptor layout에서 테스트 112용으로 shared-memory descriptor count를 1로 강제.
- descriptor write count도 1로 강제.
- 테스트 110용 static one-shot `vkCmdFillBuffer`가 남아 있음.
- 첫 draw에서 shared buffer 처음 128MB를 `0x3F800000`으로 채우고 transfer→shader barrier를 삽입.
- vertex/shared-memory 관련 추가 로그가 남아 있음.

### 기타 남은 변경

- `spirv_translator_alu.cpp`: multiply의 zero 처리를 float NMin 대신 bitcast와 정수 zero 비교로 변경.
- `vulkan_device.cpp`: Turnip에서 `shaderSignedZeroInfNanPreserveFloat32`를 강제로 false 처리하던 코드 제거.
- explicit SignedZeroInfNanPreserve SPIR-V capability/execution mode는 억제된 상태.
- `pipeline_cache.cpp`: shader dump hook이 있으며 기본 dump 경로는 빈 문자열.
- deferred command buffer에 `vkCmdFillBuffer` 지원을 추가한 상태.
- presenter에는 raw source/gamma 우회 진단이 남아 있음.

## 9. 캐시 주의사항

새 shader translator 진단을 만들 때 다음 두 파일을 그대로 두면 이전 pipeline이 로드되어 새 코드가 실행되지 않을 수 있다.

```text
/storage/.config/sdoj-recomp/cache/shaders/shareable/435A07E7.xsh
/storage/.config/sdoj-recomp/cache/shaders/shareable/435A07E7.fbo.vk.xpso
```

삭제 대신 다음과 같이 테스트 번호가 붙은 백업 이름으로 이동해 왔다.

```text
*.before107
*.before108
*.before109
*.before110
*.before111_mesa2612
*.before112
```

매번 새 라이브러리 테스트 전에 현재 `.xsh`와 `.xpso`를 다시 백업해야 한다.

## 10. 테스트 110/112의 한계

GPU fill은 `static bool`로 최초 draw에서 한 번만 실행된다. 최초 draw는 `E523...` placeholder pipeline일 수 있고 실제 SDOJ shader pipeline은 비동기로 나중에 생성된다. 그 사이 CPU→GPU upload나 submission 전환이 fill 패턴을 덮을 가능성이 있다.

따라서 110과 112의 검정 결과만으로 standalone SSBO descriptor 자체가 완전히 고장 났다고 최종 확정해서는 안 된다.

## 11. 다음 작업: 테스트 113

다음 테스트에서는 one-shot 128MB fill을 제거하고, 각 draw에서 사용되는 vertex fetch constant의 정확한 주소와 크기만 실제 draw 직전에 GPU fill해야 한다.

권장 절차:

1. `IssueDraw`의 vertex buffer `RequestRange` 루프에서 이번 draw가 쓰는 `(address << 2, size << 2)` 범위를 수집.
2. `RequestRange`가 upload 명령을 기록한 뒤, render pass 진입 직전에 해당 범위를 `vkCmdFillBuffer`로 nonzero 패턴으로 채움.
3. fill offset/size를 Vulkan 요구사항인 4바이트 배수로 정렬.
4. fill 전에 기존 read/write → transfer-write barrier, fill 뒤 transfer-write → vertex-shader-read barrier 삽입.
5. 캡처와 분홍 pixel 진단은 현재 상태로 유지.
6. 캐시를 `.before113`으로 이동한 뒤 새 pipeline을 생성.

해석:

- 113 분홍: SSBO descriptor/load는 정상. 원래 CPU→GPU vertex range upload 또는 dirty-page 추적/명령 순서 문제.
- 113 검정: 정확한 vfetch 주소를 draw 직전에 채워도 shader에서 0. descriptor layout/binding 또는 Turnip SSBO load/SPIR-V 생성 문제를 더 직접 조사.

113에서도 검정이면 다음 단계로 validation layer 또는 shader dump/disassembly를 이용해 standalone SSBO의 SPIR-V access chain과 pipeline layout binding을 비교한다. 필요하면 4개 descriptor array 대신 네 개의 독립 binding 변수(`binding 0..3`)를 정식으로 구현한다. 이 경우 EDRAM binding과 pipeline layout도 충돌하지 않게 함께 재배치해야 한다.

## 12. 마지막 빌드(112)

테스트 112 라이브러리:

```text
size: 17049264 bytes
SHA-256: c0628fb6fe56d7cc24e8e6404b358480b969e6daa3823262e8c089fb6269a9b1
```

테스트 결과: 검정/소리/112.

