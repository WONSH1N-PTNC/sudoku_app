# 크레이지 아케이드 스프라이트

이 폴더에 이미지를 넣으면 게임이 자동으로 그것을 씁니다.
파일이 없으면 코드로 그리는 기본 아트가 그대로 쓰이므로, 비어 있어도 게임은 정상 동작합니다.

## 넣는 방법

1. 아래 파일 이름으로 PNG를 이 폴더에 넣습니다.
2. 스프라이트 시트(여러 프레임이 한 장에 붙은 이미지)라면
   `lib/features/crazyarcade/presentation/sprites/sprite_library.dart`의
   `kSpriteManifest`에서 그 항목의 `columns`(가로 프레임 수)와 `rows`(세로 줄 수)를 맞춰 줍니다.
3. 다시 실행하면 적용됩니다.

## 파일 목록

| 파일 | 쓰임 | 비고 |
|---|---|---|
| `ground.png` | 바닥 타일 | 한 칸 |
| `wall.png` | 부술 수 없는 벽 | 한 칸 |
| `box.png` | 부술 수 있는 상자 | 한 칸 |
| `balloon.png` | 물풍선 | 가로로 프레임을 이으면 애니메이션 |
| `explosion.png` | 폭발 불꽃 | 가로로 프레임을 이으면 애니메이션 |
| `character.png` | 캐릭터 | 아래 설명 참고 |
| `item_power.png` | 위력 증가 | 한 칸 |
| `item_count.png` | 개수 증가 | 한 칸 |
| `item_speed.png` | 속도 증가 | 한 칸 |

### 캐릭터 시트 배치

세로 줄(row)이 바라보는 방향, 가로 칸(column)이 걷는 동작입니다.

```
row 0 : 아래를 볼 때
row 1 : 왼쪽을 볼 때
row 2 : 오른쪽을 볼 때
row 3 : 위를 볼 때
```

줄이 하나뿐이면 방향과 무관하게 같은 그림을 씁니다.

## 라이선스 주의

넣는 이미지는 **직접 만들었거나 사용 권한이 있는 것**이어야 합니다.
이 프로젝트는 GitHub Pages로 공개 배포되므로 개인 소장과 달리 공중송신에 해당합니다.

권장 출처
- <https://kenney.nl> — CC0, 출처 표기도 필요 없음
- <https://game-icons.net> — CC BY 3.0, 아이템 아이콘에 적합
- <https://opengameart.org> — CC0 필터로 검색

CC BY 계열을 쓴다면 저장소 README에 출처를 남겨 주세요.
