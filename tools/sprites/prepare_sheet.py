"""쇼케이스용 캐릭터 시트를 게임에서 쓸 수 있는 스프라이트 시트로 정리한다.

이런 시트는 보통 그대로 쓸 수 없다.
- 위쪽에 제목 띠가 있고, 각 줄 가운데에 설명 글자가 프레임 사이에 끼어 있다.
- 배경이 투명이 아니라 모눈종이라 캐릭터 뒤에 사각형이 그대로 보인다.
- 원본 해상도가 과해 웹 번들이 수 MB씩 커진다.

이 스크립트는 프레임 위치를 찾아 배경을 투명하게 만들고 균일한 격자로 다시 깐다.

사용법:
    python tools/sprites/prepare_sheet.py <입력.png> <출력.png> [--cell 96]
"""

import argparse
import sys
from collections import deque

try:
    from PIL import Image
    import numpy as np
except ImportError:
    sys.exit("Pillow와 numpy가 필요합니다: pip install pillow numpy")

# 배경(흰 바탕)과 캐릭터를 가르는 밝기 기준
BACKGROUND_MIN_CHANNEL = 165

# 모눈선은 옅은 파랑이라 흰 바탕보다 어둡다. 캐릭터는 따뜻한 색이라
# 파랑이 빨강보다 크지 않으므로, 이 조건으로 선만 골라낼 수 있다.
GRID_LINE_MIN_CHANNEL = 140
GRID_LINE_BLUE_BIAS = 12

COLUMNS = 8
ROWS = 4

# 캐릭터로 인정할 최소 세로 길이 (줄 높이 대비 비율).
# 줄 가운데 설명 글자는 캐릭터보다 훨씬 납작해서 이 기준으로 걸러진다.
MIN_FRAME_HEIGHT_RATIO = 0.4


def find_bands(values, threshold, min_length):
    """값이 threshold를 넘는 구간들을 찾는다."""
    bands, start = [], None
    for i, value in enumerate(values):
        if value > threshold and start is None:
            start = i
        elif value <= threshold and start is not None:
            bands.append((start, i - 1))
            start = None
    if start is not None:
        bands.append((start, len(values) - 1))
    return [b for b in bands if b[1] - b[0] > min_length]


def is_background(pixel):
    r, g, b = int(pixel[0]), int(pixel[1]), int(pixel[2])
    if min(r, g, b) > BACKGROUND_MIN_CHANNEL:
        return True
    return b > r + GRID_LINE_BLUE_BIAS and min(r, g, b) > GRID_LINE_MIN_CHANNEL


def background_mask(rgb):
    """이미지 전체에 대한 배경 판정 (밴드 검출용)."""
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lowest = rgb.min(axis=2)
    return (lowest > BACKGROUND_MIN_CHANNEL) | (
        (b > r + GRID_LINE_BLUE_BIAS) & (lowest > GRID_LINE_MIN_CHANNEL)
    )


def clear_background(crop):
    """테두리에서 이어진 배경만 투명하게 만든다.

    캐릭터는 검은 외곽선으로 둘러싸여 있으므로, 밝은 배가 있어도
    바깥에서 흘러든 채우기가 외곽선에서 멈춰 내부는 보존된다.
    """
    height, width = crop.shape[:2]
    visited = np.zeros((height, width), bool)
    queue = deque()

    for x in range(width):
        for y in (0, height - 1):
            if not visited[y, x] and is_background(crop[y, x]):
                visited[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if not visited[y, x] and is_background(crop[y, x]):
                visited[y, x] = True
                queue.append((y, x))

    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width:
                if not visited[ny, nx] and is_background(crop[ny, nx]):
                    visited[ny, nx] = True
                    queue.append((ny, nx))

    crop[visited, 3] = 0
    return crop


def find_frame_columns(content, title_height, height):
    """캐릭터가 서 있는 열만 찾는다.

    줄 가운데의 설명 글자도 어두운 픽셀이라 밝기만으로는 캐릭터와 구분되지 않는다.
    대신 세로로 얼마나 긴지를 본다. 글자는 납작하고 캐릭터는 줄 높이를 거의 채운다.
    """
    row_height = (height - title_height) / ROWS
    is_frame_column = np.zeros(content.shape[1], bool)

    for row in range(ROWS):
        y0 = int(title_height + row * row_height)
        y1 = int(title_height + (row + 1) * row_height)
        block = content[y0:y1]
        for x in range(content.shape[1]):
            filled = np.where(block[:, x])[0]
            if filled.size == 0:
                continue
            extent = filled[-1] - filled[0]
            if extent >= MIN_FRAME_HEIGHT_RATIO * (y1 - y0):
                is_frame_column[x] = True

    return find_bands(is_frame_column.astype(int), 0, 15)


def prepare(source_path, output_path, cell_size, title_height):
    image = Image.open(source_path).convert("RGBA")

    rgb = np.asarray(image.convert("RGB")).astype(int)
    content = ~background_mask(rgb)
    content[:title_height, :] = False

    columns = find_frame_columns(content, title_height, image.height)
    if len(columns) != COLUMNS:
        sys.exit(f"열을 {COLUMNS}개 찾지 못했습니다 (찾은 수: {len(columns)}). "
                 f"--title 값을 조정해 보세요.")

    # 캐릭터가 있는 열 바깥은 제목이든 설명 글자든 전부 지운다.
    # 마스크에서만 빼면 잘라낼 때 글자가 그대로 딸려 들어온다.
    pixels = np.array(image)
    pixels[:title_height, :] = (255, 255, 255, 255)
    keep = np.zeros(image.width, bool)
    for c0, c1 in columns:
        keep[c0:c1 + 1] = True
    pixels[:, ~keep] = (255, 255, 255, 255)
    image = Image.fromarray(pixels)

    # 줄은 서로 붙어 검출되는 일이 잦아, 스프라이트 영역을 균등하게 나눈다.
    top, bottom = title_height, image.height
    row_height = (bottom - top) / ROWS

    frames = []
    for row in range(ROWS):
        y0, y1 = int(top + row * row_height), int(top + (row + 1) * row_height)
        for c0, c1 in columns:
            cell = content[y0:y1, c0:c1 + 1]
            rows_with_content = np.where(cell.any(axis=1))[0]
            if rows_with_content.size == 0:
                sys.exit(f"({row}, {c0}) 칸에서 그림을 찾지 못했습니다.")
            pad = 10
            fy0 = max(y0, y0 + rows_with_content[0] - pad)
            fy1 = min(y1, y0 + rows_with_content[-1] + pad)
            fx0, fx1 = max(0, c0 - pad), min(image.width, c1 + pad)
            crop = np.array(image.crop((fx0, fy0, fx1, fy1)))
            frames.append(Image.fromarray(clear_background(crop)))

    source_cell = max(max(f.size) for f in frames)
    sheet = Image.new("RGBA", (cell_size * COLUMNS, cell_size * ROWS), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        canvas = Image.new("RGBA", (source_cell, source_cell), (0, 0, 0, 0))
        canvas.paste(frame, ((source_cell - frame.width) // 2,
                             (source_cell - frame.height) // 2))
        canvas = canvas.resize((cell_size, cell_size), Image.LANCZOS)
        sheet.paste(canvas, ((index % COLUMNS) * cell_size,
                             (index // COLUMNS) * cell_size))

    sheet.save(output_path, optimize=True)
    print(f"{output_path}: {sheet.size[0]}x{sheet.size[1]} "
          f"({COLUMNS}칸 x {ROWS}줄), 원본 프레임 {source_cell}px")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--cell", type=int, default=96, help="출력 프레임 한 변 (기본 96)")
    parser.add_argument("--title", type=int, default=290, help="제목 띠 높이")
    args = parser.parse_args()
    prepare(args.source, args.output, args.cell, args.title)


if __name__ == "__main__":
    main()
