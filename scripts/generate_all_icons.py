import os
from PIL import Image, ImageDraw

# Base vector coordinates in 1024x1024 master
pts_1024 = [
    (579.8, 225.6),
    (379.6, 549.0),
    (541.3, 549.0),
    (441.2, 810.8),
    (703.0, 441.2),
    (541.3, 441.2),
]

def make_icon(size, bg_color, bolt_color, is_rounded=False, radius_ratio=0.22):
    scale = 4
    canvas_size = size * scale
    im = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    
    if bg_color is not None:
        if is_rounded:
            r = int(canvas_size * radius_ratio)
            draw.rounded_rectangle([0, 0, canvas_size - 1, canvas_size - 1], radius=r, fill=bg_color)
        else:
            draw.rectangle([0, 0, canvas_size, canvas_size], fill=bg_color)
            
    scaled_pts = [(p[0] / 1024.0 * canvas_size, p[1] / 1024.0 * canvas_size) for p in pts_1024]
    draw.polygon(scaled_pts, fill=bolt_color)
    
    return im.resize((size, size), Image.Resampling.LANCZOS)

# 1. Master PNG assets (1024x1024)
icon_full = make_icon(1024, (13, 13, 13, 255), (255, 214, 0, 255), is_rounded=True)
icon_full.save('assets/icon.png', 'PNG')

icon_fg = make_icon(1024, None, (255, 214, 0, 255))
icon_fg.save('assets/icon_foreground.png', 'PNG')

icon_mono = make_icon(1024, None, (255, 255, 255, 255))
icon_mono.save('assets/icon_monochrome.png', 'PNG')

# 2. Legacy fallback mipmap icons (with rounded background)
mipmap_sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
}

for path, sz in mipmap_sizes.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = make_icon(sz, (13, 13, 13, 255), (255, 214, 0, 255), is_rounded=True)
    img.save(path, 'PNG')

# 3. Windows Multi-Resolution ICO
ico_layers = [make_icon(s, (13, 13, 13, 255), (255, 214, 0, 255), is_rounded=True) for s in [16, 32, 48, 64, 128, 256]]
ico_layers[0].save(
    'windows/runner/resources/app_icon.ico',
    format='ICO',
    sizes=[(s, s) for s in [16, 32, 48, 64, 128, 256]],
    append_images=ico_layers[1:]
)

print('All PNG and ICO assets successfully generated at maximum supersampled sharpness!')
