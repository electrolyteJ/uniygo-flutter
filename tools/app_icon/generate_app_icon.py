#!/usr/bin/env python3
"""UniYGO Pro 应用图标生成器（B2 标准版：碰撞对角 + 双色对阵 + 中央闪电）。

用法：
    python3 tools/app_icon/generate_app_icon.py

从 1024 设计空间程序化渲染（PIL，2048 超采样降采样抗锯齿），
幂等覆盖 apps/uniygopro 下全部平台图标：
  iOS / macOS AppIcon.appiconset、Android mipmap + 自适应图标、
  Web icons + favicon、Windows app_icon.ico。

设计稿与决策见 docs/superpowers/specs/2026-08-21-uniygopro-app-icon-design.md
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# ── 设计常量（1024 设计空间） ──────────────────────────────────────
D = 1024          # 设计空间
S = 2             # 超采样倍率
BG_TOP = (16, 26, 48)       # #101A30
BG_BOTTOM = (6, 9, 16)      # #060910
BG_SOLID = (11, 17, 32)     # #0B1120（自适应图标背景）
CYAN = (0, 240, 255)        # #00F0FF 我方
AMBER = (255, 179, 0)       # #FFB300 对手
SLAB_FILL_CYAN = (14, 24, 48)    # #0E1830
SLAB_FILL_AMBER = (28, 21, 10)   # #1C150A
BOLT_FILL = (242, 251, 255)      # #F2FBFF
BOLT_EDGE = (189, 243, 255)      # #BDF3FF

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps' / 'uniygopro'

# 板块矩形（1024 空间，未旋转）：(x, y, w, h, center)
SLAB_A = dict(x=150, y=220, w=460, h=250, cx=380, cy=380)   # 左上·青
SLAB_B = dict(x=414, y=554, w=460, h=250, cx=644, cy=644)   # 右下·琥珀
ROTATE_DEG = -18
BOLT = [(636, 108), (540, 396), (652, 396), (396, 900), (508, 528), (416, 528)]


def _scale_pts(pts, k):
    return [(x * k, y * k) for x, y in pts]


def _vertical_gradient(w, h, top, bottom):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def _radial_burst(size, color, max_alpha=200):
    """中央径向光晕：实心圆 + 重模糊。"""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = int(size * 0.30)
    cx = cy = size // 2
    cy = int(size * 0.48)
    d.ellipse([cx - r, cy - r, cx + r, cy + r],
              fill=color + (max_alpha,))
    return layer.filter(ImageFilter.GaussianBlur(size * 0.09))


def _draw_slab(spec, stroke, fill, k, detail):
    """在独立图层上画板块（未旋转），返回 (sharp, glow) 两个图层。"""
    pad = int(60 * k)
    w = int((spec['w']) * k) + pad * 2
    h = int((spec['h']) * k) + pad * 2
    sharp = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sharp)
    dg = ImageDraw.Draw(glow)
    rect = [pad, pad, pad + spec['w'] * k, pad + spec['h'] * k]
    radius = int(30 * k)
    sw = int((12 if detail == 'full' else 22) * k)
    # 发光层只画描边
    dg.rounded_rectangle(rect, radius=radius, outline=stroke + (255,), width=sw)
    ds.rounded_rectangle(rect, radius=radius, fill=fill + (255,),
                         outline=stroke + (255,), width=sw)

    if detail == 'full':
        # 格线：3 竖 + 1 横
        lw = int(7 * k)
        x0, y0 = pad, pad
        cw = spec['w'] * k
        ch = spec['h'] * k
        for i in range(1, 4):
            x = x0 + cw * i / 4
            ds.line([x, y0, x, y0 + ch], fill=stroke + (140,), width=lw)
        ds.line([x0, y0 + ch / 2, x0 + cw, y0 + ch / 2],
                fill=stroke + (140,), width=lw)
        # 点亮格（右下第二格 / 左上第三格——按构图语义无对错，固定位置）
        cell_w, cell_h = cw / 4, ch / 2
        lx = x0 + cell_w * 2.18
        ly = y0 + cell_h * 1.18
        cw2, ch2 = cell_w * 0.64, cell_h * 0.64
        ds.rounded_rectangle([lx, ly, lx + cw2, ly + ch2], radius=int(10 * k),
                             fill=stroke + (90,), outline=stroke + (255,),
                             width=int(5 * k))
    return sharp, glow.filter(ImageFilter.GaussianBlur(8 * k))


def _draw_bolt(k, detail):
    """中央闪电：sharp + glow 图层（1024*k 画布）。"""
    size = D * k
    sharp = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pts = _scale_pts(BOLT, k)
    ImageDraw.Draw(glow).polygon(pts, fill=BOLT_EDGE + (255,))
    ds = ImageDraw.Draw(sharp)
    ds.polygon(pts, fill=BOLT_FILL + (255,), outline=BOLT_EDGE + (255,))
    # 描边加粗：多边形边线补一轮 line
    sw = int(6 * k)
    ds.line(pts + [pts[0]], fill=BOLT_EDGE + (255,), width=sw, joint='curve')
    return sharp, glow.filter(ImageFilter.GaussianBlur(10 * k))


def render(size=D, detail='full', background=True, content_scale=1.0,
           bg_color=BG_SOLID):
    """渲染图标。detail='small' 时加粗描边、省略格线（小尺寸档）。"""
    k = S
    big = D * k
    canvas = Image.new('RGBA', (big, big), (0, 0, 0, 0))

    if background:
        canvas = _vertical_gradient(big, big, BG_TOP, BG_BOTTOM).convert('RGBA')
        canvas.alpha_composite(_radial_burst(big, (126, 231, 255)))

    # ── 板块（旋转合成） ──
    for spec, stroke, fill in (
        (SLAB_A, CYAN, SLAB_FILL_CYAN),
        (SLAB_B, AMBER, SLAB_FILL_AMBER),
    ):
        sharp, glow = _draw_slab(spec, stroke, fill, k, detail)
        # PIL rotate 逆时针为正；与 SVG rotate(-18) 视觉一致取 18
        cx = spec['cx'] * k
        cy = spec['cy'] * k
        # 板块图层原点 = (cx - w/2, cy - h/2)
        ox = cx - sharp.width // 2
        oy = cy - sharp.height // 2
        rot_g = glow.rotate(18, resample=Image.BICUBIC, center=(glow.width / 2, glow.height / 2))
        rot_s = sharp.rotate(18, resample=Image.BICUBIC, center=(sharp.width / 2, sharp.height / 2))
        canvas.alpha_composite(rot_g, (int(ox), int(oy)))
        canvas.alpha_composite(rot_s, (int(ox), int(oy)))

    # ── 闪电 ──
    bolt_s, bolt_g = _draw_bolt(k, detail)
    canvas.alpha_composite(bolt_g)
    canvas.alpha_composite(bolt_s)

    # ── 内容缩放（maskable / 自适应安全区用） ──
    if content_scale != 1.0:
        fg = Image.new('RGBA', (big, big), (0, 0, 0, 0))
        content = canvas if not background else _render_content_only(k, detail)
        cw = int(big * content_scale)
        content = content.resize((cw, cw), Image.LANCZOS)
        off = (big - cw) // 2
        if background:
            base = Image.new('RGBA', (big, big), bg_color + (255,))
            base.alpha_composite(content, (off, off))
            canvas = base
        else:
            fg.alpha_composite(content, (off, off))
            canvas = fg

    return canvas.resize((size, size), Image.LANCZOS)


def _render_content_only(k, detail):
    """仅内容（透明底）：板块 + 闪电 + 轻光晕。"""
    big = D * k
    canvas = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    burst = _radial_burst(big, (126, 231, 255), max_alpha=110)
    canvas.alpha_composite(burst)
    for spec, stroke, fill in (
        (SLAB_A, CYAN, SLAB_FILL_CYAN),
        (SLAB_B, AMBER, SLAB_FILL_AMBER),
    ):
        sharp, glow = _draw_slab(spec, stroke, fill, k, detail)
        cx = spec['cx'] * k
        cy = spec['cy'] * k
        ox = cx - sharp.width // 2
        oy = cy - sharp.height // 2
        rot_g = glow.rotate(18, resample=Image.BICUBIC, center=(glow.width / 2, glow.height / 2))
        rot_s = sharp.rotate(18, resample=Image.BICUBIC, center=(sharp.width / 2, sharp.height / 2))
        canvas.alpha_composite(rot_g, (int(ox), int(oy)))
        canvas.alpha_composite(rot_s, (int(ox), int(oy)))
    bolt_s, bolt_g = _draw_bolt(k, detail)
    canvas.alpha_composite(bolt_g)
    canvas.alpha_composite(bolt_s)
    return canvas


def _flatten(img, color=BG_SOLID):
    base = Image.new('RGB', img.size, color)
    base.paste(img, mask=img.split()[3] if img.mode == 'RGBA' else None)
    return base


m1024_global: Image.Image  # main() 里赋值，供 _sized 复用


def _sized(px):
    """按导出尺寸分级：≤64px 用 small 档（加粗描边、省略格线）。"""
    if px <= 64:
        return render(size=px, detail='small')
    return m1024_global.resize((px, px), Image.LANCZOS)


# ── 平台导出 ─────────────────────────────────────────────────────

def export_ios(_master):
    d = APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for f in d.glob('Icon-App-*.png'):
        # 文件名含尺寸如 Icon-App-60x60@3x.png → 60*3
        stem = f.stem.split('-')[-1]          # 60x60@3x
        dim = stem.split('@')[0].split('x')[0]
        scale = int(stem.split('@')[1][0])
        px = int(float(dim) * scale)
        img = _sized(px)
        _flatten(img).save(f)                 # iOS 不允许 alpha
        print('  iOS', f.name, px)


def export_macos(_master):
    d = APP / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for f in d.glob('app_icon_*.png'):
        px = int(f.stem.split('_')[-1])
        img = _sized(px)
        img.save(f)                           # macOS 允许 alpha（全出血无需）
        print('  macOS', f.name, px)


def export_android(_master, content_only):
    res = APP / 'android/app/src/main/res'
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    fore = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
    for name, px in legacy.items():
        d = res / f'mipmap-{name}'
        d.mkdir(parents=True, exist_ok=True)
        _flatten(_sized(px)).save(d / 'ic_launcher.png')
        # 自适应前景：内容缩 62%（安全区）
        fpx = fore[name]
        fimg = content_only.resize((int(fpx * 0.62),) * 2, Image.LANCZOS)
        canvas = Image.new('RGBA', (fpx, fpx), (0, 0, 0, 0))
        canvas.alpha_composite(fimg, ((fpx - fimg.width) // 2,) * 2)
        canvas.save(d / 'ic_launcher_foreground.png')
        print('  Android', name, px)
    # anydpi-v26 自适应图标 xml + 背景色
    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding='utf-8')
    values = res / 'values'
    values.mkdir(parents=True, exist_ok=True)
    (values / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#0B1120</color>\n'
        '</resources>\n', encoding='utf-8')
    print('  Android adaptive icon xml + background')


def export_web(_master):
    d = APP / 'web/icons'
    for name, px in (('Icon-192.png', 192), ('Icon-512.png', 512)):
        _flatten(_sized(px)).save(d / name)
        print('  Web', name, px)
    # maskable：内容缩至 70% 安全区，底色填充
    for name, px in (('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)):
        content = m1024_global.resize((int(px * 0.7),) * 2, Image.LANCZOS)
        canvas = Image.new('RGB', (px, px), BG_SOLID)
        canvas.paste(content, ((px - content.width) // 2,) * 2, content)
        canvas.save(d / name)
        print('  Web', name, px, '(maskable)')
    _sized(48).save(APP / 'web/favicon.png')
    print('  Web favicon.png 48')


def export_windows(master):
    ico = APP / 'windows/runner/resources/app_icon.ico'
    sizes = [16, 24, 32, 48, 64, 128, 256]
    master.save(ico, sizes=[(s, s) for s in sizes])
    print('  Windows app_icon.ico', sizes)


def main():
    global m1024_global
    print('渲染 master（2048 超采样）…')
    master = render(size=2048, detail='full')
    out = ROOT / 'tools/app_icon/icon_master.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    master.save(out)
    print('master →', out)

    # 前景内容（透明底，自适应图标用）
    content_only = _render_content_only(S, 'full').resize((1024, 1024), Image.LANCZOS)

    m1024_global = master.resize((1024, 1024), Image.LANCZOS)
    print('导出各平台…')
    export_ios(m1024_global)
    export_macos(m1024_global)
    export_android(m1024_global, content_only)
    export_web(m1024_global)
    export_windows(m1024_global)
    print('完成 ✅')


if __name__ == '__main__':
    main()
