# Monitor maintenance timing distributions

Generated from the byte-verified native receipt inventory. Values are milliseconds per whole scheduler call unless explicitly marked as hook attribution. No numerical pass/fail threshold is applied.

Each row contains exactly 600 post-cold/re-warm samples. Window 1 and window 2 are independent save/create/cold processes, not two selections from one run. All compared guests/test drivers match within their scene/workload. Hardware: AMD Ryzen 9 7900 host with four available logical CPUs; shared host contention is retained in the raw run inventory.

## Window 1

| Archive / scene / workload | Mode | Mean | Median | p95 | Maximum |
| --- | --- | ---: | ---: | ---: | ---: |
| released/zero-sparse | base | 0.156642 | 0.132648 | 0.361138 | 0.709603 |
| released/zero-sparse | space-age | 0.163907 | 0.137121 | 0.324708 | 0.864758 |
| prechange/zero-sparse | base | 0.153902 | 0.131916 | 0.284733 | 0.768075 |
| prechange/zero-sparse | space-age | 0.164957 | 0.139285 | 0.244105 | 1.088365 |
| candidate/zero-sparse | base | 0.159220 | 0.132682 | 0.386046 | 0.731585 |
| candidate/zero-sparse | space-age | 0.175017 | 0.140563 | 0.448524 | 1.151153 |
| released/idle-sparse | base | 6.871259 | 5.036954 | 16.844813 | 24.397937 |
| released/idle-sparse | space-age | 7.558813 | 5.270570 | 19.710454 | 24.024995 |
| prechange/idle-sparse | base | 6.957244 | 5.086429 | 17.340276 | 26.093709 |
| prechange/idle-sparse | space-age | 7.432151 | 5.142610 | 19.143201 | 26.007222 |
| candidate/idle-sparse | base | 2.678536 | 1.766932 | 8.088414 | 13.842621 |
| candidate/idle-sparse | space-age | 2.960072 | 1.833689 | 9.564798 | 15.042497 |
| released/one-sparse | base | 19.774884 | 23.189989 | 45.220419 | 68.046959 |
| released/one-sparse | space-age | 21.024922 | 25.221109 | 50.204566 | 69.257527 |
| prechange/one-sparse | base | 20.152054 | 24.983673 | 46.704046 | 60.765293 |
| prechange/one-sparse | space-age | 20.793739 | 25.445096 | 49.249014 | 60.764581 |
| candidate/one-sparse | base | 15.400921 | 18.191889 | 31.443762 | 44.922730 |
| candidate/one-sparse | space-age | 16.254370 | 19.740900 | 36.645796 | 47.790216 |
| released/all-sparse | base | 24.033783 | 28.859808 | 54.168369 | 75.589443 |
| released/all-sparse | space-age | 25.630528 | 32.613953 | 60.024068 | 69.580331 |
| prechange/all-sparse | base | 23.759917 | 29.194075 | 54.038473 | 62.157053 |
| prechange/all-sparse | space-age | 25.150847 | 29.125344 | 57.710167 | 94.190279 |
| candidate/all-sparse | base | 20.141636 | 21.173060 | 48.990762 | 65.101454 |
| candidate/all-sparse | space-age | 21.201339 | 22.769632 | 53.242154 | 64.410427 |
| released/all-full-blit | base | 26.211345 | 34.218154 | 59.051093 | 84.307173 |
| released/all-full-blit | space-age | 25.081442 | 31.882960 | 57.298664 | 68.866418 |
| prechange/all-full-blit | base | 24.314423 | 33.990470 | 55.020261 | 73.432068 |
| prechange/all-full-blit | space-age | 25.132389 | 30.144100 | 56.949377 | 71.356753 |
| candidate/all-full-blit | base | 20.061761 | 20.947896 | 47.652630 | 67.886260 |
| candidate/all-full-blit | space-age | 20.975823 | 21.856061 | 51.714020 | 59.839806 |

## Window 2

| Archive / scene / workload | Mode | Mean | Median | p95 | Maximum |
| --- | --- | ---: | ---: | ---: | ---: |
| released/zero-sparse | base | 0.157847 | 0.135002 | 0.273351 | 0.721936 |
| released/zero-sparse | space-age | 0.161724 | 0.137011 | 0.285663 | 1.071462 |
| prechange/zero-sparse | base | 0.161433 | 0.132453 | 0.364165 | 1.100377 |
| prechange/zero-sparse | space-age | 0.150727 | 0.128029 | 0.272400 | 0.709752 |
| candidate/zero-sparse | base | 0.157430 | 0.131245 | 0.362691 | 1.007601 |
| candidate/zero-sparse | space-age | 0.163632 | 0.132758 | 0.411314 | 0.903762 |
| released/idle-sparse | base | 6.780123 | 4.975718 | 16.076407 | 25.143457 |
| released/idle-sparse | space-age | 7.343700 | 5.168525 | 19.316451 | 25.689186 |
| prechange/idle-sparse | base | 7.476564 | 5.017933 | 20.534212 | 25.379637 |
| prechange/idle-sparse | space-age | 7.321830 | 5.150565 | 18.984138 | 30.711577 |
| candidate/idle-sparse | base | 2.722929 | 1.767262 | 8.561966 | 12.643706 |
| candidate/idle-sparse | space-age | 2.930834 | 1.806874 | 9.573714 | 14.326963 |
| released/one-sparse | base | 19.655799 | 26.240883 | 45.273869 | 56.090994 |
| released/one-sparse | space-age | 20.548643 | 26.889755 | 48.443049 | 62.748692 |
| prechange/one-sparse | base | 20.250670 | 23.078962 | 46.050499 | 57.159531 |
| prechange/one-sparse | space-age | 20.420702 | 26.480795 | 48.651907 | 66.393738 |
| candidate/one-sparse | base | 15.333354 | 18.282581 | 35.525551 | 53.699326 |
| candidate/one-sparse | space-age | 15.848782 | 17.344172 | 37.446163 | 45.675165 |
| released/all-sparse | base | 23.849632 | 27.794033 | 53.846376 | 59.997409 |
| released/all-sparse | space-age | 24.553280 | 30.734551 | 56.556872 | 68.491907 |
| prechange/all-sparse | base | 23.461008 | 29.159740 | 52.846710 | 62.986013 |
| prechange/all-sparse | space-age | 24.515148 | 29.227130 | 56.645280 | 71.587385 |
| candidate/all-sparse | base | 19.875335 | 20.039360 | 48.666284 | 67.882494 |
| candidate/all-sparse | space-age | 20.392615 | 21.140929 | 50.700071 | 64.799349 |
| released/all-full-blit | base | 24.015965 | 27.538622 | 53.871693 | 73.887158 |
| released/all-full-blit | space-age | 25.218300 | 32.333604 | 57.904208 | 67.903304 |
| prechange/all-full-blit | base | 24.384845 | 34.566604 | 54.419247 | 62.350310 |
| prechange/all-full-blit | space-age | 25.233940 | 31.380958 | 58.122585 | 79.399773 |
| candidate/all-full-blit | base | 20.392565 | 21.223140 | 49.319128 | 54.048471 |
| candidate/all-full-blit | space-age | 21.249670 | 23.328648 | 52.661457 | 69.300636 |

## Interpretation

The candidate reduces monitor-scene work in the idle and active comparisons, but still pays live observation, circuit/authority and guest/render costs. The zero-monitor control has small mean/tail differences; these are not a monitor optimization gain and must not be hidden. In window 2, the all-sparse base maximum worsens from 59.997409 to 67.882494 ms, and the all-full-blit Space Age maximum from 67.903304 to 69.300636 ms, despite lower means. Each window is reported separately because host load/GC and runtime tails vary. No real-time UPS, client FPS or full-modpack speedup follows from accelerated headless simulation.

## Separate hook attribution

The following means come from **another instrumented archive/run**, not the whole-scheduler windows above. Every phase profile has exactly 600 observations per mode. The observer adds native profiler, protected-call, tuple and log overhead, including GC effects; phase sums must not be subtracted from the uninstrumented totals or interpreted as synchronized admission work units. Full median/p95/max for every hook are preserved in `verified-ledger.json`.

| Archive / scene / workload | Mode | Hook | Mean ms | Median ms | p95 ms | Maximum ms |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| released/zero-sparse | base | `lifecycle/00-physical-power-loss` | 0.017837 | 0.016206 | 0.027522 | 0.060084 |
| released/zero-sparse | base | `lifecycle/01-clone-components` | 0.001783 | 0.000561 | 0.000821 | 0.439768 |
| released/zero-sparse | base | `lifecycle/01-network-output-authority` | 0.002136 | 0.002024 | 0.002516 | 0.011302 |
| released/zero-sparse | base | `lifecycle/02-monitor-groups` | 0.004867 | 0.004198 | 0.005921 | 0.057972 |
| released/zero-sparse | base | `lifecycle/02-native-radar-adoption` | 0.068955 | 0.045436 | 0.286265 | 0.637686 |
| released/zero-sparse | base | `lifecycle/physical-devices` | 0.027206 | 0.023255 | 0.038244 | 0.405493 |
| released/zero-sparse | base | `sample/logic-input` | 0.005875 | 0.003743 | 0.009779 | 0.288940 |
| released/zero-sparse | base | `notifications/monitor-events` | 0.001917 | 0.001473 | 0.002534 | 0.026390 |
| released/zero-sparse | base | `notifications/peripheral-topology` | 0.001294 | 0.001213 | 0.001763 | 0.009780 |
| released/zero-sparse | base | `render/device-status-art` | 0.007068 | 0.006271 | 0.007524 | 0.321723 |
| released/zero-sparse | base | `render/kv-reclamation` | 0.001831 | 0.001442 | 0.002014 | 0.023485 |
| released/zero-sparse | base | `render/monitor-world` | 0.005960 | 0.005701 | 0.006892 | 0.018927 |
| released/zero-sparse | base | `render/program-editor` | 0.000522 | 0.000431 | 0.001162 | 0.002094 |
| released/zero-sparse | base | `render/ui-peripheral-inspectors` | 0.000595 | 0.000420 | 0.002374 | 0.003928 |
| released/zero-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.019255 | 0.017519 | 0.029347 | 0.081375 |
| released/zero-sparse | space-age | `lifecycle/01-clone-components` | 0.000598 | 0.000551 | 0.000892 | 0.001383 |
| released/zero-sparse | space-age | `lifecycle/01-network-output-authority` | 0.002222 | 0.002144 | 0.002544 | 0.009217 |
| released/zero-sparse | space-age | `lifecycle/02-monitor-groups` | 0.004987 | 0.004348 | 0.005891 | 0.058091 |
| released/zero-sparse | space-age | `lifecycle/02-native-radar-adoption` | 0.078056 | 0.048603 | 0.328737 | 0.880709 |
| released/zero-sparse | space-age | `lifecycle/physical-devices` | 0.027456 | 0.024778 | 0.044535 | 0.097787 |
| released/zero-sparse | space-age | `sample/logic-input` | 0.004936 | 0.004007 | 0.006953 | 0.045648 |
| released/zero-sparse | space-age | `notifications/monitor-events` | 0.002049 | 0.001557 | 0.005600 | 0.022141 |
| released/zero-sparse | space-age | `notifications/peripheral-topology` | 0.001376 | 0.001312 | 0.001663 | 0.008386 |
| released/zero-sparse | space-age | `render/device-status-art` | 0.006841 | 0.006543 | 0.007746 | 0.016751 |
| released/zero-sparse | space-age | `render/kv-reclamation` | 0.002079 | 0.001533 | 0.006241 | 0.022122 |
| released/zero-sparse | space-age | `render/monitor-world` | 0.006272 | 0.006041 | 0.007313 | 0.018756 |
| released/zero-sparse | space-age | `render/program-editor` | 0.000583 | 0.000450 | 0.001273 | 0.008397 |
| released/zero-sparse | space-age | `render/ui-peripheral-inspectors` | 0.000653 | 0.000451 | 0.002475 | 0.005269 |
| prechange/zero-sparse | base | `lifecycle/00-physical-power-loss` | 0.019353 | 0.017593 | 0.031029 | 0.077569 |
| prechange/zero-sparse | base | `lifecycle/01-clone-components` | 0.000650 | 0.000611 | 0.000932 | 0.002875 |
| prechange/zero-sparse | base | `lifecycle/01-network-output-authority` | 0.002219 | 0.002115 | 0.002535 | 0.015889 |
| prechange/zero-sparse | base | `lifecycle/02-monitor-groups` | 0.005542 | 0.004319 | 0.008366 | 0.294161 |
| prechange/zero-sparse | base | `lifecycle/02-native-radar-adoption` | 0.072265 | 0.047320 | 0.283420 | 0.879926 |
| prechange/zero-sparse | base | `lifecycle/physical-devices` | 0.028217 | 0.024126 | 0.044025 | 0.589603 |
| prechange/zero-sparse | base | `sample/logic-input` | 0.005253 | 0.003848 | 0.007855 | 0.093959 |
| prechange/zero-sparse | base | `notifications/monitor-events` | 0.002002 | 0.001533 | 0.002996 | 0.022793 |
| prechange/zero-sparse | base | `notifications/peripheral-topology` | 0.001354 | 0.001282 | 0.001764 | 0.004899 |
| prechange/zero-sparse | base | `render/device-status-art` | 0.006741 | 0.006417 | 0.007856 | 0.022373 |
| prechange/zero-sparse | base | `render/kv-reclamation` | 0.002971 | 0.001513 | 0.002245 | 0.362250 |
| prechange/zero-sparse | base | `render/monitor-world` | 0.006173 | 0.005871 | 0.007243 | 0.020700 |
| prechange/zero-sparse | base | `render/program-editor` | 0.000529 | 0.000430 | 0.001212 | 0.002364 |
| prechange/zero-sparse | base | `render/ui-peripheral-inspectors` | 0.000628 | 0.000425 | 0.002485 | 0.005189 |
| prechange/zero-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.022111 | 0.018451 | 0.033414 | 0.571960 |
| prechange/zero-sparse | space-age | `lifecycle/01-clone-components` | 0.000716 | 0.000631 | 0.001092 | 0.011312 |
| prechange/zero-sparse | space-age | `lifecycle/01-network-output-authority` | 0.002304 | 0.002154 | 0.002986 | 0.014828 |
| prechange/zero-sparse | space-age | `lifecycle/02-monitor-groups` | 0.006830 | 0.004489 | 0.008446 | 0.420352 |
| prechange/zero-sparse | space-age | `lifecycle/02-native-radar-adoption` | 0.080108 | 0.050620 | 0.300774 | 1.601923 |
| prechange/zero-sparse | space-age | `lifecycle/physical-devices` | 0.031941 | 0.025238 | 0.045548 | 0.591667 |
| prechange/zero-sparse | space-age | `sample/logic-input` | 0.005752 | 0.004088 | 0.007845 | 0.118036 |
| prechange/zero-sparse | space-age | `notifications/monitor-events` | 0.002219 | 0.001683 | 0.002956 | 0.038042 |
| prechange/zero-sparse | space-age | `notifications/peripheral-topology` | 0.001438 | 0.001343 | 0.002044 | 0.006532 |
| prechange/zero-sparse | space-age | `render/device-status-art` | 0.007577 | 0.006562 | 0.009810 | 0.335820 |
| prechange/zero-sparse | space-age | `render/kv-reclamation` | 0.002062 | 0.001523 | 0.002495 | 0.037070 |
| prechange/zero-sparse | space-age | `render/monitor-world` | 0.006469 | 0.006192 | 0.009047 | 0.019878 |
| prechange/zero-sparse | space-age | `render/program-editor` | 0.000591 | 0.000481 | 0.001283 | 0.001804 |
| prechange/zero-sparse | space-age | `render/ui-peripheral-inspectors` | 0.000695 | 0.000461 | 0.002495 | 0.010321 |
| candidate/zero-sparse | base | `lifecycle/00-physical-power-loss` | 0.018729 | 0.017093 | 0.026811 | 0.070374 |
| candidate/zero-sparse | base | `lifecycle/01-clone-components` | 0.000646 | 0.000591 | 0.000891 | 0.011302 |
| candidate/zero-sparse | base | `lifecycle/01-network-output-authority` | 0.002197 | 0.002055 | 0.002594 | 0.019097 |
| candidate/zero-sparse | base | `lifecycle/02-monitor-groups` | 0.001945 | 0.001522 | 0.002715 | 0.024846 |
| candidate/zero-sparse | base | `lifecycle/02-native-radar-adoption` | 0.068988 | 0.048036 | 0.121071 | 0.611615 |
| candidate/zero-sparse | base | `lifecycle/physical-devices` | 0.026857 | 0.024051 | 0.041781 | 0.126521 |
| candidate/zero-sparse | base | `sample/logic-input` | 0.004982 | 0.003817 | 0.011161 | 0.043272 |
| candidate/zero-sparse | base | `notifications/monitor-events` | 0.002426 | 0.001563 | 0.003467 | 0.057530 |
| candidate/zero-sparse | base | `notifications/peripheral-topology` | 0.001364 | 0.001272 | 0.001723 | 0.014878 |
| candidate/zero-sparse | base | `render/device-status-art` | 0.006750 | 0.006432 | 0.007896 | 0.022643 |
| candidate/zero-sparse | base | `render/kv-reclamation` | 0.002260 | 0.001493 | 0.002415 | 0.057029 |
| candidate/zero-sparse | base | `render/monitor-world` | 0.007145 | 0.006733 | 0.008747 | 0.030668 |
| candidate/zero-sparse | base | `render/program-editor` | 0.000563 | 0.000446 | 0.001192 | 0.011202 |
| candidate/zero-sparse | base | `render/ui-peripheral-inspectors` | 0.000647 | 0.000431 | 0.002335 | 0.018616 |
| candidate/zero-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.020852 | 0.018370 | 0.030869 | 0.346601 |
| candidate/zero-sparse | space-age | `lifecycle/01-clone-components` | 0.000708 | 0.000621 | 0.001092 | 0.010020 |
| candidate/zero-sparse | space-age | `lifecycle/01-network-output-authority` | 0.002308 | 0.002195 | 0.003056 | 0.014428 |
| candidate/zero-sparse | space-age | `lifecycle/02-monitor-groups` | 0.002139 | 0.001674 | 0.002766 | 0.049924 |
| candidate/zero-sparse | space-age | `lifecycle/02-native-radar-adoption` | 0.072437 | 0.049434 | 0.166397 | 0.922658 |
| candidate/zero-sparse | space-age | `lifecycle/physical-devices` | 0.027771 | 0.025103 | 0.042932 | 0.121431 |
| candidate/zero-sparse | space-age | `sample/logic-input` | 0.005754 | 0.004108 | 0.011151 | 0.092947 |
| candidate/zero-sparse | space-age | `notifications/monitor-events` | 0.002304 | 0.001673 | 0.002865 | 0.046017 |
| candidate/zero-sparse | space-age | `notifications/peripheral-topology` | 0.001557 | 0.001362 | 0.002044 | 0.023113 |
| candidate/zero-sparse | space-age | `render/device-status-art` | 0.007311 | 0.006873 | 0.009960 | 0.021711 |
| candidate/zero-sparse | space-age | `render/kv-reclamation` | 0.002161 | 0.001583 | 0.002465 | 0.047612 |
| candidate/zero-sparse | space-age | `render/monitor-world` | 0.007707 | 0.007203 | 0.011182 | 0.044214 |
| candidate/zero-sparse | space-age | `render/program-editor` | 0.000537 | 0.000431 | 0.001193 | 0.002444 |
| candidate/zero-sparse | space-age | `render/ui-peripheral-inspectors` | 0.000712 | 0.000441 | 0.002565 | 0.010269 |
| released/idle-sparse | base | `lifecycle/00-physical-power-loss` | 0.983834 | 0.706336 | 2.281137 | 8.331017 |
| released/idle-sparse | base | `lifecycle/01-clone-components` | 0.001032 | 0.000872 | 0.001673 | 0.033654 |
| released/idle-sparse | base | `lifecycle/01-network-output-authority` | 0.043905 | 0.041370 | 0.061297 | 0.103046 |
| released/idle-sparse | base | `lifecycle/02-monitor-groups` | 2.088387 | 1.319639 | 5.877711 | 11.703044 |
| released/idle-sparse | base | `lifecycle/02-native-radar-adoption` | 1.128426 | 0.743997 | 4.082129 | 8.119944 |
| released/idle-sparse | base | `lifecycle/physical-devices` | 1.473337 | 1.107301 | 3.877118 | 10.476185 |
| released/idle-sparse | base | `sample/logic-input` | 0.140622 | 0.017272 | 1.245755 | 2.815415 |
| released/idle-sparse | base | `notifications/monitor-events` | 0.003051 | 0.002494 | 0.004899 | 0.044755 |
| released/idle-sparse | base | `notifications/peripheral-topology` | 0.006447 | 0.005992 | 0.008756 | 0.014677 |
| released/idle-sparse | base | `render/device-status-art` | 0.213295 | 0.208112 | 0.240387 | 0.347442 |
| released/idle-sparse | base | `render/kv-reclamation` | 0.024235 | 0.023445 | 0.029557 | 0.053402 |
| released/idle-sparse | base | `render/monitor-world` | 0.922547 | 0.704553 | 1.879893 | 8.792305 |
| released/idle-sparse | base | `render/program-editor` | 0.000856 | 0.000661 | 0.002074 | 0.004920 |
| released/idle-sparse | base | `render/ui-peripheral-inspectors` | 0.001156 | 0.000681 | 0.003276 | 0.055566 |
| released/idle-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.995808 | 0.725878 | 2.340601 | 7.795246 |
| released/idle-sparse | space-age | `lifecycle/01-clone-components` | 0.001082 | 0.000942 | 0.001783 | 0.010770 |
| released/idle-sparse | space-age | `lifecycle/01-network-output-authority` | 0.044760 | 0.041303 | 0.067929 | 0.123255 |
| released/idle-sparse | space-age | `lifecycle/02-monitor-groups` | 2.239835 | 1.336422 | 7.063963 | 12.589400 |
| released/idle-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.195923 | 0.768815 | 4.144798 | 12.821444 |
| released/idle-sparse | space-age | `lifecycle/physical-devices` | 1.674372 | 1.139391 | 4.541795 | 14.460508 |
| released/idle-sparse | space-age | `sample/logic-input` | 0.159665 | 0.017794 | 1.512341 | 3.248802 |
| released/idle-sparse | space-age | `notifications/monitor-events` | 0.003154 | 0.002570 | 0.005059 | 0.057089 |
| released/idle-sparse | space-age | `notifications/peripheral-topology` | 0.006783 | 0.006232 | 0.009268 | 0.029826 |
| released/idle-sparse | space-age | `render/device-status-art` | 0.216462 | 0.211663 | 0.243844 | 0.335158 |
| released/idle-sparse | space-age | `render/kv-reclamation` | 0.023951 | 0.023224 | 0.028555 | 0.046078 |
| released/idle-sparse | space-age | `render/monitor-world` | 0.975536 | 0.737940 | 2.385094 | 12.005128 |
| released/idle-sparse | space-age | `render/program-editor` | 0.000996 | 0.000746 | 0.002175 | 0.028725 |
| released/idle-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001383 | 0.000711 | 0.003387 | 0.063430 |
| prechange/idle-sparse | base | `lifecycle/00-physical-power-loss` | 0.946863 | 0.710128 | 2.125019 | 9.531865 |
| prechange/idle-sparse | base | `lifecycle/01-clone-components` | 0.001172 | 0.000912 | 0.001724 | 0.047431 |
| prechange/idle-sparse | base | `lifecycle/01-network-output-authority` | 0.044917 | 0.042216 | 0.063632 | 0.096292 |
| prechange/idle-sparse | base | `lifecycle/02-monitor-groups` | 2.158610 | 1.318824 | 6.510437 | 13.832030 |
| prechange/idle-sparse | base | `lifecycle/02-native-radar-adoption` | 1.134547 | 0.744082 | 4.017116 | 8.140533 |
| prechange/idle-sparse | base | `lifecycle/physical-devices` | 1.529339 | 1.105140 | 4.169656 | 14.275615 |
| prechange/idle-sparse | base | `sample/logic-input` | 0.151874 | 0.017223 | 1.302252 | 6.052966 |
| prechange/idle-sparse | base | `notifications/monitor-events` | 0.003066 | 0.002505 | 0.004498 | 0.053461 |
| prechange/idle-sparse | base | `notifications/peripheral-topology` | 0.006624 | 0.006061 | 0.009208 | 0.018365 |
| prechange/idle-sparse | base | `render/device-status-art` | 0.212381 | 0.208782 | 0.235600 | 0.350416 |
| prechange/idle-sparse | base | `render/kv-reclamation` | 0.024457 | 0.023615 | 0.030438 | 0.068250 |
| prechange/idle-sparse | base | `render/monitor-world` | 0.934224 | 0.705229 | 2.011334 | 7.772472 |
| prechange/idle-sparse | base | `render/program-editor` | 0.000994 | 0.000711 | 0.002194 | 0.042301 |
| prechange/idle-sparse | base | `render/ui-peripheral-inspectors` | 0.001067 | 0.000591 | 0.003276 | 0.043953 |
| prechange/idle-sparse | space-age | `lifecycle/00-physical-power-loss` | 1.060294 | 0.748311 | 2.384304 | 10.866709 |
| prechange/idle-sparse | space-age | `lifecycle/01-clone-components` | 0.001203 | 0.001087 | 0.001853 | 0.005830 |
| prechange/idle-sparse | space-age | `lifecycle/01-network-output-authority` | 0.045355 | 0.042241 | 0.064523 | 0.112485 |
| prechange/idle-sparse | space-age | `lifecycle/02-monitor-groups` | 2.419908 | 1.367065 | 7.675547 | 15.707464 |
| prechange/idle-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.239602 | 0.792385 | 4.525144 | 13.050380 |
| prechange/idle-sparse | space-age | `lifecycle/physical-devices` | 1.672667 | 1.180640 | 4.424342 | 11.617940 |
| prechange/idle-sparse | space-age | `sample/logic-input` | 0.185856 | 0.018255 | 1.602143 | 7.055646 |
| prechange/idle-sparse | space-age | `notifications/monitor-events` | 0.003053 | 0.002605 | 0.005120 | 0.013045 |
| prechange/idle-sparse | space-age | `notifications/peripheral-topology` | 0.007312 | 0.006672 | 0.010049 | 0.051878 |
| prechange/idle-sparse | space-age | `render/device-status-art` | 0.221604 | 0.214990 | 0.259845 | 0.364935 |
| prechange/idle-sparse | space-age | `render/kv-reclamation` | 0.024699 | 0.023805 | 0.029477 | 0.063561 |
| prechange/idle-sparse | space-age | `render/monitor-world` | 1.055145 | 0.754142 | 2.377520 | 9.726266 |
| prechange/idle-sparse | space-age | `render/program-editor` | 0.001012 | 0.000802 | 0.002314 | 0.004859 |
| prechange/idle-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001077 | 0.000661 | 0.003266 | 0.044104 |
| candidate/idle-sparse | base | `lifecycle/00-physical-power-loss` | 0.863806 | 0.610182 | 1.919919 | 8.526721 |
| candidate/idle-sparse | base | `lifecycle/01-clone-components` | 0.001033 | 0.000911 | 0.001483 | 0.009989 |
| candidate/idle-sparse | base | `lifecycle/01-network-output-authority` | 0.042906 | 0.041168 | 0.052911 | 0.087156 |
| candidate/idle-sparse | base | `lifecycle/02-monitor-groups` | 0.002271 | 0.002104 | 0.003206 | 0.008146 |
| candidate/idle-sparse | base | `lifecycle/02-native-radar-adoption` | 1.327045 | 0.757328 | 4.470709 | 11.286649 |
| candidate/idle-sparse | base | `lifecycle/physical-devices` | 0.213939 | 0.161543 | 0.537044 | 5.174021 |
| candidate/idle-sparse | base | `sample/logic-input` | 0.051671 | 0.015701 | 0.279072 | 0.768525 |
| candidate/idle-sparse | base | `notifications/monitor-events` | 0.003411 | 0.002405 | 0.004799 | 0.047441 |
| candidate/idle-sparse | base | `notifications/peripheral-topology` | 0.006514 | 0.006091 | 0.008345 | 0.021301 |
| candidate/idle-sparse | base | `render/device-status-art` | 0.077401 | 0.073661 | 0.095362 | 0.134948 |
| candidate/idle-sparse | base | `render/kv-reclamation` | 0.023884 | 0.022798 | 0.031470 | 0.053572 |
| candidate/idle-sparse | base | `render/monitor-world` | 0.009842 | 0.008567 | 0.012364 | 0.075624 |
| candidate/idle-sparse | base | `render/program-editor` | 0.000753 | 0.000601 | 0.002034 | 0.003767 |
| candidate/idle-sparse | base | `render/ui-peripheral-inspectors` | 0.000822 | 0.000551 | 0.002995 | 0.007474 |
| candidate/idle-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.985122 | 0.660128 | 2.191417 | 11.170808 |
| candidate/idle-sparse | space-age | `lifecycle/01-clone-components` | 0.001082 | 0.000971 | 0.001734 | 0.010269 |
| candidate/idle-sparse | space-age | `lifecycle/01-network-output-authority` | 0.043039 | 0.041145 | 0.054143 | 0.156578 |
| candidate/idle-sparse | space-age | `lifecycle/02-monitor-groups` | 0.002529 | 0.002139 | 0.004209 | 0.028835 |
| candidate/idle-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.590254 | 0.803311 | 5.821183 | 11.444268 |
| candidate/idle-sparse | space-age | `lifecycle/physical-devices` | 0.241415 | 0.174011 | 0.634208 | 9.346994 |
| candidate/idle-sparse | space-age | `sample/logic-input` | 0.054028 | 0.015750 | 0.242090 | 1.152055 |
| candidate/idle-sparse | space-age | `notifications/monitor-events` | 0.003742 | 0.002654 | 0.005862 | 0.064783 |
| candidate/idle-sparse | space-age | `notifications/peripheral-topology` | 0.006570 | 0.006102 | 0.009408 | 0.014958 |
| candidate/idle-sparse | space-age | `render/device-status-art` | 0.082964 | 0.075158 | 0.117023 | 0.648807 |
| candidate/idle-sparse | space-age | `render/kv-reclamation` | 0.024444 | 0.023124 | 0.033344 | 0.045658 |
| candidate/idle-sparse | space-age | `render/monitor-world` | 0.010691 | 0.008947 | 0.016501 | 0.065514 |
| candidate/idle-sparse | space-age | `render/program-editor` | 0.000765 | 0.000621 | 0.001894 | 0.003346 |
| candidate/idle-sparse | space-age | `render/ui-peripheral-inspectors` | 0.000860 | 0.000611 | 0.003126 | 0.005069 |
| released/one-sparse | base | `lifecycle/00-physical-power-loss` | 0.812426 | 0.698341 | 1.504737 | 4.923302 |
| released/one-sparse | base | `lifecycle/01-clone-components` | 0.001144 | 0.001032 | 0.001804 | 0.006652 |
| released/one-sparse | base | `lifecycle/01-network-output-authority` | 0.041567 | 0.039786 | 0.051208 | 0.110049 |
| released/one-sparse | base | `lifecycle/02-monitor-groups` | 1.946757 | 1.313708 | 4.852197 | 11.210224 |
| released/one-sparse | base | `lifecycle/02-native-radar-adoption` | 0.981689 | 0.725948 | 3.291974 | 7.542043 |
| released/one-sparse | base | `lifecycle/physical-devices` | 1.358108 | 1.081361 | 3.681396 | 8.199736 |
| released/one-sparse | base | `sample/logic-input` | 0.095445 | 0.016927 | 0.780368 | 3.475072 |
| released/one-sparse | base | `notifications/monitor-events` | 0.004131 | 0.002680 | 0.004889 | 0.206413 |
| released/one-sparse | base | `notifications/peripheral-topology` | 0.577533 | 0.434708 | 1.841228 | 5.017291 |
| released/one-sparse | base | `render/device-status-art` | 0.248651 | 0.229046 | 0.356038 | 0.688402 |
| released/one-sparse | base | `render/kv-reclamation` | 0.025466 | 0.023749 | 0.031921 | 0.088318 |
| released/one-sparse | base | `render/monitor-world` | 1.245489 | 1.129202 | 2.617037 | 7.840141 |
| released/one-sparse | base | `render/program-editor` | 0.000961 | 0.000721 | 0.002164 | 0.041759 |
| released/one-sparse | base | `render/ui-peripheral-inspectors` | 0.001022 | 0.000701 | 0.003337 | 0.054284 |
| released/one-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.848292 | 0.713901 | 1.680773 | 5.500682 |
| released/one-sparse | space-age | `lifecycle/01-clone-components` | 0.001252 | 0.001133 | 0.001884 | 0.014547 |
| released/one-sparse | space-age | `lifecycle/01-network-output-authority` | 0.042657 | 0.040778 | 0.051118 | 0.095141 |
| released/one-sparse | space-age | `lifecycle/02-monitor-groups` | 1.967654 | 1.334258 | 5.018243 | 9.104140 |
| released/one-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.036870 | 0.747109 | 4.157202 | 10.152076 |
| released/one-sparse | space-age | `lifecycle/physical-devices` | 1.364561 | 1.102181 | 3.694400 | 7.622797 |
| released/one-sparse | space-age | `sample/logic-input` | 0.094516 | 0.017358 | 0.694353 | 2.209331 |
| released/one-sparse | space-age | `notifications/monitor-events` | 0.004450 | 0.002785 | 0.005210 | 0.192397 |
| released/one-sparse | space-age | `notifications/peripheral-topology` | 0.590556 | 0.445955 | 1.803487 | 5.454283 |
| released/one-sparse | space-age | `render/device-status-art` | 0.236861 | 0.222600 | 0.317586 | 0.457552 |
| released/one-sparse | space-age | `render/kv-reclamation` | 0.024926 | 0.023545 | 0.031189 | 0.093589 |
| released/one-sparse | space-age | `render/monitor-world` | 1.243093 | 1.141827 | 2.472102 | 8.618914 |
| released/one-sparse | space-age | `render/program-editor` | 0.000984 | 0.000832 | 0.002325 | 0.004248 |
| released/one-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001057 | 0.000731 | 0.003507 | 0.037642 |
| prechange/one-sparse | base | `lifecycle/00-physical-power-loss` | 0.852808 | 0.693622 | 1.712685 | 6.023099 |
| prechange/one-sparse | base | `lifecycle/01-clone-components` | 0.001317 | 0.001112 | 0.001996 | 0.053202 |
| prechange/one-sparse | base | `lifecycle/01-network-output-authority` | 0.042078 | 0.039836 | 0.052200 | 0.098718 |
| prechange/one-sparse | base | `lifecycle/02-monitor-groups` | 1.884171 | 1.308539 | 4.947919 | 8.036585 |
| prechange/one-sparse | base | `lifecycle/02-native-radar-adoption` | 0.948379 | 0.723219 | 2.837788 | 5.642112 |
| prechange/one-sparse | base | `lifecycle/physical-devices` | 1.325698 | 1.075480 | 3.789461 | 6.517170 |
| prechange/one-sparse | base | `sample/logic-input` | 0.095923 | 0.016851 | 0.353614 | 3.934077 |
| prechange/one-sparse | base | `notifications/monitor-events` | 0.003653 | 0.002875 | 0.004700 | 0.140838 |
| prechange/one-sparse | base | `notifications/peripheral-topology` | 0.557467 | 0.431893 | 1.594439 | 4.961515 |
| prechange/one-sparse | base | `render/device-status-art` | 0.239789 | 0.223441 | 0.340490 | 0.420471 |
| prechange/one-sparse | base | `render/kv-reclamation` | 0.025018 | 0.023511 | 0.031350 | 0.092908 |
| prechange/one-sparse | base | `render/monitor-world` | 1.190835 | 1.129097 | 2.198520 | 7.252531 |
| prechange/one-sparse | base | `render/program-editor` | 0.001155 | 0.000857 | 0.002465 | 0.042771 |
| prechange/one-sparse | base | `render/ui-peripheral-inspectors` | 0.000861 | 0.000592 | 0.003396 | 0.010681 |
| prechange/one-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.906977 | 0.722156 | 2.093930 | 6.292532 |
| prechange/one-sparse | space-age | `lifecycle/01-clone-components` | 0.001271 | 0.001083 | 0.001853 | 0.036640 |
| prechange/one-sparse | space-age | `lifecycle/01-network-output-authority` | 0.042222 | 0.039661 | 0.055796 | 0.116112 |
| prechange/one-sparse | space-age | `lifecycle/02-monitor-groups` | 2.061095 | 1.340761 | 5.663894 | 12.318156 |
| prechange/one-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.010835 | 0.750185 | 3.256225 | 7.257560 |
| prechange/one-sparse | space-age | `lifecycle/physical-devices` | 1.417510 | 1.109665 | 4.432638 | 6.712954 |
| prechange/one-sparse | space-age | `sample/logic-input` | 0.109917 | 0.016948 | 0.843006 | 2.971733 |
| prechange/one-sparse | space-age | `notifications/monitor-events` | 0.004477 | 0.002716 | 0.004739 | 0.247131 |
| prechange/one-sparse | space-age | `notifications/peripheral-topology` | 0.600202 | 0.442283 | 2.147713 | 6.077312 |
| prechange/one-sparse | space-age | `render/device-status-art` | 0.247556 | 0.225559 | 0.340248 | 3.241497 |
| prechange/one-sparse | space-age | `render/kv-reclamation` | 0.024892 | 0.023385 | 0.030668 | 0.105702 |
| prechange/one-sparse | space-age | `render/monitor-world` | 1.261965 | 1.159781 | 2.481680 | 8.026615 |
| prechange/one-sparse | space-age | `render/program-editor` | 0.001174 | 0.000831 | 0.002285 | 0.056347 |
| prechange/one-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001141 | 0.000861 | 0.003647 | 0.011441 |
| candidate/one-sparse | base | `lifecycle/00-physical-power-loss` | 0.821638 | 0.604847 | 2.297990 | 5.654385 |
| candidate/one-sparse | base | `lifecycle/01-clone-components` | 0.001022 | 0.000897 | 0.001783 | 0.006062 |
| candidate/one-sparse | base | `lifecycle/01-network-output-authority` | 0.042772 | 0.041585 | 0.050416 | 0.077728 |
| candidate/one-sparse | base | `lifecycle/02-monitor-groups` | 0.002482 | 0.002265 | 0.003396 | 0.029527 |
| candidate/one-sparse | base | `lifecycle/02-native-radar-adoption` | 1.388495 | 0.747564 | 4.826789 | 8.079687 |
| candidate/one-sparse | base | `lifecycle/physical-devices` | 0.219904 | 0.156328 | 0.500504 | 2.894214 |
| candidate/one-sparse | base | `sample/logic-input` | 0.057244 | 0.016391 | 0.363031 | 0.975880 |
| candidate/one-sparse | base | `notifications/monitor-events` | 0.003741 | 0.002520 | 0.005209 | 0.072918 |
| candidate/one-sparse | base | `notifications/peripheral-topology` | 0.639294 | 0.439822 | 1.887517 | 4.389906 |
| candidate/one-sparse | base | `render/device-status-art` | 0.092109 | 0.083910 | 0.139697 | 0.215791 |
| candidate/one-sparse | base | `render/kv-reclamation` | 0.026595 | 0.024061 | 0.038172 | 0.088699 |
| candidate/one-sparse | base | `render/monitor-world` | 0.431372 | 0.281176 | 0.860239 | 7.528246 |
| candidate/one-sparse | base | `render/program-editor` | 0.000896 | 0.000662 | 0.002094 | 0.040807 |
| candidate/one-sparse | base | `render/ui-peripheral-inspectors` | 0.001074 | 0.000611 | 0.003276 | 0.068491 |
| candidate/one-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.781698 | 0.623803 | 1.675312 | 4.757004 |
| candidate/one-sparse | space-age | `lifecycle/01-clone-components` | 0.001025 | 0.000901 | 0.001643 | 0.011001 |
| candidate/one-sparse | space-age | `lifecycle/01-network-output-authority` | 0.042230 | 0.041229 | 0.048874 | 0.071326 |
| candidate/one-sparse | space-age | `lifecycle/02-monitor-groups` | 0.002565 | 0.002304 | 0.003677 | 0.031650 |
| candidate/one-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.190243 | 0.771315 | 3.810061 | 10.538304 |
| candidate/one-sparse | space-age | `lifecycle/physical-devices` | 0.196973 | 0.160000 | 0.248093 | 3.468280 |
| candidate/one-sparse | space-age | `sample/logic-input` | 0.029731 | 0.016141 | 0.024687 | 0.878354 |
| candidate/one-sparse | space-age | `notifications/monitor-events` | 0.003096 | 0.002475 | 0.004439 | 0.061437 |
| candidate/one-sparse | space-age | `notifications/peripheral-topology` | 0.517140 | 0.447418 | 0.628878 | 3.533153 |
| candidate/one-sparse | space-age | `render/device-status-art` | 0.097455 | 0.084788 | 0.163993 | 0.262410 |
| candidate/one-sparse | space-age | `render/kv-reclamation` | 0.025518 | 0.023786 | 0.032742 | 0.094390 |
| candidate/one-sparse | space-age | `render/monitor-world` | 0.559317 | 0.284026 | 2.911629 | 7.710483 |
| candidate/one-sparse | space-age | `render/program-editor` | 0.001079 | 0.000721 | 0.002275 | 0.046889 |
| candidate/one-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001185 | 0.000591 | 0.003406 | 0.047531 |
| released/all-sparse | base | `lifecycle/00-physical-power-loss` | 0.830104 | 0.693842 | 1.753181 | 5.521652 |
| released/all-sparse | base | `lifecycle/01-clone-components` | 0.001410 | 0.001182 | 0.002214 | 0.047951 |
| released/all-sparse | base | `lifecycle/01-network-output-authority` | 0.044014 | 0.041885 | 0.052079 | 0.119747 |
| released/all-sparse | base | `lifecycle/02-monitor-groups` | 1.890805 | 1.323362 | 3.987839 | 13.730757 |
| released/all-sparse | base | `lifecycle/02-native-radar-adoption` | 0.979014 | 0.733649 | 3.905223 | 5.381616 |
| released/all-sparse | base | `lifecycle/physical-devices` | 1.285640 | 1.082352 | 3.146807 | 6.083895 |
| released/all-sparse | base | `sample/logic-input` | 0.092335 | 0.017924 | 0.855140 | 2.492620 |
| released/all-sparse | base | `notifications/monitor-events` | 0.004006 | 0.002815 | 0.004618 | 0.210791 |
| released/all-sparse | base | `notifications/peripheral-topology` | 0.562161 | 0.435932 | 1.807093 | 4.513812 |
| released/all-sparse | base | `render/device-status-art` | 0.232556 | 0.225179 | 0.278510 | 0.356109 |
| released/all-sparse | base | `render/kv-reclamation` | 0.025454 | 0.024602 | 0.031079 | 0.075022 |
| released/all-sparse | base | `render/monitor-world` | 2.000288 | 2.219074 | 3.266464 | 18.524261 |
| released/all-sparse | base | `render/program-editor` | 0.001093 | 0.000881 | 0.002444 | 0.021522 |
| released/all-sparse | base | `render/ui-peripheral-inspectors` | 0.000950 | 0.000642 | 0.003436 | 0.017805 |
| released/all-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.875911 | 0.718935 | 1.828155 | 5.935069 |
| released/all-sparse | space-age | `lifecycle/01-clone-components` | 0.001304 | 0.001222 | 0.001994 | 0.009397 |
| released/all-sparse | space-age | `lifecycle/01-network-output-authority` | 0.041829 | 0.040356 | 0.048793 | 0.103097 |
| released/all-sparse | space-age | `lifecycle/02-monitor-groups` | 2.013147 | 1.350128 | 4.867876 | 10.428733 |
| released/all-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.017073 | 0.750851 | 3.789281 | 8.386051 |
| released/all-sparse | space-age | `lifecycle/physical-devices` | 1.440568 | 1.124970 | 4.398894 | 10.648642 |
| released/all-sparse | space-age | `sample/logic-input` | 0.094709 | 0.017413 | 0.565999 | 2.875140 |
| released/all-sparse | space-age | `notifications/monitor-events` | 0.003692 | 0.002905 | 0.005040 | 0.092877 |
| released/all-sparse | space-age | `notifications/peripheral-topology` | 0.610012 | 0.451425 | 1.950748 | 8.412943 |
| released/all-sparse | space-age | `render/device-status-art` | 0.235375 | 0.224753 | 0.290022 | 0.373421 |
| released/all-sparse | space-age | `render/kv-reclamation` | 0.024733 | 0.023300 | 0.030478 | 0.094290 |
| released/all-sparse | space-age | `render/monitor-world` | 2.291509 | 2.376980 | 4.348557 | 19.684623 |
| released/all-sparse | space-age | `render/program-editor` | 0.001121 | 0.000982 | 0.002344 | 0.003927 |
| released/all-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001603 | 0.001102 | 0.003907 | 0.078900 |
| prechange/all-sparse | base | `lifecycle/00-physical-power-loss` | 0.814002 | 0.700745 | 1.539153 | 4.307207 |
| prechange/all-sparse | base | `lifecycle/01-clone-components` | 0.001149 | 0.001051 | 0.001893 | 0.006192 |
| prechange/all-sparse | base | `lifecycle/01-network-output-authority` | 0.050144 | 0.042450 | 0.055074 | 3.417222 |
| prechange/all-sparse | base | `lifecycle/02-monitor-groups` | 1.922967 | 1.325481 | 4.608071 | 9.081556 |
| prechange/all-sparse | base | `lifecycle/02-native-radar-adoption` | 0.965368 | 0.732932 | 3.660106 | 6.020463 |
| prechange/all-sparse | base | `lifecycle/physical-devices` | 1.330780 | 1.086396 | 3.432572 | 9.692551 |
| prechange/all-sparse | base | `sample/logic-input` | 0.108009 | 0.018044 | 0.935333 | 2.308689 |
| prechange/all-sparse | base | `notifications/monitor-events` | 0.003826 | 0.002755 | 0.004799 | 0.193139 |
| prechange/all-sparse | base | `notifications/peripheral-topology` | 0.586812 | 0.436392 | 1.904930 | 4.036952 |
| prechange/all-sparse | base | `render/device-status-art` | 0.235057 | 0.227083 | 0.286365 | 0.413267 |
| prechange/all-sparse | base | `render/kv-reclamation` | 0.026354 | 0.025098 | 0.032442 | 0.095943 |
| prechange/all-sparse | base | `render/monitor-world` | 2.156032 | 2.272476 | 4.545383 | 18.123348 |
| prechange/all-sparse | base | `render/program-editor` | 0.001005 | 0.000801 | 0.002295 | 0.025609 |
| prechange/all-sparse | base | `render/ui-peripheral-inspectors` | 0.001105 | 0.000892 | 0.003456 | 0.004970 |
| prechange/all-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.872136 | 0.721780 | 1.793606 | 6.899177 |
| prechange/all-sparse | space-age | `lifecycle/01-clone-components` | 0.001295 | 0.001152 | 0.002084 | 0.031460 |
| prechange/all-sparse | space-age | `lifecycle/01-network-output-authority` | 0.044063 | 0.041259 | 0.052441 | 0.439347 |
| prechange/all-sparse | space-age | `lifecycle/02-monitor-groups` | 2.078350 | 1.358789 | 5.502346 | 10.307734 |
| prechange/all-sparse | space-age | `lifecycle/02-native-radar-adoption` | 0.994705 | 0.758450 | 3.386754 | 6.837680 |
| prechange/all-sparse | space-age | `lifecycle/physical-devices` | 1.421001 | 1.127328 | 4.176811 | 7.953656 |
| prechange/all-sparse | space-age | `sample/logic-input` | 0.090351 | 0.017848 | 0.619892 | 2.467893 |
| prechange/all-sparse | space-age | `notifications/monitor-events` | 0.004283 | 0.003196 | 0.005159 | 0.281918 |
| prechange/all-sparse | space-age | `notifications/peripheral-topology` | 0.601211 | 0.455323 | 1.907375 | 5.987361 |
| prechange/all-sparse | space-age | `render/device-status-art` | 0.237255 | 0.227017 | 0.300813 | 0.392168 |
| prechange/all-sparse | space-age | `render/kv-reclamation` | 0.025617 | 0.024091 | 0.032302 | 0.086113 |
| prechange/all-sparse | space-age | `render/monitor-world` | 2.282520 | 2.415203 | 4.427057 | 18.413682 |
| prechange/all-sparse | space-age | `render/program-editor` | 0.001178 | 0.000972 | 0.002525 | 0.027963 |
| prechange/all-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001150 | 0.000832 | 0.003447 | 0.062178 |
| candidate/all-sparse | base | `lifecycle/00-physical-power-loss` | 0.699500 | 0.588020 | 1.507062 | 3.810873 |
| candidate/all-sparse | base | `lifecycle/01-clone-components` | 0.001275 | 0.001082 | 0.002024 | 0.014507 |
| candidate/all-sparse | base | `lifecycle/01-network-output-authority` | 0.043854 | 0.042501 | 0.051579 | 0.088940 |
| candidate/all-sparse | base | `lifecycle/02-monitor-groups` | 0.002538 | 0.002314 | 0.003557 | 0.010139 |
| candidate/all-sparse | base | `lifecycle/02-native-radar-adoption` | 1.160944 | 0.733683 | 4.017826 | 6.059027 |
| candidate/all-sparse | base | `lifecycle/physical-devices` | 0.186138 | 0.156693 | 0.351620 | 3.677048 |
| candidate/all-sparse | base | `sample/logic-input` | 0.035581 | 0.016642 | 0.104851 | 0.686137 |
| candidate/all-sparse | base | `notifications/monitor-events` | 0.003339 | 0.002495 | 0.004369 | 0.059563 |
| candidate/all-sparse | base | `notifications/peripheral-topology` | 0.525976 | 0.434188 | 1.243269 | 3.543913 |
| candidate/all-sparse | base | `render/device-status-art` | 0.090582 | 0.084121 | 0.126902 | 0.180685 |
| candidate/all-sparse | base | `render/kv-reclamation` | 0.025918 | 0.024276 | 0.033033 | 0.096685 |
| candidate/all-sparse | base | `render/monitor-world` | 1.658364 | 1.007420 | 3.242769 | 16.513839 |
| candidate/all-sparse | base | `render/program-editor` | 0.000987 | 0.000771 | 0.002324 | 0.026009 |
| candidate/all-sparse | base | `render/ui-peripheral-inspectors` | 0.000977 | 0.000651 | 0.003286 | 0.018856 |
| candidate/all-sparse | space-age | `lifecycle/00-physical-power-loss` | 0.786705 | 0.627441 | 1.904138 | 4.655842 |
| candidate/all-sparse | space-age | `lifecycle/01-clone-components` | 0.001202 | 0.001053 | 0.001914 | 0.022293 |
| candidate/all-sparse | space-age | `lifecycle/01-network-output-authority` | 0.042554 | 0.041354 | 0.049795 | 0.078000 |
| candidate/all-sparse | space-age | `lifecycle/02-monitor-groups` | 0.002620 | 0.002404 | 0.003578 | 0.014427 |
| candidate/all-sparse | space-age | `lifecycle/02-native-radar-adoption` | 1.327871 | 0.794845 | 4.817862 | 7.303347 |
| candidate/all-sparse | space-age | `lifecycle/physical-devices` | 0.219238 | 0.163627 | 0.572651 | 3.982910 |
| candidate/all-sparse | space-age | `sample/logic-input` | 0.042306 | 0.016030 | 0.281357 | 0.828219 |
| candidate/all-sparse | space-age | `notifications/monitor-events` | 0.003932 | 0.002725 | 0.004609 | 0.116883 |
| candidate/all-sparse | space-age | `notifications/peripheral-topology` | 0.597538 | 0.459441 | 1.759823 | 4.365659 |
| candidate/all-sparse | space-age | `render/device-status-art` | 0.090947 | 0.083975 | 0.127412 | 0.372000 |
| candidate/all-sparse | space-age | `render/kv-reclamation` | 0.026088 | 0.023771 | 0.034025 | 0.092327 |
| candidate/all-sparse | space-age | `render/monitor-world` | 1.668689 | 1.086089 | 3.350184 | 15.643742 |
| candidate/all-sparse | space-age | `render/program-editor` | 0.001077 | 0.000902 | 0.002295 | 0.027964 |
| candidate/all-sparse | space-age | `render/ui-peripheral-inspectors` | 0.001141 | 0.000691 | 0.003346 | 0.051658 |
| released/all-full-blit | base | `lifecycle/00-physical-power-loss` | 0.855451 | 0.708285 | 1.780213 | 5.864626 |
| released/all-full-blit | base | `lifecycle/01-clone-components` | 0.001309 | 0.001143 | 0.002013 | 0.018013 |
| released/all-full-blit | base | `lifecycle/01-network-output-authority` | 0.043752 | 0.041970 | 0.050547 | 0.108576 |
| released/all-full-blit | base | `lifecycle/02-monitor-groups` | 2.017592 | 1.348530 | 5.184260 | 14.735823 |
| released/all-full-blit | base | `lifecycle/02-native-radar-adoption` | 0.985018 | 0.739604 | 3.612214 | 5.892309 |
| released/all-full-blit | base | `lifecycle/physical-devices` | 1.350978 | 1.093364 | 3.746210 | 8.914158 |
| released/all-full-blit | base | `sample/logic-input` | 0.116965 | 0.018530 | 0.974698 | 4.072040 |
| released/all-full-blit | base | `notifications/monitor-events` | 0.004967 | 0.003327 | 0.005811 | 0.242523 |
| released/all-full-blit | base | `notifications/peripheral-topology` | 0.602813 | 0.439943 | 1.923054 | 5.896648 |
| released/all-full-blit | base | `render/device-status-art` | 0.239564 | 0.229121 | 0.298248 | 0.408999 |
| released/all-full-blit | base | `render/kv-reclamation` | 0.031570 | 0.024497 | 0.032582 | 3.508736 |
| released/all-full-blit | base | `render/monitor-world` | 2.156601 | 2.357353 | 3.823977 | 18.131463 |
| released/all-full-blit | base | `render/program-editor` | 0.001164 | 0.000882 | 0.002555 | 0.041679 |
| released/all-full-blit | base | `render/ui-peripheral-inspectors` | 0.001205 | 0.000922 | 0.003827 | 0.010180 |
| released/all-full-blit | space-age | `lifecycle/00-physical-power-loss` | 0.891986 | 0.734490 | 1.855766 | 6.450122 |
| released/all-full-blit | space-age | `lifecycle/01-clone-components` | 0.001252 | 0.001162 | 0.001873 | 0.016862 |
| released/all-full-blit | space-age | `lifecycle/01-network-output-authority` | 0.044443 | 0.042451 | 0.052008 | 0.114860 |
| released/all-full-blit | space-age | `lifecycle/02-monitor-groups` | 2.074189 | 1.365067 | 5.214707 | 11.940696 |
| released/all-full-blit | space-age | `lifecycle/02-native-radar-adoption` | 0.968406 | 0.769661 | 2.622147 | 5.987320 |
| released/all-full-blit | space-age | `lifecycle/physical-devices` | 1.415934 | 1.142457 | 4.289604 | 12.640107 |
| released/all-full-blit | space-age | `sample/logic-input` | 0.094069 | 0.018434 | 0.314149 | 2.821697 |
| released/all-full-blit | space-age | `notifications/monitor-events` | 0.003155 | 0.002645 | 0.004649 | 0.088158 |
| released/all-full-blit | space-age | `notifications/peripheral-topology` | 0.586830 | 0.455664 | 1.786124 | 5.366538 |
| released/all-full-blit | space-age | `render/device-status-art` | 0.235407 | 0.225389 | 0.290995 | 0.417124 |
| released/all-full-blit | space-age | `render/kv-reclamation` | 0.025800 | 0.024752 | 0.032682 | 0.072127 |
| released/all-full-blit | space-age | `render/monitor-world` | 2.266360 | 2.353039 | 4.584366 | 17.931892 |
| released/all-full-blit | space-age | `render/program-editor` | 0.001140 | 0.000931 | 0.002355 | 0.036639 |
| released/all-full-blit | space-age | `render/ui-peripheral-inspectors` | 0.001096 | 0.000782 | 0.003487 | 0.038793 |
| prechange/all-full-blit | base | `lifecycle/00-physical-power-loss` | 0.854228 | 0.702750 | 1.830087 | 5.081513 |
| prechange/all-full-blit | base | `lifecycle/01-clone-components` | 0.001361 | 0.001158 | 0.002054 | 0.037090 |
| prechange/all-full-blit | base | `lifecycle/01-network-output-authority` | 0.044430 | 0.042500 | 0.051699 | 0.104810 |
| prechange/all-full-blit | base | `lifecycle/02-monitor-groups` | 1.919819 | 1.334844 | 4.361322 | 11.914466 |
| prechange/all-full-blit | base | `lifecycle/02-native-radar-adoption` | 0.968676 | 0.730998 | 3.606224 | 5.483901 |
| prechange/all-full-blit | base | `lifecycle/physical-devices` | 1.304292 | 1.081876 | 3.258560 | 6.502532 |
| prechange/all-full-blit | base | `sample/logic-input` | 0.116280 | 0.017273 | 0.901587 | 9.062962 |
| prechange/all-full-blit | base | `notifications/monitor-events` | 0.003655 | 0.002995 | 0.005190 | 0.143934 |
| prechange/all-full-blit | base | `notifications/peripheral-topology` | 0.569274 | 0.437153 | 1.666275 | 4.963258 |
| prechange/all-full-blit | base | `render/device-status-art` | 0.237041 | 0.225720 | 0.299381 | 0.380004 |
| prechange/all-full-blit | base | `render/kv-reclamation` | 0.026215 | 0.024897 | 0.032622 | 0.085362 |
| prechange/all-full-blit | base | `render/monitor-world` | 2.096572 | 2.247002 | 3.490471 | 16.552994 |
| prechange/all-full-blit | base | `render/program-editor` | 0.001124 | 0.000892 | 0.002565 | 0.032742 |
| prechange/all-full-blit | base | `render/ui-peripheral-inspectors` | 0.001118 | 0.000863 | 0.003527 | 0.018545 |
| prechange/all-full-blit | space-age | `lifecycle/00-physical-power-loss` | 0.847851 | 0.717031 | 1.755807 | 5.191854 |
| prechange/all-full-blit | space-age | `lifecycle/01-clone-components` | 0.001263 | 0.001152 | 0.001944 | 0.022804 |
| prechange/all-full-blit | space-age | `lifecycle/01-network-output-authority` | 0.047703 | 0.040598 | 0.049604 | 3.501392 |
| prechange/all-full-blit | space-age | `lifecycle/02-monitor-groups` | 1.977506 | 1.347573 | 4.117867 | 12.678751 |
| prechange/all-full-blit | space-age | `lifecycle/02-native-radar-adoption` | 0.964281 | 0.749503 | 2.243656 | 6.947670 |
| prechange/all-full-blit | space-age | `lifecycle/physical-devices` | 1.356187 | 1.122815 | 3.675163 | 6.525485 |
| prechange/all-full-blit | space-age | `sample/logic-input` | 0.069519 | 0.017203 | 0.129748 | 2.035630 |
| prechange/all-full-blit | space-age | `notifications/monitor-events` | 0.003583 | 0.002706 | 0.004599 | 0.169903 |
| prechange/all-full-blit | space-age | `notifications/peripheral-topology` | 0.600614 | 0.447783 | 1.796403 | 5.294109 |
| prechange/all-full-blit | space-age | `render/device-status-art` | 0.231179 | 0.222148 | 0.289361 | 0.378921 |
| prechange/all-full-blit | space-age | `render/kv-reclamation` | 0.025081 | 0.023655 | 0.031380 | 0.091635 |
| prechange/all-full-blit | space-age | `render/monitor-world` | 2.200207 | 2.389981 | 3.530007 | 17.457980 |
| prechange/all-full-blit | space-age | `render/program-editor` | 0.001057 | 0.000832 | 0.002274 | 0.029486 |
| prechange/all-full-blit | space-age | `render/ui-peripheral-inspectors` | 0.001082 | 0.000831 | 0.003537 | 0.009158 |
| candidate/all-full-blit | base | `lifecycle/00-physical-power-loss` | 0.704616 | 0.593737 | 1.538171 | 4.000072 |
| candidate/all-full-blit | base | `lifecycle/01-clone-components` | 0.001134 | 0.000941 | 0.001765 | 0.020859 |
| candidate/all-full-blit | base | `lifecycle/01-network-output-authority` | 0.044257 | 0.043418 | 0.049123 | 0.123034 |
| candidate/all-full-blit | base | `lifecycle/02-monitor-groups` | 0.002536 | 0.002404 | 0.003457 | 0.011042 |
| candidate/all-full-blit | base | `lifecycle/02-native-radar-adoption` | 1.146563 | 0.733509 | 3.428875 | 5.956811 |
| candidate/all-full-blit | base | `lifecycle/physical-devices` | 0.191014 | 0.154885 | 0.279161 | 3.170914 |
| candidate/all-full-blit | base | `sample/logic-input` | 0.031250 | 0.016766 | 0.028443 | 0.808862 |
| candidate/all-full-blit | base | `notifications/monitor-events` | 0.003662 | 0.002665 | 0.004599 | 0.066336 |
| candidate/all-full-blit | base | `notifications/peripheral-topology` | 0.518180 | 0.431487 | 0.989936 | 4.709806 |
| candidate/all-full-blit | base | `render/device-status-art` | 0.093447 | 0.086850 | 0.133053 | 0.204760 |
| candidate/all-full-blit | base | `render/kv-reclamation` | 0.026476 | 0.024832 | 0.032792 | 0.106132 |
| candidate/all-full-blit | base | `render/monitor-world` | 1.605475 | 1.057190 | 5.632455 | 12.982701 |
| candidate/all-full-blit | base | `render/program-editor` | 0.001048 | 0.000832 | 0.002284 | 0.024527 |
| candidate/all-full-blit | base | `render/ui-peripheral-inspectors` | 0.001001 | 0.000691 | 0.003226 | 0.022643 |
| candidate/all-full-blit | space-age | `lifecycle/00-physical-power-loss` | 0.790161 | 0.634154 | 1.878651 | 7.129506 |
| candidate/all-full-blit | space-age | `lifecycle/01-clone-components` | 0.001200 | 0.001062 | 0.002134 | 0.006442 |
| candidate/all-full-blit | space-age | `lifecycle/01-network-output-authority` | 0.044493 | 0.043207 | 0.051569 | 0.074753 |
| candidate/all-full-blit | space-age | `lifecycle/02-monitor-groups` | 0.002635 | 0.002425 | 0.003767 | 0.014327 |
| candidate/all-full-blit | space-age | `lifecycle/02-native-radar-adoption` | 1.287517 | 0.789389 | 4.360850 | 9.700756 |
| candidate/all-full-blit | space-age | `lifecycle/physical-devices` | 0.206063 | 0.166928 | 0.469345 | 3.704098 |
| candidate/all-full-blit | space-age | `sample/logic-input` | 0.032628 | 0.016307 | 0.136810 | 0.637125 |
| candidate/all-full-blit | space-age | `notifications/monitor-events` | 0.003792 | 0.002685 | 0.005080 | 0.127744 |
| candidate/all-full-blit | space-age | `notifications/peripheral-topology` | 0.577215 | 0.460407 | 1.482454 | 4.043645 |
| candidate/all-full-blit | space-age | `render/device-status-art` | 0.099045 | 0.089852 | 0.137081 | 1.358328 |
| candidate/all-full-blit | space-age | `render/kv-reclamation` | 0.027771 | 0.025083 | 0.034596 | 0.369124 |
| candidate/all-full-blit | space-age | `render/monitor-world` | 1.844922 | 1.053993 | 6.409284 | 16.430551 |
| candidate/all-full-blit | space-age | `render/program-editor` | 0.001245 | 0.000877 | 0.002394 | 0.047491 |
| candidate/all-full-blit | space-age | `render/ui-peripheral-inspectors` | 0.000948 | 0.000641 | 0.003326 | 0.037881 |

Hook attribution covers registered lifecycle/sample/notification/render hooks; guest dispatch and scheduler orchestration are outside individual hook profiles. The physical observation residual is deliberately retained. Negative or adverse tail differences in the tables are observations, not grounds to invent a higher budget or a new acceptance threshold.
