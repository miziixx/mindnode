# 프리셋 주파수 검증 리포트

- 프리셋 21개 중 **21 PASS**
- 각 프리셋의 선언 주파수를 엔진으로 실제 생성→측정하고, 대중 기준값과 대조.
- 청취용 합성 믹스: `test_output/preset_renders/<id>.wav`

| 프리셋 | 상태 | 레이어(선언→측정) | 뇌파대역 | 기준 |
|---|---|---|---|---|
| 마음 끌어올리기 | PASS | primary 528.0→528.0Hz; drone.main 528.0→528.0Hz |  | Solfeggio 528 |
| 활력 깨우기 | PASS | primary 528.0→528.0Hz; secondary 741.0→741.0Hz; drone.main 528.0→528.0Hz; pulse.rate 16.0→16.0Hz |  | Solfeggio 528, Solfeggio 741 |
| 풍요 · 돈 들어오는 의식 | PASS | secondary 888.0→888.0Hz; drone.main 432.0→432.0Hz; pulse.rate 8.8→8.802Hz |  | 432 튜닝, 888 풍요(상징) |
| 부정적 에너지 정화 | PASS | primary 396.0→396.0Hz; drone.main 396.0→396.0Hz |  | Solfeggio 396 |
| 깊은 명상 | PASS | primary 432.0→432.0Hz; drone.main 432.0→432.0Hz |  | 432 튜닝 |
| 레이키 · 셀프 | PASS | secondary 528.0→528.0Hz; drone.main 432.0→432.0Hz; pulse.rate 7.83→7.828Hz |  | 432 튜닝, Schumann 7.83, Solfeggio 528 |
| 1차크라 · 안정 | PASS | primary 396.0→396.0Hz; drone.main 396.0→396.0Hz |  | Solfeggio 396 |
| 2차크라 · 감정과 창조 | PASS | primary 417.0→417.0Hz; drone.main 417.0→417.0Hz |  | Solfeggio 417 |
| 3차크라 · 의지와 활력 | PASS | primary 528.0→528.0Hz; drone.main 528.0→528.0Hz |  | Solfeggio 528 |
| 4차크라 · 사랑과 연결 | PASS | primary 639.0→639.0Hz; drone.main 639.0→639.0Hz |  | Solfeggio 639 |
| 5차크라 · 표현 | PASS | primary 741.0→741.0Hz; drone.main 741.0→741.0Hz |  | Solfeggio 741 |
| 6차크라 · 직관 | PASS | primary 852.0→852.0Hz; drone.main 426.0→426.0Hz |  | Solfeggio 852 |
| 7차크라 · 명상과 연결 | PASS | primary 963.0→963.0Hz; drone.main 481.5→481.5Hz |  | Solfeggio 963 |
| 전체 차크라 순환 | PASS | primary 396.0→396.0Hz; drone.main 396.0→396.0Hz |  | Solfeggio 396 |
| 잠이 안 올 때 · 수면 유도 | PASS | drone.main 108.0→108.0Hz; binaural.left 100.0→100.0Hz; binaural.beat 3.0→3.0Hz | Delta (기대 Delta, OK) |  |
| 깊은 수면 | PASS | drone.main 90.0→90.0Hz; binaural.left 90.0→90.0Hz; binaural.beat 2.0→2.0Hz | Delta (기대 Delta, OK) |  |
| 집중 · 공부와 업무 | PASS | drone.main 220.0→220.0Hz; binaural.left 220.0→220.0Hz; binaural.beat 14.0→14.0Hz | Beta (기대 Beta, OK) |  |
| 몰입 · 딥워크 | PASS | drone.main 220.0→220.0Hz; binaural.left 220.0→220.0Hz; binaural.beat 40.0→40.0Hz | Gamma (기대 Gamma, OK) |  |
| 불안·긴장 완화 | PASS | primary 432.0→432.0Hz; drone.main 216.0→216.0Hz; binaural.left 216.0→216.0Hz; binaural.beat 10.0→10.0Hz | Alpha (기대 Alpha, OK) | 432 튜닝 |
| 세타 · 깊은 이완 | PASS | drone.main 216.0→216.0Hz; binaural.left 216.0→216.0Hz; binaural.beat 6.0→6.0Hz | Theta (기대 Theta, OK) |  |
| 스트레스 해소 · 7.83Hz | PASS | drone.main 432.0→432.0Hz; pulse.rate 7.83→7.828Hz |  | 432 튜닝, Schumann 7.83 |
