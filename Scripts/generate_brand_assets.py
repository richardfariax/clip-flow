#!/usr/bin/env python3
"""Generate ClipFlow raster assets from the transparent master mark."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSET_ROOT = PROJECT_ROOT / "ClipFlow" / "Resources" / "Assets.xcassets"
MARK_PATH = ASSET_ROOT / "ClipFlowMark.imageset" / "clipflow-mark.png"
MENU_BAR_ROOT = ASSET_ROOT / "ClipFlowMenuBarIcon.imageset"
APP_ICON_ROOT = ASSET_ROOT / "AppIcon.appiconset"

APP_ICON_SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def crop_to_alpha(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"The master mark has no visible pixels: {MARK_PATH}")
    return image.crop(bounds)


def vertical_gradient(size: int) -> Image.Image:
    top = (38, 122, 246, 255)
    bottom = (100, 55, 225, 255)
    gradient = Image.new("RGBA", (size, size))
    pixels = gradient.load()

    for y in range(size):
        progress = y / max(size - 1, 1)
        for x in range(size):
            diagonal = min(max(progress * 0.72 + (x / max(size - 1, 1)) * 0.28, 0), 1)
            pixels[x, y] = tuple(
                round(start + (end - start) * diagonal)
                for start, end in zip(top, bottom)
            )
    return gradient


def make_app_icon(mark: Image.Image, size: int = 1024) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile_inset = round(size * 0.07)
    tile_bounds = (
        tile_inset,
        tile_inset,
        size - tile_inset,
        size - tile_inset,
    )
    tile_size = tile_bounds[2] - tile_bounds[0]
    corner_radius = round(tile_size * 0.225)

    shadow_mask = Image.new("L", (size, size), 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.rounded_rectangle(
        (tile_bounds[0], tile_bounds[1] + round(size * 0.02), tile_bounds[2], tile_bounds[3]),
        radius=corner_radius,
        fill=155,
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(round(size * 0.035)))
    shadow = Image.new("RGBA", (size, size), (12, 18, 42, 0))
    shadow.putalpha(shadow_mask)
    canvas.alpha_composite(shadow)

    tile_mask = Image.new("L", (size, size), 0)
    tile_draw = ImageDraw.Draw(tile_mask)
    tile_draw.rounded_rectangle(tile_bounds, radius=corner_radius, fill=255)
    tile = vertical_gradient(size)
    tile.putalpha(tile_mask)
    canvas.alpha_composite(tile)

    highlight = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    highlight_mask = Image.new("L", (size, size), 0)
    highlight_draw = ImageDraw.Draw(highlight_mask)
    highlight_draw.rounded_rectangle(
        tuple(value + offset for value, offset in zip(tile_bounds, (2, 2, -2, -2))),
        radius=max(corner_radius - 2, 0),
        outline=72,
        width=max(round(size * 0.003), 1),
    )
    highlight.putalpha(highlight_mask)
    canvas.alpha_composite(highlight)

    target_height = round(tile_size * 0.61)
    target_width = round(mark.width * target_height / mark.height)
    resized_mark = mark.resize((target_width, target_height), Image.Resampling.LANCZOS)
    mark_alpha = resized_mark.getchannel("A")
    white_mark = Image.new("RGBA", resized_mark.size, (255, 255, 255, 255))
    white_mark.putalpha(mark_alpha)
    mark_position = (
        round((size - target_width) / 2),
        round((size - target_height) / 2 + size * 0.012),
    )
    canvas.alpha_composite(white_mark, mark_position)
    return canvas


def make_menu_bar_icon(mark: Image.Image, size: int) -> Image.Image:
    render_scale = 4
    canvas_size = size * render_scale
    target_height = round(size * 0.84 * render_scale)
    target_width = round(mark.width * target_height / mark.height)
    alpha = mark.getchannel("A").resize(
        (target_width, target_height),
        Image.Resampling.LANCZOS,
    )
    high_resolution = Image.new("L", (canvas_size, canvas_size), 0)
    position = (
        round((canvas_size - target_width) / 2),
        round((canvas_size - target_height) / 2),
    )
    high_resolution.paste(alpha, position)
    final_alpha = high_resolution.resize((size, size), Image.Resampling.LANCZOS)

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    icon.putalpha(final_alpha)
    return icon


def main() -> None:
    mark = crop_to_alpha(Image.open(MARK_PATH).convert("RGBA"))
    app_icon = make_app_icon(mark)

    for filename, size in APP_ICON_SIZES.items():
        resized = app_icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(APP_ICON_ROOT / filename, optimize=True)

    make_menu_bar_icon(mark, 18).save(
        MENU_BAR_ROOT / "clipflow-menubar.png",
        optimize=True,
    )
    make_menu_bar_icon(mark, 36).save(
        MENU_BAR_ROOT / "clipflow-menubar@2x.png",
        optimize=True,
    )


if __name__ == "__main__":
    main()
