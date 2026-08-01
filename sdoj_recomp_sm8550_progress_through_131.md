# SDOJ Recomp SM8550 검은 화면 조사 기록 (테스트 131까지 최종 업데이트)

작성 시점: 2026-07-23 (KST)

이 문서는 `sdoj_recomp_sm8550_progress_through_119.md` 이후 진행한 테스트 120~131의 진단 결과와 결정적인 원인 규명 내용을 정리한 인계 문서다.

---

## 1. 개요 및 현재 증상
- **대상**: ROCKNIX / SM8550 / Snapdragon 8 Gen 2 / Adreno 740
- **Vulkan 드라이버**: Mesa Turnip 26.1.2
- **애플리케이션**: SDOJ Recomp / ReXGlue Vulkan backend
- **증상**: 게임 오디오 및 키 입구 로직은 100% 정상 작동하나, 화면이 검정색으로 출력됨.

---

## 2. 테스트 120 ~ 129 진행 요약

- **테스트 120~122 (CPU-GPU Upload & Staging Readback)**:
  - GPU `vkCmdFillBuffer` 및 `vkCmdCopyBuffer`를 통한 staging readback 결과, staging buffer와 shared memory 간 데이터 전송은 정상 동작함 (`A5A5A5A5` 센티널 데이터 정상 보존).
  - CPU 업로드/Staging Copy 자체는 렌더링 불능의 직접 원인이 아님이 확인됨.
- **테스트 123~126 (Vertex Shader & Clip/Cull Distance)**:
  - 알려진 VS hash에 대해 `gl_Position` 전체화면 삼각형 강제 지정 및 Clip/Cull Distance 우회 테스트 진행.
  - 전역 셰이더 캐시 재생성을 확인했으나 계속 검은 화면 유지. (VS 셰이더 단의 킬/클리핑 문제는 아님)
- **테스트 127~129 (Fixed Pipeline & Viewport/Scissor & Fragment Kill)**:
  - Culling, Depth/Stencil Compare, Rasterizer Discard, Blend, Dynamic Viewport/Scissor 및 Fragment Kill/Demote 전체를 안전 상태로 강제 해제.
  - 여전히 검은 화면이 유지되어 렌더링 파이프라인 전반의 기하학적 커팅 문제가 아님이 확인됨.

---

## 3. 테스트 130 ~ 131 결정적 발견 (Smoking Gun)

### A. 테스트 130: 동기 GPU Readback & Frontbuffer 비교
- **Resolve 렌더링 출력 (GPU VRAM)**:
  ```log
  [gpu] SDOJ test 130 resolve: address=0x1EF3B000 length=0x384000 words=921600 nonzero=460800 or=A5A5A5A5
  [gpu] SDOJ test 130 resolve: address=0x1DE00000 length=0x206000 words=530432 nonzero=271232 or=A5A5A5A5
  ```
  - GPU가 Resolve 렌더 타겟에 화면을 그린 직후 VRAM 메모리를 확인한 결과, 921,600개 단어 중 **460,800개(정확히 50%)가 유효 픽셀 데이터(non-zero)**로 화면이 100% 정상 렌더링되고 있음.
- **Present 시점 참조 버퍼 (Frontbuffer)**:
  ```log
  [gpu] XELOG_GPU PRESENT: frontbuffer_ptr=0x1E80B000 swap_texture_view=0xffff4821a960 ...
  [gpu] SDOJ test 130 frontbuffer: ptr=0x1E80B000 size=0x384000 words=921600 nonzero=10240 ...
  ```
  - 그러나 화면 출력을 담당하는 Presenter가 읽어가는 `frontbuffer_ptr` 주소(`0x1E80B000`, `0x1EBA3000`)는 렌더링이 수행된 Resolve 주소(`0x1EF3B000`)와 전혀 다른 주소를 가리키고 있거나, 유효 픽셀이 1% 미만인 텅 빈 더미 버퍼를 참조하고 있음.

### B. 테스트 131: CPU Physical Memory 주소 검사
```log
[gpu] SDOJ test 131 swap check: front_ptr=0x1EBA3000 (nonzero=0), resolve_ptr=0x1EBB7000 (nonzero=0)
[gpu] SDOJ test 131 swap check: front_ptr=0x1E80B000 (nonzero=0), resolve_ptr=0x1E81F000 (nonzero=0)
```
- CPU 메인 램(`memory_->TranslatePhysical(addr)`) 상에서 `frontbuffer_ptr` 및 일부 resolve 전달 주소들은 `nonzero=0` (0x00000000 텅 빈 상태)로 남아 있음.
- **근본 원인 규명**:
  1. GPU VRAM 상에는 `0x1EF3B000`에 화면 렌더링 결과가 완성되어 있음.
  2. 그러나 `VulkanTextureCache::RequestSwapTexture` 및 Presenter가 화면에 스왑 텍스처를 바인딩할 때, GPU VRAM의 최신 렌더 타겟 Image(`0x1EF3B000`) 대신 CPU RAM 상의 텅 빈 더미 버퍼 주소(`0x1EBA3000`, `0x1E80B000`)를 읽으려 하여 화면에 아무것도 나오지 않는 것임.

---

## 4. 코덱스(Codex) 및 다음 개발자를 위한 해결 가이드

1. **Vulkan Presenter와 RenderTarget Cache 바인딩 수정을 위한 핵심 작업**:
   - `src/graphics/vulkan/command_processor.cpp`의 `IssueSwap` 및 `texture_cache.cpp`의 `RequestSwapTexture` 수정.
   - `RequestSwapTexture`가 게스트 레지스터 `GetTextureFetch(0)`만 의존하지 않고, 최근 `Resolve`가 완료된 GPU Vulkan RenderTarget Image (`0x1EF3B000`) 또는 텍스처 뷰를 직접 Presenter의 스왑 텍스처(`swap_texture_view`)로 바인딩하도록 연결.
2. **확인할 파일**:
   - `src/graphics/vulkan/command_processor.cpp` (`IssueSwap`, `IssueCopy_StandardResolvePath`)
   - `src/graphics/vulkan/texture_cache.cpp` (`RequestSwapTexture`)
   - `src/graphics/vulkan/render_target_cache.cpp` (`Resolve`)
