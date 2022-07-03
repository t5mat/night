import io
from pathlib import Path
import configparser

from matplotlib import pyplot as plt


TOTAL = 32
GREYS = 8

COLORMAPS = [
    'CMRmap',
    'cubehelix',
    'gist_earth',
    'gist_ncar',
    'gist_rainbow',
    'jet',
    'nipy_spectral',
    'ocean',
    'turbo',
    'twilight',
]


def main():
    path = Path.cwd()
    for colormap in COLORMAPS:
        colors = generate_colormap_colors('binary_r', GREYS) + generate_colormap_colors(colormap, TOTAL - GREYS)

        filename = f'{TOTAL}-{colormap}.ini'
        data = generate_colors_file_contents(colors)
        (path / filename).write_text(data, newline='')


def generate_colors_file_contents(colors: list[tuple]) -> str:
    config = configparser.ConfigParser()
    config['Colors'] = {i + 1: f'#{bytes(color[:-1]).hex()}' for i, color in enumerate(colors)}

    data = io.StringIO()
    config.write(data)
    return data.getvalue().strip()


def generate_colormap_colors(colormap: str, count: int) -> list[tuple]:
    colormap = plt.get_cmap(colormap)
    return [colormap(i / (count - 1), bytes=True) for i in range(count)]


if __name__ == '__main__':
    main()
