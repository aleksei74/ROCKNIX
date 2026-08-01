# SDOJ Recomp (DoDonPachi Saidaioujou Recompiled) - ROCKNIX SM8550 이식 및 오류 수정 보고서

## 1. 개요 (Overview)
- **대상 기기 및 OS**: ROCKNIX OS / SM8550 (Snapdragon 8 Gen 2 / Adreno 740, ARM64)
- **그래픽 드라이버**: Mesa Turnip (Adreno 740, Vulkan 1.4 API)
- **패키지 위치**: `projects/ROCKNIX/packages/emulators/standalone/sdoj-recomp-sa/`

---

## 2. 발생한 주요 오류 및 원인 분석 (Issues & Root Causes)

### Issue 1. 공유 라이브러리(`*.so`) 설치 누락
- **현상**: 게임 실행 시 `librexruntime.so` 및 `libsaidaioujou_recomp_tu1_*.so` 동적 라이브러리를 찾을 수 없어 런타임 시작 실패.
- **원인**: `package.mk`의 `makeinstall_target()` 구문에서 패키지 빌드 후 링킹할 동적 라이브러리 복사 명령어(`cp -P *.so*`)가 누락됨.

### Issue 2. GTK / Vulkan 디스플레이 서페이스 생성 실패 (`GDK_BACKEND=wayland`)
- **현상**: 터미널 출력에 `GTKWindow: The window system of the GTK window is not supported by Xenia` 에러 출력 및 화면 불출력.
- **원인**: ReXGlue SDK의 Linux Windowing 시스템(`window_gtk.cpp`, `vulkan_presenter.cpp`)은 오직 **X11 (`VK_KHR_xcb_surface`)** 서페이스만 지원함. SSH 연결 실행 환경에서 `DISPLAY` 환경변수가 비어있어 GTK가 Wayland로 작동을 시도하며 `nullptr` 서페이스를 반환함.

### Issue 3. Mesa Turnip 드라이버 `fmadz` 셰이더 컴파일러 중단 (Crash)
- **현상**:
  ```text
  div 32 %632 = fmadz %181, %623, %690.y // exact, preserve:sz,inf,nan Unhandled ALU op: fmadz
  ```
- **원인**: ReXGlue `spirv_translator_alu.cpp`의 `ZeroIfAnyOperandIsZero()` 함수가 생성하는 SPIR-V `GLSLstd450NMin(abs(a), abs(b)) == 0` 구문을 Mesa NIR 대수 최적화 패스가 NIR `fmadz` 연산자로 병합함. Mesa Turnip(Adreno ir3) 드라이버에 `fmadz` 대응 코드가 없어 셰이더 컴파일 실패 및 abort 발생.

### Issue 4. 버텍스 셰이더 파이프라인 무한 대기 (검은 화면 멈춤)
- **현상**: `Creating graphics pipeline state with VS 2EF78F7D2D666746` 로그 출력 후 프로세스는 살아있으나 화면/사운드 응답 없음.
- **원인**: Mesa Turnip 드라이버에서 Vulkan 부동소수점 정밀도 유지 옵션인 `shaderSignedZeroInfNanPreserveFloat32` 활성화 시 특정 버텍스 셰이더 파이프라인 생성 시 백그라운드 스레드가 무한 대기(Stuck)에 빠짐.

### Issue 5. 유효하지 않은 SPIR-V 셰이더 연산자로 인한 렌더링 드롭
- **현상**: 프로그램 구동 후 사운드와 화면이 나오지 않고 검은 화면 지속.
- **원인**: `ZeroIfAnyOperandIsZero()` 우회 패치 중 임시로 적용했던 `GLSLstd450FClamp` 함수가 3개 인자를 요구함에도 2개 인자만 전달되어 유효하지 않은(Invalid) SPIR-V가 빌드되어 Vulkan 파이프라인 렌더링이 조기 취소됨.

---

## 3. 적용된 최종 수정 패치 (Final Applied Solutions)

### 1) 패키지 빌드 스크립트 수정 ([package.mk](file:///home/aleksei/ROCKNIX/projects/ROCKNIX/packages/emulators/standalone/sdoj-recomp-sa/package.mk))
- **동적 라이브러리 설치 구문 추가**: `makeinstall_target()`에 `librexruntime.so`, `libTracyClient.so`, `libsaidaioujou_recomp_tu1_*.so` 바이너리를 `/usr/lib/` 디렉토리로 배치하도록 수정.
- **Mesa Turnip 부동소수점 버그 패치**:
  `vulkan_device.cpp`에 패치를 적용하여 Mesa Turnip 드라이버 감지 시 `shaderSignedZeroInfNanPreserveFloat32 = false`로 변경함으로써 백그라운드 셰이더 무한 대기 해결.
- **`fmadz` 무력화 및 표준 SPIR-V 2-Operand 곱셈 연산자 적용**:
  `spirv_translator_alu.cpp`의 `ZeroIfAnyOperandIsZero()` 함수를 표준 SPIR-V 곱셈 연산자인 `spv::OpFMul` (`builder_->createBinOp(spv::OpFMul, ...)`)로 치환.
  - Mesa NIR의 `fmadz` 합성 패턴 오작동 방지.
  - 2개 인자를 사용하는 올바른 SPIR-V 규격 생성 보장.

### 2) 런처 스크립트 수정 ([start_sdoj_recomp.sh](file:///home/aleksei/ROCKNIX/projects/ROCKNIX/packages/emulators/standalone/sdoj-recomp-sa/scripts/start_sdoj_recomp.sh))
- `export LD_LIBRARY_PATH="${GAME_DATA}:/usr/lib:${LD_LIBRARY_PATH}"` 추가.
- `export DISPLAY="${DISPLAY:-:0}"` 및 `export GDK_BACKEND="x11"` 지정하여 Xwayland/X11 서페이스 강제 할당.
- Title Update (`TU1`) 자동 탐색 옵션 포함.

---

## 4. 빌드 및 구동 안내 (Build & Execution Instructions)

### 🔨 툴체인 cross-build 실행
```bash
DISTRO=ROCKNIX PROJECT=ROCKNIX DEVICE=SM8550 ARCH=aarch64 ./scripts/build sdoj-recomp-sa
```

### 🎮 SSH 터미널 테스트 구동 명령
```bash
DISPLAY=:0 GDK_BACKEND=x11 ./DoDonPachi\ Saidaioujou.sh
```
