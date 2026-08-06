# Audio Test Results (auto-generated)

- generatedAt: 2026-08-06T16:24:57.897282+00:00
- engineVersion: mindsound-dsp-v1
- PASS 132 · FAIL 0 · INFO 0 · TOTAL 132

## single_frequency — 46/46 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Sine 20Hz @44k | PASS | 20 | 20.0 | 0.0 |
| Sine 40Hz @44k | PASS | 40 | 40.0 | 0.0 |
| Sine 100Hz @44k | PASS | 100 | 100.0 | 0.0 |
| Sine 198Hz @44k | PASS | 198 | 198.0 | 0.0 |
| Sine 208.5Hz @44k | PASS | 208.5 | 208.5 | 0.0 |
| Sine 220Hz @44k | PASS | 220 | 220.0 | 0.0 |
| Sine 264Hz @44k | PASS | 264 | 264.0 | 0.0 |
| Sine 396Hz @44k | PASS | 396 | 396.0 | 0.0 |
| Sine 417Hz @44k | PASS | 417 | 417.0 | 0.0 |
| Sine 426Hz @44k | PASS | 426 | 426.0 | 0.0 |
| Sine 432Hz @44k | PASS | 432 | 432.0 | 0.0 |
| Sine 440Hz @44k | PASS | 440 | 440.0 | 0.0 |
| Sine 481.5Hz @44k | PASS | 481.5 | 481.5 | 0.0 |
| Sine 528Hz @44k | PASS | 528 | 528.0 | 0.0 |
| Sine 639Hz @44k | PASS | 639 | 639.0 | 0.0 |
| Sine 741Hz @44k | PASS | 741 | 741.0 | 0.0 |
| Sine 852Hz @44k | PASS | 852 | 852.0 | 0.0 |
| Sine 888Hz @44k | PASS | 888 | 888.0 | 0.0 |
| Sine 963Hz @44k | PASS | 963 | 963.0 | 0.0 |
| Sine 1000Hz @44k | PASS | 1000 | 1000.0 | 0.0 |
| Sine 5000Hz @44k | PASS | 5000 | 5000.0 | 0.0 |
| Sine 10000Hz @44k | PASS | 10000 | 10000.0 | 0.0 |
| Sine 15000Hz @44k | PASS | 15000 | 15000.0 | 0.0 |
| Sine 20Hz @48k | PASS | 20 | 20.0 | 0.0 |
| Sine 40Hz @48k | PASS | 40 | 40.0 | 0.0 |
| Sine 100Hz @48k | PASS | 100 | 100.0 | 0.0 |
| Sine 198Hz @48k | PASS | 198 | 198.0 | 0.0 |
| Sine 208.5Hz @48k | PASS | 208.5 | 208.5 | 0.0 |
| Sine 220Hz @48k | PASS | 220 | 220.0 | 0.0 |
| Sine 264Hz @48k | PASS | 264 | 264.0 | 0.0 |
| Sine 396Hz @48k | PASS | 396 | 396.0 | 0.0 |
| Sine 417Hz @48k | PASS | 417 | 417.0 | 0.0 |
| Sine 426Hz @48k | PASS | 426 | 426.0 | 0.0 |
| Sine 432Hz @48k | PASS | 432 | 432.0 | 0.0 |
| Sine 440Hz @48k | PASS | 440 | 440.0 | 0.0 |
| Sine 481.5Hz @48k | PASS | 481.5 | 481.5 | 0.0 |
| Sine 528Hz @48k | PASS | 528 | 528.0 | 0.0 |
| Sine 639Hz @48k | PASS | 639 | 639.0 | 0.0 |
| Sine 741Hz @48k | PASS | 741 | 741.0 | 0.0 |
| Sine 852Hz @48k | PASS | 852 | 852.0 | 0.0 |
| Sine 888Hz @48k | PASS | 888 | 888.0 | 0.0 |
| Sine 963Hz @48k | PASS | 963 | 963.0 | 0.0 |
| Sine 1000Hz @48k | PASS | 1000 | 1000.0 | 0.0 |
| Sine 5000Hz @48k | PASS | 5000 | 5000.0 | 0.0 |
| Sine 10000Hz @48k | PASS | 10000 | 10000.0 | 0.0 |
| Sine 15000Hz @48k | PASS | 15000 | 15000.0 | 0.0 |

## phase_continuity — 7/7 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Phase continuity block64 | PASS | 432.0 |  | 2.6519228707531234e-13 |
| Phase continuity block128 | PASS | 432.0 |  | 2.2324746624903177e-13 |
| Phase continuity block256 | PASS | 432.0 |  | 1.4435573741954696e-13 |
| Phase continuity block480 | PASS | 432.0 |  | 1.2325592868510265e-13 |
| Phase continuity block1024 | PASS | 432.0 |  | 1.432014652935328e-13 |
| Phase continuity irregular | PASS | 432.0 |  | 1.4218681130228044e-13 |
| Phase reset bug is DETECTED | PASS |  |  |  |

## long_drift — 5/5 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Drift 60min 396.0Hz | PASS | 396.0 | 396.0 | 0.0 |
| Drift 60min 432.0Hz | PASS | 432.0 | 432.0 | 0.0 |
| Drift 60min 528.0Hz | PASS | 528.0 | 528.0 | 0.0 |
| Drift 60min 741.0Hz | PASS | 741.0 | 741.0 | 0.0 |
| Drift 60min 963.0Hz | PASS | 963.0 | 963.0 | 0.0 |

## frequency_ramp — 30/30 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Ramp 396->417 10ms | PASS | 417 | 417.0 | 0.0 |
| Ramp 396->417 30ms | PASS | 417 | 417.0 | 0.0 |
| Ramp 396->417 50ms | PASS | 417 | 417.0 | 0.0 |
| Ramp 396->417 100ms | PASS | 417 | 417.0 | 0.0 |
| Ramp 396->417 1500ms | PASS | 417 | 417.0 | 0.0 |
| Ramp 432->528 10ms | PASS | 528 | 528.0 | 0.0 |
| Ramp 432->528 30ms | PASS | 528 | 528.0 | 0.0 |
| Ramp 432->528 50ms | PASS | 528 | 528.0 | 0.0 |
| Ramp 432->528 100ms | PASS | 528 | 528.0 | 0.0 |
| Ramp 432->528 1500ms | PASS | 528 | 528.0 | 0.0 |
| Ramp 528->741 10ms | PASS | 741 | 741.0 | 0.0 |
| Ramp 528->741 30ms | PASS | 741 | 741.0 | 0.0 |
| Ramp 528->741 50ms | PASS | 741 | 741.0 | 0.0 |
| Ramp 528->741 100ms | PASS | 741 | 741.0 | 0.0 |
| Ramp 528->741 1500ms | PASS | 741 | 741.0 | 0.0 |
| Ramp 741->852 10ms | PASS | 852 | 852.0 | 0.0 |
| Ramp 741->852 30ms | PASS | 852 | 852.0 | 0.0 |
| Ramp 741->852 50ms | PASS | 852 | 852.0 | 0.0 |
| Ramp 741->852 100ms | PASS | 852 | 852.0 | 0.0 |
| Ramp 741->852 1500ms | PASS | 852 | 852.0 | 0.0 |
| Ramp 852->963 10ms | PASS | 963 | 963.0 | 0.0 |
| Ramp 852->963 30ms | PASS | 963 | 963.0 | 0.0 |
| Ramp 852->963 50ms | PASS | 963 | 963.0 | 0.0 |
| Ramp 852->963 100ms | PASS | 963 | 963.0 | 0.0 |
| Ramp 852->963 1500ms | PASS | 963 | 963.0 | 0.0 |
| Ramp 963->481.5 10ms | PASS | 481.5 | 481.46893 | 0.031073 |
| Ramp 963->481.5 30ms | PASS | 481.5 | 481.46893 | 0.031073 |
| Ramp 963->481.5 50ms | PASS | 481.5 | 481.46893 | 0.031073 |
| Ramp 963->481.5 100ms | PASS | 481.5 | 481.46893 | 0.031073 |
| Ramp 963->481.5 1500ms | PASS | 481.5 | 481.46893 | 0.031073 |

## gain_fade — 10/10 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Gain fade_in 30ms | PASS |  |  |  |
| Gain fade_in 100ms | PASS |  |  |  |
| Gain fade_in 1000ms | PASS |  |  |  |
| Gain fade_in 3000ms | PASS |  |  |  |
| Gain fade_in 10000ms | PASS |  |  |  |
| Gain fade_out 30ms | PASS |  |  |  |
| Gain fade_out 100ms | PASS |  |  |  |
| Gain fade_out 1000ms | PASS |  |  |  |
| Gain fade_out 3000ms | PASS |  |  |  |
| Gain fade_out 10000ms | PASS |  |  |  |

## binaural — 4/4 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Binaural A beat 4Hz | PASS |  |  |  |
| Binaural B beat 7.83Hz | PASS |  |  |  |
| Binaural C beat 10Hz | PASS |  |  |  |
| Binaural D beat 16Hz | PASS |  |  |  |

## pulse — 12/12 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Pulse 1Hz c432 d50% | PASS | 1 | 1.0 | 0.0 |
| Pulse 4Hz c432 d50% | PASS | 4 | 4.0 | 0.0 |
| Pulse 6Hz c432 d50% | PASS | 6 | 6.0 | 0.0 |
| Pulse 7.83Hz c432 d50% | PASS | 7.83 | 7.82818 | 0.001817 |
| Pulse 8.8Hz c432 d50% | PASS | 8.8 | 8.80152 | 0.001518 |
| Pulse 10Hz c432 d50% | PASS | 10 | 10.0 | 0.0 |
| Pulse 16Hz c432 d50% | PASS | 16 | 16.0 | 0.0 |
| Pulse 7.83Hz c220 d50% | PASS | 7.83 | 7.82818 | 0.001817 |
| Pulse 7.83Hz c528 d50% | PASS | 7.83 | 7.82818 | 0.001817 |
| Pulse 7.83Hz c432 d10% | PASS | 7.83 | 7.82818 | 0.001817 |
| Pulse 7.83Hz c432 d25% | PASS | 7.83 | 7.82818 | 0.001817 |
| Pulse 7.83Hz c432 d100% | PASS | 7.83 | 7.82818 | 0.001817 |

## drone — 11/11 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Drone center 396Hz | PASS | 396 | 395.99957 |  |
| Drone center 417Hz | PASS | 417 | 416.99957 |  |
| Drone center 432Hz | PASS | 432 | 431.99957 |  |
| Drone center 528Hz | PASS | 528 | 527.99957 |  |
| Drone center 639Hz | PASS | 639 | 638.99957 |  |
| Drone center 741Hz | PASS | 741 | 740.99957 |  |
| Drone center 852Hz | PASS | 852 | 851.99957 |  |
| Drone center 963Hz | PASS | 963 | 962.99957 |  |
| Drone LFO 0.03Hz | PASS | 0.03 | 0.02991 | 9e-05 |
| Drone LFO 0.05Hz | PASS | 0.05 | 0.05 | 0.0 |
| Drone LFO 0.1Hz | PASS | 0.1 | 0.1 | 0.0 |

## mixer — 5/5 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Mixer combo1 (528+drone) | PASS |  |  |  |
| Mixer combo2 (abundance) | PASS |  |  |  |
| Mixer combo3 (cleanse tones) | PASS |  |  |  |
| Mixer combo4 (all layers) | PASS |  |  |  |
| Mixer mute (741 muted) | PASS |  |  |  |

## sequence — 2/2 PASS
| test | status | target | measured | error |
|---|---|---|---|---|
| Sequence silent stage | PASS |  |  |  |
| Sequence crossfade 396->741 | PASS |  |  |  |
