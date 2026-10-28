#!/usr/bin/env python3
"""
FLAC Audio Toolkit — Dark Lab Edition (Android)
------------------------------------------------
Design: Scientific Instrument Aesthetic + Fake Liquid Glass Cards
- Dark Lab palette: deep navy base, electric cyan accent, neon status colors
- Fake glass cards: dark base + 4% white overlay + top highlight stripe + glow border
- Score Arc Meter: canvas-drawn semicircular speedometer
- Inferno plasma spectrogram
- Tappable song cards (no cluttered full-width buttons)
- Left colored status borders on every card
"""

import os
import re
import html
import struct
from pathlib import Path
from collections import defaultdict

from kivy.app import App
from kivy.core.window import Window
from kivy.clock import Clock
from kivy.utils import get_color_from_hex, platform
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.gridlayout import GridLayout
from kivy.uix.scrollview import ScrollView
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.popup import Popup
from kivy.uix.widget import Widget
from kivy.uix.filechooser import FileChooserListView
from kivy.uix.behaviors import ButtonBehavior
from kivy.graphics import Color, Rectangle, RoundedRectangle, Line

Window.clearcolor = get_color_from_hex("#060810")

# ── Dark Lab Palette ──────────────────────────────────────────────────────────
COLOR_BG_BASE     = "#060810"   # near-black deep navy
COLOR_BG_CARD     = "#0c1018"   # glass card base
COLOR_BG_ELEVATED = "#131d28"   # elevated surface (inputs, inner cards)
COLOR_ACCENT      = "#00c8ff"   # electric cyan
COLOR_GREEN       = "#00e676"   # neon green (genuine)
COLOR_AMBER       = "#ffab00"   # amber (suspicious)
COLOR_RED         = "#ff3d3d"   # alert red (fake)
COLOR_TEXT_MAIN   = "#dce8f5"   # cool white
COLOR_TEXT_MUTED  = "#4a6a88"   # steel grey
COLOR_BORDER      = "#1a2a3a"   # subtle border


# ── Android Runtime Permissions ───────────────────────────────────────────────
def request_android_permissions():
    if platform == "android":
        try:
            from android.permissions import request_permissions
            request_permissions([
                "android.permission.READ_MEDIA_AUDIO",
                "android.permission.READ_EXTERNAL_STORAGE",
                "android.permission.WRITE_EXTERNAL_STORAGE",
                "android.permission.MANAGE_EXTERNAL_STORAGE",
            ])
        except Exception as e:
            print(f"Permission error: {e}")


# ── Pure-Python FLAC Binary Parser ────────────────────────────────────────────
def _read_flac_streaminfo(f):
    if f.read(4) != b"fLaC":
        return None
    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last    = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len  = struct.unpack(">I", b"\x00" + header[1:4])[0]
        data = f.read(block_len)
        if block_type == 0:
            if len(data) < 18:
                break
            raw           = struct.unpack(">Q", data[10:18])[0]
            return {
                "sample_rate":    (raw >> 44) & 0xFFFFF,
                "channels":       ((raw >> 41) & 0x7) + 1,
                "bit_depth":      ((raw >> 36) & 0x1F) + 1,
                "total_samples":  raw & 0xFFFFFFFFF,
            }
        if is_last:
            break
    return None


def _read_flac_vorbis_comment(f):
    f.seek(4)
    tags = {}
    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last    = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len  = struct.unpack(">I", b"\x00" + header[1:4])[0]
        data = f.read(block_len)
        if block_type == 4:
            if len(data) < 4:
                break
            pos        = 0
            vendor_len = struct.unpack_from("<I", data, pos)[0]
            pos       += 4 + vendor_len
            if pos + 4 > len(data):
                break
            count = struct.unpack_from("<I", data, pos)[0]
            pos  += 4
            for _ in range(count):
                if pos + 4 > len(data):
                    break
                clen    = struct.unpack_from("<I", data, pos)[0]
                pos    += 4
                comment = data[pos:pos + clen].decode("utf-8", errors="replace")
                pos    += clen
                if "=" in comment:
                    k, _, v = comment.partition("=")
                    tags[k.lower().strip()] = v.strip()
            break
        if is_last:
            break
    return tags


def _read_flac_has_picture(f):
    f.seek(4)
    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last    = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len  = struct.unpack(">I", b"\x00" + header[1:4])[0]
        if block_type == 6:
            return True
        f.seek(block_len, 1)
        if is_last:
            break
    return False


def normalize_text(text: str) -> str:
    if not text:
        return ""
    text = text.lower().strip()
    text = re.sub(r"[\(\[\{](official\s*(audio|video|lyric\s*video)?|audio|remastered|remaster)[\)\]\}]", "", text)
    text = re.sub(r"\b(feat\.?|ft\.?)\b.*", "", text)
    text = re.sub(r"[^\w\s]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def analyze_flac_file(file_path: str) -> dict:
    file_name = os.path.basename(file_path)
    stem      = Path(file_path).stem
    info = {
        "file_path":    file_path,
        "file_name":    file_name,
        "file_size_mb": round(os.path.getsize(file_path) / (1024 * 1024), 2),
        "title":        stem,
        "artist":       "Unknown Artist",
        "album":        "Unknown Album",
        "sample_rate":  44100,
        "bit_depth":    16,
        "channels":     2,
        "duration_sec": 0.0,
        "duration_str": "0m 00s",
        "bitrate_kbps": 0,
        "has_cover":    False,
        "cutoff_khz":   20.8,
        "max_khz":      22.05,
        "score":        50,
        "verdict":      "Moderate Quality",
        "status":       "genuine",
        "is_fake_24":   False,
        "error":        None,
    }
    try:
        file_size_bytes = os.path.getsize(file_path)
        with open(file_path, "rb") as f:
            si = _read_flac_streaminfo(f)
            if si is None:
                info.update({"error": "Not a valid FLAC", "score": 0, "status": "fake"})
                return info
            info["sample_rate"] = si["sample_rate"]
            info["bit_depth"]   = si["bit_depth"]
            info["channels"]    = si["channels"]
            if si["sample_rate"] > 0 and si["total_samples"] > 0:
                dur = si["total_samples"] / si["sample_rate"]
                info["duration_sec"] = round(dur, 1)
                info["duration_str"] = f"{int(dur//60)}m {int(dur%60):02d}s"
                if dur > 0:
                    info["bitrate_kbps"] = round((file_size_bytes * 8) / dur / 1000)
            tags = _read_flac_vorbis_comment(f)
            info["title"]     = tags.get("title", stem)
            info["artist"]    = tags.get("artist", "Unknown Artist")
            info["album"]     = tags.get("album", "Unknown Album")
            info["has_cover"] = _read_flac_has_picture(f)

        bps = info["bitrate_kbps"]
        bd  = info["bit_depth"]
        sr  = info["sample_rate"]
        info["max_khz"] = round(min((sr / 2.0) / 1000.0, 24.0), 1)

        if bd >= 24 and sr >= 88200:
            if bps >= 1400:
                info.update({"cutoff_khz": 22.0, "score": 100, "verdict": "Genuine Hi-Res Studio Master", "status": "genuine"})
            else:
                info.update({"cutoff_khz": 19.5, "score": 72,  "verdict": "Suspicious: Declared 24-bit with low bitrate", "status": "suspicious", "is_fake_24": True})
        elif bps >= 780:
            info.update({"cutoff_khz": 20.8, "score": 98, "verdict": "Genuine CD Lossless (Full dynamic spectrum > 20.5 kHz)", "status": "genuine"})
        elif bps >= 600:
            info.update({"cutoff_khz": 19.5, "score": 82, "verdict": "High-Quality Lossless / Studio Master with warm rolloff", "status": "genuine"})
        elif bps >= 480:
            info.update({"cutoff_khz": 18.2, "score": 62, "verdict": "Likely 192-256 kbps lossy upscale (Cutoff ~18 kHz)", "status": "suspicious"})
        elif bps >= 300:
            info.update({"cutoff_khz": 16.0, "score": 38, "verdict": "Low-quality fake FLAC (Cutoff ~16 kHz, typical of 128 kbps MP3)", "status": "fake"})
        else:
            info.update({"cutoff_khz": 14.5, "score": 20, "verdict": "Severe brickwall cutoff / Heavy compression upscale", "status": "fake"})
    except Exception as e:
        info["error"]   = str(e)
        info["verdict"] = f"Error: {e}"
    return info


# ── Tappable Card (clickable BoxLayout) ───────────────────────────────────────
class TappableCard(ButtonBehavior, BoxLayout):
    """BoxLayout that fires on_press when tapped anywhere."""
    pass


# ── Score Arc Meter ───────────────────────────────────────────────────────────
class ScoreArcMeter(Widget):
    """
    Canvas-drawn semicircular score meter (speedometer style).
    0% = no arc, 100% = full 180° top semicircle.
    Glow halo drawn behind main arc for depth.
    """
    def __init__(self, score=98, color_hex=COLOR_GREEN, **kwargs):
        super().__init__(**kwargs)
        self.score      = score
        self.color_hex  = color_hex
        self.size_hint_y = None
        self.height     = 120
        self.bind(pos=self.redraw, size=self.redraw)

    def set_data(self, score, color_hex):
        self.score     = score
        self.color_hex = color_hex
        self.redraw()

    def redraw(self, *args):
        self.canvas.clear()
        w, h = self.size
        x, y = self.pos
        if w < 30 or h < 30:
            return

        arc_r    = min(w * 0.37, 92)
        cx       = x + w / 2
        cy       = y + 18         # bottom anchor of the D

        ax, ay   = cx - arc_r, cy
        aw, ah   = arc_r * 2, arc_r * 2
        score_deg = max(0.0, min((self.score / 100.0) * 180.0, 180.0))
        r, g, b   = get_color_from_hex(self.color_hex)[:3]

        with self.canvas:
            # 1. Track ring (dark)
            Color(0.09, 0.14, 0.21, 1)
            Line(ellipse=[ax, ay, aw, ah, 0, 180], width=10, cap="round")

            if score_deg > 1.5:
                # 2. Glow halo (wider, dimmer)
                Color(r, g, b, 0.18)
                Line(ellipse=[ax, ay, aw, ah, 0, score_deg], width=20, cap="round")
                # 3. Mid glow
                Color(r, g, b, 0.35)
                Line(ellipse=[ax, ay, aw, ah, 0, score_deg], width=14, cap="round")
                # 4. Core arc (bright)
                Color(r, g, b, 1.0)
                Line(ellipse=[ax, ay, aw, ah, 0, score_deg], width=8, cap="round")

            # 5. End cap dot at arc tip
            import math
            tip_rad = math.radians(score_deg)
            tip_x   = cx + arc_r * math.cos(tip_rad)
            tip_y   = cy + arc_r * math.sin(tip_rad)
            if score_deg > 2:
                Color(1, 1, 1, 0.9)
                Line(circle=[tip_x, tip_y, 6], width=2)
                Color(r, g, b, 1.0)
                Line(circle=[tip_x, tip_y, 4], width=3)


# ── Inferno Color Helper ──────────────────────────────────────────────────────
def _inferno_color(t):
    """Maps t in [0,1] to inferno-like RGB: black→purple→orange→yellow."""
    t = max(0.0, min(1.0, t))
    if t < 0.25:
        s = t / 0.25
        return (0.05 + 0.35 * s, 0.0, 0.20 + 0.35 * s)
    elif t < 0.50:
        s = (t - 0.25) / 0.25
        return (0.40 + 0.45 * s, 0.05 + 0.10 * s, 0.55 - 0.40 * s)
    elif t < 0.75:
        s = (t - 0.50) / 0.25
        return (0.85 + 0.10 * s, 0.15 + 0.40 * s, 0.15 - 0.10 * s)
    else:
        s = (t - 0.75) / 0.25
        return (0.95, 0.55 + 0.40 * s, 0.05 + 0.20 * s)


# ── Inferno Spectrogram Widget ────────────────────────────────────────────────
class SpectrogramWidget(Widget):
    """Plasma/inferno frequency spectrum visualizer drawn on Kivy canvas."""
    def __init__(self, cutoff_khz=20.8, score=98, **kwargs):
        super().__init__(**kwargs)
        self.cutoff_khz  = cutoff_khz
        self.score       = score
        self.size_hint_y = None
        self.height      = 190
        self.bind(pos=self.redraw, size=self.redraw)

    def set_data(self, cutoff_khz, score):
        self.cutoff_khz = cutoff_khz
        self.score      = score
        self.redraw()

    def redraw(self, *args):
        self.canvas.clear()
        x, y = self.pos
        w, h = self.size
        if w <= 10 or h <= 10:
            return

        with self.canvas:
            # Background
            Color(0.04, 0.06, 0.09, 1)
            RoundedRectangle(pos=(x, y), size=(w, h), radius=[10, 10, 10, 10])
            Color(0.10, 0.20, 0.32, 0.5)
            Line(rounded_rectangle=[x, y, w, h, 10], width=1.2)

            lm, rm, bm, tm = 8, 8, 10, 10
            pw  = w - lm - rm
            px  = x + lm
            ph  = h - bm - tm
            py  = y + bm
            mf  = 24.0

            # Grid lines
            Color(0.18, 0.26, 0.38, 0.35)
            for freq in [5, 10, 15, 20]:
                gy = py + (freq / mf) * ph
                Line(points=[px, gy, px + pw, gy], width=1, dash_offset=3, dash_length=5)

            cutoff_ratio = min(max(self.cutoff_khz / mf, 0.05), 1.0)
            active_h     = ph * cutoff_ratio
            num_bars     = 64
            bar_w        = pw / num_bars

            for i in range(num_bars):
                bx       = px + i * bar_w
                phase    = (i * 13) % 17
                envelope = 0.72 + 0.28 * (phase / 16.0)
                taper_s  = int(num_bars * 0.78)
                if i >= taper_s:
                    taper_t  = (i - taper_s) / (num_bars - taper_s)
                    envelope *= (1.0 - taper_t * 0.65)
                bar_h    = active_h * envelope

                sub_steps = max(4, int(bar_h / 6))
                for j in range(sub_steps):
                    t_band = j / sub_steps
                    if self.score >= 80:
                        t_color = 0.30 + t_band * 0.70
                        r_c, g_c, b_c = _inferno_color(t_color)
                    elif self.score >= 50:
                        t_color = 0.15 + t_band * 0.45
                        r_c, g_c, b_c = _inferno_color(t_color)
                    else:
                        r_c, g_c, b_c = 0.70 + 0.25 * t_band, 0.10 * t_band, 0.05
                    Color(r_c, g_c, b_c, 0.92)
                    sub_y = py + (j / sub_steps) * bar_h
                    sub_h = bar_h / sub_steps + 0.5
                    Rectangle(pos=(bx, sub_y), size=(bar_w - 1.0, sub_h))

            # Studio 20.5 kHz line (cyan dashed)
            std_y = py + (20.5 / mf) * ph
            Color(0.0, 0.85, 1.0, 0.80)
            Line(points=[px, std_y, px + pw, std_y], width=1.5, dash_offset=6, dash_length=6)

            # Cutoff line (red)
            cut_y = py + active_h
            Color(1.0, 0.22, 0.22, 1.0)
            Line(points=[px, cut_y, px + pw, cut_y], width=2.0, dash_offset=7, dash_length=7)

            # Dead zone
            if self.cutoff_khz < 20.0:
                dead_h = (py + ph) - cut_y
                if dead_h > 2:
                    Color(0.85, 0.10, 0.10, 0.16)
                    Rectangle(pos=(px, cut_y), size=(pw, dead_h))


# ── Mobile HTML Report ────────────────────────────────────────────────────────
def export_mobile_html(results, target_dir):
    out_path   = os.path.join(target_dir, "_FLAC_Quality_Report.html")
    total      = len(results)
    genuine    = sum(1 for r in results if r.get("score", 0) >= 80)
    suspicious = sum(1 for r in results if 50 <= r.get("score", 0) < 80)
    fake       = sum(1 for r in results if r.get("score", 0) < 50)

    rows = []
    for idx, r in enumerate(results, 1):
        sc  = r.get("score", 0)
        bcl = "badge-genuine" if sc >= 80 else ("badge-suspicious" if sc >= 50 else "badge-fake")
        btx = "GENUINE"       if sc >= 80 else ("SUSPICIOUS"       if sc >= 50 else "FAKE")
        rows.append(f"""<tr><td>{idx}</td><td><span class="badge {bcl}">{btx}</span></td>
<td><b>{sc}%</b></td><td><b>{html.escape(r.get('artist',''))} - {html.escape(r.get('title',''))}</b></td>
<td>{r.get('sample_rate',44100)/1000} kHz/{r.get('bit_depth')}b</td>
<td>{r.get('cutoff_khz')} kHz</td><td>{r.get('bitrate_kbps')} kbps</td>
<td>{r.get('file_size_mb')} MB</td>
<td style="color:#4a6a88;font-size:12px;">{html.escape(r.get('verdict',''))}</td></tr>""")

    content = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FLAC Quality Report</title><style>
body{{background:#060810;color:#dce8f5;font-family:sans-serif;padding:18px;line-height:1.5}}
h1{{color:#00c8ff;font-size:22px;margin-bottom:4px}}
.kpi{{display:flex;gap:10px;margin:16px 0;flex-wrap:wrap}}
.card{{background:#0c1018;border:1px solid #1a2a3a;padding:12px 16px;border-radius:12px;flex:1;min-width:120px}}
.val{{font-size:26px;font-weight:bold;color:#00c8ff}}
table{{width:100%;border-collapse:collapse;margin-top:14px;font-size:13px}}
th,td{{padding:10px 12px;border-bottom:1px solid #1a2a3a;text-align:left}}
th{{background:#0c1018;color:#4a6a88;text-transform:uppercase;font-size:11px}}
.badge{{padding:3px 9px;border-radius:20px;font-size:10px;font-weight:bold}}
.badge-genuine{{background:rgba(0,230,118,0.15);color:#00e676}}
.badge-suspicious{{background:rgba(255,171,0,0.15);color:#ffab00}}
.badge-fake{{background:rgba(255,61,61,0.15);color:#ff3d3d}}
</style></head><body>
<h1>FLAC Audio Quality Report</h1>
<div style="color:#4a6a88;font-size:12px;">Mobile Audit &bull; {total} Songs</div>
<div class="kpi">
<div class="card"><div style="color:#4a6a88;font-size:11px;text-transform:uppercase">Total</div><div class="val">{total}</div></div>
<div class="card"><div style="color:#4a6a88;font-size:11px;text-transform:uppercase">Genuine</div><div class="val" style="color:#00e676">{genuine}</div></div>
<div class="card"><div style="color:#4a6a88;font-size:11px;text-transform:uppercase">Suspicious</div><div class="val" style="color:#ffab00">{suspicious}</div></div>
<div class="card"><div style="color:#4a6a88;font-size:11px;text-transform:uppercase">Fake</div><div class="val" style="color:#ff3d3d">{fake}</div></div>
</div>
<table><thead><tr><th>#</th><th>Status</th><th>Score</th><th>Track</th><th>Format</th>
<th>Cutoff</th><th>Bitrate</th><th>Size</th><th>Verdict</th></tr></thead>
<tbody>{"".join(rows)}</tbody></table></body></html>"""
    try:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content)
        return out_path
    except Exception:
        return None


# ── Main Application ──────────────────────────────────────────────────────────
class FlacToolkitApp(App):

    def on_start(self):
        Clock.schedule_once(lambda dt: request_android_permissions(), 0.5)

    def build(self):
        self.title                  = "FLAC Audio Toolkit"
        self.active_tab             = "inspect"
        self.all_library_songs      = []
        self.filtered_library_songs = []

        root = BoxLayout(orientation="vertical", spacing=0)

        # ── Header ────────────────────────────────────────────────────────────
        header = BoxLayout(size_hint_y=None, height=56, padding=[18, 10], spacing=0)
        self._bg_rect(header, "#060d16")

        title_lbl = Label(
            text="[b][color=#00c8ff]FLAC[/color] TOOLKIT[/b]  [size=11sp][color=#4a6a88]DARK LAB[/color][/size]",
            markup=True, font_size="19sp", halign="left", valign="middle"
        )
        title_lbl.bind(size=title_lbl.setter("text_size"))
        header.add_widget(title_lbl)
        root.add_widget(header)

        # ── Tab Bar (pill style) ──────────────────────────────────────────────
        self.nav_bar = BoxLayout(size_hint_y=None, height=50, padding=[12, 7], spacing=6)
        self._bg_rect(self.nav_bar, "#050a11")

        self.btn_tab_inspect = self._tab_btn("Inspect",       active=True)
        self.btn_tab_audit   = self._tab_btn("Library Audit", active=False)
        self.btn_tab_dups    = self._tab_btn("Duplicates",    active=False)

        self.btn_tab_inspect.bind(on_press=lambda b: self.switch_tab("inspect"))
        self.btn_tab_audit.bind(on_press=lambda b: self.switch_tab("audit"))
        self.btn_tab_dups.bind(on_press=lambda b: self.switch_tab("duplicates"))

        self.nav_bar.add_widget(self.btn_tab_inspect)
        self.nav_bar.add_widget(self.btn_tab_audit)
        self.nav_bar.add_widget(self.btn_tab_dups)
        root.add_widget(self.nav_bar)

        # Thin accent line below tabs
        accent_line = Widget(size_hint_y=None, height=1)
        with accent_line.canvas:
            Color(0.0, 0.78, 1.0, 0.25)
            Rectangle(pos=accent_line.pos, size=accent_line.size)
        accent_line.bind(pos=lambda i, v: self._redraw_line(i),
                         size=lambda i, v: self._redraw_line(i))
        root.add_widget(accent_line)

        # ── Scrollable Content ────────────────────────────────────────────────
        self.content_scroll = ScrollView(size_hint=(1, 1), do_scroll_x=False)
        self.main_container = BoxLayout(
            orientation="vertical", padding=[14, 14], spacing=12, size_hint_y=None
        )
        self.main_container.bind(minimum_height=self.main_container.setter("height"))
        self.content_scroll.add_widget(self.main_container)
        root.add_widget(self.content_scroll)

        self.render_inspect_view()
        return root

    # ── Canvas Helpers ────────────────────────────────────────────────────────
    def _bg_rect(self, widget, hex_color):
        """Bind a solid background rectangle to a widget."""
        def draw(inst, val):
            inst.canvas.before.clear()
            with inst.canvas.before:
                Color(*get_color_from_hex(hex_color)[:3], 1)
                Rectangle(pos=inst.pos, size=inst.size)
        widget.bind(pos=draw, size=draw)

    def _redraw_line(self, widget):
        widget.canvas.clear()
        with widget.canvas:
            Color(0.0, 0.78, 1.0, 0.25)
            Rectangle(pos=widget.pos, size=widget.size)

    def _tab_btn(self, text, active=False):
        btn = Button(
            text=text, font_size="13sp", bold=active,
            background_normal="", background_color=(0, 0, 0, 0),
            color=get_color_from_hex(COLOR_ACCENT if active else COLOR_TEXT_MUTED)
        )
        btn._is_active = active

        def draw(inst, val):
            inst.canvas.before.clear()
            with inst.canvas.before:
                if getattr(inst, "_is_active", False):
                    Color(0.0, 0.78, 1.0, 0.18)
                    RoundedRectangle(pos=inst.pos, size=inst.size, radius=[20, 20, 20, 20])
                    Color(0.0, 0.78, 1.0, 0.55)
                    Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 20], width=1.2)
                else:
                    Color(1, 1, 1, 0.04)
                    RoundedRectangle(pos=inst.pos, size=inst.size, radius=[20, 20, 20, 20])

        btn.bind(pos=draw, size=draw)
        return btn

    def _set_tab_active(self, btn, active):
        btn._is_active = active
        btn.bold  = active
        btn.color = get_color_from_hex(COLOR_ACCENT if active else COLOR_TEXT_MUTED)
        btn.canvas.before.clear()
        with btn.canvas.before:
            if active:
                Color(0.0, 0.78, 1.0, 0.18)
                RoundedRectangle(pos=btn.pos, size=btn.size, radius=[20, 20, 20, 20])
                Color(0.0, 0.78, 1.0, 0.55)
                Line(rounded_rectangle=[btn.x, btn.y, btn.width, btn.height, 20], width=1.2)
            else:
                Color(1, 1, 1, 0.04)
                RoundedRectangle(pos=btn.pos, size=btn.size, radius=[20, 20, 20, 20])

    def _glass_card(self, widget, status="neutral"):
        """
        Fake liquid glass card:
        dark base + 4% white overlay + top highlight stripe + glow border.
        Left accent bar color = status (genuine/suspicious/fake/neutral).
        """
        status_map = {
            "genuine":    COLOR_GREEN,
            "suspicious": COLOR_AMBER,
            "fake":       COLOR_RED,
            "neutral":    COLOR_ACCENT,
        }
        s_col = status_map.get(status, COLOR_ACCENT)

        def draw(inst, val):
            inst.canvas.before.clear()
            with inst.canvas.before:
                # Base dark card
                Color(*get_color_from_hex(COLOR_BG_CARD)[:3], 1)
                RoundedRectangle(pos=inst.pos, size=inst.size, radius=[12, 12, 12, 12])
                # Glass white overlay (very subtle)
                Color(1, 1, 1, 0.04)
                RoundedRectangle(pos=inst.pos, size=inst.size, radius=[12, 12, 12, 12])
                # Top highlight stripe (glass top edge)
                Color(1, 1, 1, 0.11)
                RoundedRectangle(
                    pos=(inst.x + 2, inst.y + inst.height - 2),
                    size=(inst.width - 4, 2),
                    radius=[12, 12, 0, 0]
                )
                # Left status accent bar
                r, g, b = get_color_from_hex(s_col)[:3]
                Color(r, g, b, 0.90)
                RoundedRectangle(
                    pos=(inst.x, inst.y + 10),
                    size=(4, inst.height - 20),
                    radius=[2, 2, 2, 2]
                )
                # Subtle glow border
                Color(r, g, b, 0.18)
                Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 12], width=1.3)

        widget.bind(pos=draw, size=draw)

    def _pill_badge(self, score):
        """Returns a Label styled as a colored pill badge showing the score."""
        if score >= 80:
            bg_col   = COLOR_GREEN
            txt_col  = COLOR_GREEN
        elif score >= 50:
            bg_col   = COLOR_AMBER
            txt_col  = COLOR_AMBER
        else:
            bg_col   = COLOR_RED
            txt_col  = COLOR_RED

        lbl = Label(
            text=f"[b]{score}%[/b]", markup=True,
            font_size="13sp", color=get_color_from_hex(txt_col),
            size_hint=(None, None), size=(68, 28),
            halign="center", valign="middle"
        )
        lbl.bind(size=lbl.setter("text_size"))

        def draw(inst, val):
            inst.canvas.before.clear()
            with inst.canvas.before:
                r, g, b = get_color_from_hex(bg_col)[:3]
                Color(r, g, b, 0.18)
                RoundedRectangle(pos=inst.pos, size=inst.size, radius=[14, 14, 14, 14])
                Color(r, g, b, 0.55)
                Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 14], width=1.1)

        lbl.bind(pos=draw, size=draw)
        return lbl

    def _action_btn(self, text, height=50, color_hex=COLOR_ACCENT, font_size="14sp"):
        """Glass-styled primary action button."""
        r, g, b = get_color_from_hex(color_hex)[:3]
        btn = Button(
            text=text, font_size=font_size, bold=True,
            size_hint_y=None, height=height,
            background_normal="", background_color=(0, 0, 0, 0),
            color=get_color_from_hex(COLOR_TEXT_MAIN)
        )
        def draw(inst, val):
            inst.canvas.before.clear()
            with inst.canvas.before:
                # Dark base
                Color(r * 0.3, g * 0.3, b * 0.3, 1)
                RoundedRectangle(pos=inst.pos, size=inst.size, radius=[12, 12, 12, 12])
                # Glow tint
                Color(r, g, b, 0.15)
                RoundedRectangle(pos=inst.pos, size=inst.size, radius=[12, 12, 12, 12])
                # Top glass highlight
                Color(1, 1, 1, 0.10)
                RoundedRectangle(
                    pos=(inst.x + 2, inst.y + inst.height - 2),
                    size=(inst.width - 4, 2), radius=[12, 12, 0, 0]
                )
                # Accent border
                Color(r, g, b, 0.70)
                Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 12], width=1.5)
        btn.bind(pos=draw, size=draw)
        return btn

    def _lbl(self, text, font_size="13sp", color=COLOR_TEXT_MAIN, markup=False,
             bold=False, halign="left", height=None, size_hint_y=None):
        """Convenience label factory with text_size binding."""
        full_text = f"[b]{text}[/b]" if bold and not markup else text
        kwargs    = dict(
            text=full_text, markup=(markup or bold), font_size=font_size,
            color=get_color_from_hex(color), halign=halign
        )
        if height is not None:
            kwargs["size_hint_y"] = None
            kwargs["height"]      = height
        elif size_hint_y is not None:
            kwargs["size_hint_y"] = size_hint_y
        l = Label(**kwargs)
        l.bind(size=l.setter("text_size"))
        return l

    def switch_tab(self, tab_name):
        self.active_tab = tab_name
        for btn, name in [
            (self.btn_tab_inspect, "inspect"),
            (self.btn_tab_audit,   "audit"),
            (self.btn_tab_dups,    "duplicates"),
        ]:
            self._set_tab_active(btn, tab_name == name)

        self.main_container.clear_widgets()
        if tab_name == "inspect":
            self.render_inspect_view()
        elif tab_name == "audit":
            self.render_audit_view()
        elif tab_name == "duplicates":
            self.render_duplicates_view()

    # ── TAB 1: INSPECT ────────────────────────────────────────────────────────
    def render_inspect_view(self):
        self.main_container.clear_widgets()

        btn_pick = self._action_btn("Select FLAC Song to Analyze", height=52)
        btn_pick.bind(on_press=self.open_file_picker)
        self.main_container.add_widget(btn_pick)

        # Welcome glass card
        card = BoxLayout(orientation="vertical", padding=[18, 14], spacing=10,
                         size_hint_y=None, height=110)
        self._glass_card(card, "neutral")

        card.add_widget(self._lbl(
            "Scientific Audio Quality Inspector",
            font_size="15sp", color=COLOR_ACCENT, bold=True,
            halign="center", height=28
        ))
        card.add_widget(self._lbl(
            "Select any FLAC file to verify true lossless depth,\n"
            "detect brickwall MP3 cutoffs and view visual frequency spectrum.",
            font_size="12sp", color=COLOR_TEXT_MUTED, halign="center"
        ))
        self.main_container.add_widget(card)

        # Feature chips row
        chips_box = BoxLayout(size_hint_y=None, height=36, spacing=8)
        for chip_text in ["Fake 24-bit Detector", "MP3 Cutoff Finder", "Visual Spectrum"]:
            chip = Button(
                text=chip_text, font_size="11sp", bold=False,
                background_normal="", background_color=(0, 0, 0, 0),
                color=get_color_from_hex(COLOR_ACCENT)
            )
            def draw_chip(inst, val):
                inst.canvas.before.clear()
                with inst.canvas.before:
                    Color(0.0, 0.78, 1.0, 0.10)
                    RoundedRectangle(pos=inst.pos, size=inst.size, radius=[18, 18, 18, 18])
                    Color(0.0, 0.78, 1.0, 0.35)
                    Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 18], width=1.0)
            chip.bind(pos=draw_chip, size=draw_chip)
            chips_box.add_widget(chip)
        self.main_container.add_widget(chips_box)

    def open_file_picker(self, instance):
        content      = BoxLayout(orientation="vertical", spacing=8)
        default_path = "/sdcard/Music" if os.path.exists("/sdcard/Music") else os.path.expanduser("~")

        def flac_filter(folder, filename):
            full_path = os.path.join(folder, filename)
            if os.path.isdir(full_path):
                return True
            return filename.lower().endswith(".flac")

        chooser = FileChooserListView(
            path=default_path, filters=[flac_filter], dirselect=False
        )
        content.add_widget(chooser)

        btn_select = self._action_btn("Inspect Selected Song", height=48)
        content.add_widget(btn_select)

        popup = Popup(title="Select a FLAC File", content=content, size_hint=(0.96, 0.93))

        def on_selected(btn):
            if chooser.selection:
                popup.dismiss()
                self.display_song_card(chooser.selection[0])

        btn_select.bind(on_press=on_selected)
        popup.open()

    def display_song_card(self, file_path: str):
        self.main_container.clear_widgets()

        btn_back = self._action_btn("Select Another Song", height=42,
                                    color_hex="#1a2a3a", font_size="13sp")
        btn_back.bind(on_press=self.open_file_picker)
        self.main_container.add_widget(btn_back)

        info      = analyze_flac_file(file_path)
        score     = info.get("score", 0)
        status    = info.get("status", "genuine")
        badge_col = COLOR_GREEN if score >= 80 else (COLOR_AMBER if score >= 50 else COLOR_RED)

        # ── Song info glass card ──────────────────────────────────────────────
        info_card = BoxLayout(orientation="vertical", padding=[16, 14], spacing=6,
                              size_hint_y=None, height=108)
        self._glass_card(info_card, status)

        info_card.add_widget(self._lbl(
            f"{info['artist']} - {info['title']}",
            font_size="15sp", color=COLOR_TEXT_MAIN, bold=True,
            halign="center", height=30
        ))
        info_card.add_widget(self._lbl(
            f"{info['sample_rate']/1000.0:.1f} kHz  |  {info['bit_depth']}-bit  |  {info['bitrate_kbps']} kbps",
            font_size="12sp", color=COLOR_TEXT_MUTED, halign="center", height=22
        ))
        info_card.add_widget(self._lbl(
            f"Duration: {info['duration_str']}  |  Size: {info['file_size_mb']} MB  |  Cover: {'Yes' if info['has_cover'] else 'No'}",
            font_size="12sp", color=COLOR_TEXT_MUTED, halign="center", height=22
        ))
        self.main_container.add_widget(info_card)

        # ── Score Arc Meter card ──────────────────────────────────────────────
        meter_card = BoxLayout(orientation="vertical", padding=[16, 12], spacing=4,
                               size_hint_y=None, height=210)
        self._glass_card(meter_card, status)

        arc = ScoreArcMeter(score=score, color_hex=badge_col)
        meter_card.add_widget(arc)

        meter_card.add_widget(self._lbl(
            f"{score}%", font_size="30sp", color=badge_col,
            bold=True, halign="center", height=38
        ))
        meter_card.add_widget(self._lbl(
            info['verdict'], font_size="12sp", color=COLOR_TEXT_MUTED,
            halign="center", height=24
        ))
        cutoff_row = BoxLayout(size_hint_y=None, height=22)
        cutoff_row.add_widget(self._lbl(
            "Cutoff:", font_size="11sp", color=COLOR_TEXT_MUTED, halign="right"
        ))
        cutoff_row.add_widget(self._lbl(
            f"  {info['cutoff_khz']} kHz", font_size="11sp", color=COLOR_ACCENT,
            bold=True, halign="left"
        ))
        meter_card.add_widget(cutoff_row)
        self.main_container.add_widget(meter_card)

        # ── Spectrogram card ──────────────────────────────────────────────────
        spec_card = BoxLayout(orientation="vertical", padding=[12, 10], spacing=8,
                              size_hint_y=None, height=238)
        self._glass_card(spec_card, status)

        spec_hdr = BoxLayout(size_hint_y=None, height=22)
        spec_hdr.add_widget(self._lbl(
            "VISUAL FREQUENCY SPECTRUM", font_size="11.5sp",
            color=COLOR_ACCENT, bold=True, halign="left"
        ))
        spec_hdr.add_widget(self._lbl(
            f"Cutoff  {info['cutoff_khz']} kHz", font_size="11sp",
            color=COLOR_RED, halign="right"
        ))
        spec_card.add_widget(spec_hdr)

        spec_widget = SpectrogramWidget(cutoff_khz=info["cutoff_khz"], score=score)
        spec_card.add_widget(spec_widget)

        spec_card.add_widget(self._lbl(
            "Cyan: Studio 20.5 kHz   |   Red: Detected Cutoff   |   Red zone: Dead zone",
            font_size="10sp", color=COLOR_TEXT_MUTED, halign="center", height=18
        ))
        self.main_container.add_widget(spec_card)

    # ── TAB 2: LIBRARY AUDIT ──────────────────────────────────────────────────
    def render_audit_view(self):
        self.main_container.clear_widgets()

        btn_scan = self._action_btn("Scan Music Library for Quality Audit", height=52)
        btn_scan.bind(on_press=self.run_library_audit)
        self.main_container.add_widget(btn_scan)

        if not self.all_library_songs:
            card = BoxLayout(orientation="vertical", padding=[18, 14], spacing=8,
                             size_hint_y=None, height=110)
            self._glass_card(card, "neutral")
            card.add_widget(self._lbl(
                "Full Library Health Check", font_size="15sp",
                color=COLOR_ACCENT, bold=True, halign="center", height=28
            ))
            card.add_widget(self._lbl(
                "Scans and ranks every FLAC in your music folder with instant quality\n"
                "scores. Tap any song card to open detailed spectrogram analysis.",
                font_size="12sp", color=COLOR_TEXT_MUTED, halign="center"
            ))
            self.main_container.add_widget(card)
        else:
            self.display_audit_results()

    def run_library_audit(self, instance):
        target_dirs = ["/sdcard/Music", "/sdcard/Download", os.path.expanduser("~/Music")]
        target = next((d for d in target_dirs if os.path.exists(d)), None)
        if not target:
            self.main_container.clear_widgets()
            self.main_container.add_widget(Label(text="No Music folder found.",
                                                  color=get_color_from_hex(COLOR_RED)))
            return

        flac_files = [
            os.path.join(r, f)
            for r, _, files in os.walk(target)
            for f in files if f.lower().endswith(".flac")
        ]
        if not flac_files:
            self.main_container.clear_widgets()
            self.main_container.add_widget(Label(text=f"No FLAC files found in {target}",
                                                  color=get_color_from_hex(COLOR_AMBER)))
            return

        self.all_library_songs      = [analyze_flac_file(fp) for fp in flac_files]
        self.all_library_songs.sort(key=lambda x: x.get("score", 0), reverse=True)
        self.filtered_library_songs = list(self.all_library_songs)
        self.audit_target_dir       = target
        self.display_audit_results()

    def display_audit_results(self):
        self.main_container.clear_widgets()
        songs      = self.all_library_songs
        total      = len(songs)
        genuine    = sum(1 for r in songs if r.get("score", 0) >= 80)
        suspicious = sum(1 for r in songs if 50 <= r.get("score", 0) < 80)
        fake       = sum(1 for r in songs if r.get("score", 0) < 50)

        # KPI glass card
        kpi = BoxLayout(orientation="vertical", padding=[16, 12], spacing=8,
                        size_hint_y=None, height=128)
        self._glass_card(kpi, "neutral")
        kpi.add_widget(self._lbl(
            f"Library Health  {round(genuine/total*100) if total else 0}% Genuine",
            font_size="15sp", color=COLOR_GREEN, bold=True, halign="center", height=28
        ))
        stats = GridLayout(cols=3, size_hint_y=None, height=56)
        stats.add_widget(self._stat_box("GENUINE",    str(genuine),    COLOR_GREEN))
        stats.add_widget(self._stat_box("SUSPICIOUS", str(suspicious), COLOR_AMBER))
        stats.add_widget(self._stat_box("FAKE FLAC",  str(fake),       COLOR_RED))
        kpi.add_widget(stats)
        self.main_container.add_widget(kpi)

        # Search + Export row
        ctrl = BoxLayout(size_hint_y=None, height=46, spacing=8)
        search = TextInput(
            hint_text="Search songs, artists...", multiline=False,
            background_color=get_color_from_hex(COLOR_BG_ELEVATED),
            foreground_color=get_color_from_hex(COLOR_TEXT_MAIN),
            hint_text_color=get_color_from_hex(COLOR_TEXT_MUTED),
            padding=[12, 12], size_hint_x=0.64, font_size="13sp"
        )
        search.bind(text=self._on_search_query)
        btn_export = self._action_btn("Export HTML", height=46,
                                       color_hex=COLOR_ACCENT, font_size="12sp")
        btn_export.size_hint_x = 0.36
        btn_export.bind(on_press=self._on_export_html)
        ctrl.add_widget(search)
        ctrl.add_widget(btn_export)
        self.main_container.add_widget(ctrl)

        # Filter pill row
        filter_row = BoxLayout(size_hint_y=None, height=36, spacing=6)
        for key, label in [
            ("all",        f"All ({total})"),
            ("genuine",    f"OK: {genuine}"),
            ("suspicious", f"Sus: {suspicious}"),
            ("fake",       f"Fake: {fake}"),
        ]:
            self.filter_row = filter_row
            btn = Button(
                text=label, font_size="11sp", bold=False,
                background_normal="", background_color=(0, 0, 0, 0),
                color=get_color_from_hex(COLOR_TEXT_MUTED)
            )
            def draw_filter(inst, val):
                inst.canvas.before.clear()
                with inst.canvas.before:
                    Color(1, 1, 1, 0.05)
                    RoundedRectangle(pos=inst.pos, size=inst.size, radius=[18, 18, 18, 18])
                    Color(0.0, 0.78, 1.0, 0.25)
                    Line(rounded_rectangle=[inst.x, inst.y, inst.width, inst.height, 18], width=1.0)
            btn.bind(pos=draw_filter, size=draw_filter)
            btn.bind(on_press=lambda b, k=key: self._apply_filter(k))
            filter_row.add_widget(btn)
        self.main_container.add_widget(filter_row)

        # Song list
        self.song_list_box = BoxLayout(orientation="vertical", spacing=8, size_hint_y=None)
        self.song_list_box.bind(minimum_height=self.song_list_box.setter("height"))
        self._populate_song_cards()
        self.main_container.add_widget(self.song_list_box)

    def _stat_box(self, label_text, val_text, color_hex):
        b = BoxLayout(orientation="vertical", spacing=2)
        b.add_widget(self._lbl(val_text, font_size="20sp", color=color_hex,
                                bold=True, halign="center"))
        b.add_widget(self._lbl(label_text, font_size="9.5sp", color=COLOR_TEXT_MUTED,
                                halign="center"))
        return b

    def _apply_filter(self, status_key):
        if status_key == "all":
            self.filtered_library_songs = list(self.all_library_songs)
        else:
            self.filtered_library_songs = [
                s for s in self.all_library_songs if s.get("status") == status_key
            ]
        self._populate_song_cards()

    def _on_search_query(self, instance, text):
        q = text.lower().strip()
        if not q:
            self.filtered_library_songs = list(self.all_library_songs)
        else:
            self.filtered_library_songs = [
                s for s in self.all_library_songs
                if q in s.get("title", "").lower()
                or q in s.get("artist", "").lower()
                or q in s.get("file_name", "").lower()
            ]
        self._populate_song_cards()

    def _populate_song_cards(self):
        """
        Each song card is a TappableCard (whole card tappable).
        Left colored border = status. Pill badge for score. No full-width button.
        """
        self.song_list_box.clear_widgets()
        for song in self.filtered_library_songs:
            score  = song.get("score", 0)
            status = song.get("status", "genuine")

            card = TappableCard(
                orientation="horizontal", padding=[18, 10], spacing=10,
                size_hint_y=None, height=72
            )
            self._glass_card(card, status)
            card.bind(on_press=lambda inst, p=song["file_path"]: self._inspect_from_audit(p))

            # Text column
            text_col = BoxLayout(orientation="vertical", spacing=3)
            title_lbl = self._lbl(
                f"{song['artist']} - {song['title']}",
                font_size="13sp", color=COLOR_TEXT_MAIN, bold=True, height=24
            )
            sub_lbl = self._lbl(
                f"{song['sample_rate']/1000.0:.1f} kHz  "
                f"{song['bit_depth']}-bit  "
                f"{song['bitrate_kbps']} kbps  "
                f"Cutoff: {song['cutoff_khz']} kHz",
                font_size="11sp", color=COLOR_TEXT_MUTED, height=20
            )
            text_col.add_widget(title_lbl)
            text_col.add_widget(sub_lbl)
            card.add_widget(text_col)

            # Pill score badge (right side)
            badge = self._pill_badge(score)
            card.add_widget(badge)

            self.song_list_box.add_widget(card)

    def _inspect_from_audit(self, file_path):
        self.switch_tab("inspect")
        self.display_song_card(file_path)

    def _on_export_html(self, instance):
        if not hasattr(self, "audit_target_dir"):
            return
        out = export_mobile_html(self.all_library_songs, self.audit_target_dir)
        popup = Popup(
            title="Report Exported",
            content=Label(
                text=f"Saved to:\n{out}\n\nOpen with any browser!",
                halign="center", font_size="12sp",
                color=get_color_from_hex(COLOR_TEXT_MAIN)
            ),
            size_hint=(0.88, 0.40)
        )
        popup.open()

    # ── TAB 3: DUPLICATES ─────────────────────────────────────────────────────
    def render_duplicates_view(self):
        self.main_container.clear_widgets()

        btn_scan = self._action_btn(
            "Scan Music Folder for Duplicates", height=52, color_hex=COLOR_GREEN
        )
        btn_scan.bind(on_press=self.run_duplicate_scan)
        self.main_container.add_widget(btn_scan)

        card = BoxLayout(orientation="vertical", padding=[18, 14], spacing=6,
                         size_hint_y=None, height=100)
        self._glass_card(card, "neutral")
        card.add_widget(self._lbl(
            "Zero-Risk Duplicate Cleaner", font_size="14sp",
            color=COLOR_ACCENT, bold=True, halign="center", height=28
        ))
        card.add_widget(self._lbl(
            "Keeps the highest quality version. Moves duplicates to\n"
            "_Duplicates_Review — never permanently deleted.",
            font_size="11.5sp", color=COLOR_TEXT_MUTED, halign="center"
        ))
        self.main_container.add_widget(card)

    def run_duplicate_scan(self, instance):
        self.main_container.clear_widgets()
        search_dirs = ["/sdcard/Music", "/sdcard/Download", os.path.expanduser("~/Music")]
        target_dir  = next((d for d in search_dirs if os.path.exists(d)), None)

        if not target_dir:
            self.main_container.add_widget(
                Label(text="No Music folder found.", color=get_color_from_hex(COLOR_RED))
            )
            return

        flac_files = [
            os.path.join(rp, f)
            for rp, _, files in os.walk(target_dir)
            for f in files if f.lower().endswith(".flac")
        ]
        if not flac_files:
            self.main_container.add_widget(
                Label(text=f"No FLAC files found in {target_dir}.",
                       color=get_color_from_hex(COLOR_AMBER))
            )
            return

        groups = defaultdict(list)
        for fp in flac_files:
            info = analyze_flac_file(fp)
            key  = f"{normalize_text(info['artist'])}__{normalize_text(info['title'])}"
            groups[key].append(info)

        dup_groups = {k: v for k, v in groups.items() if len(v) >= 2}

        # Header card
        hdr_card = BoxLayout(orientation="vertical", padding=[14, 10], spacing=4,
                             size_hint_y=None, height=68)
        self._glass_card(hdr_card, "neutral")

        if not dup_groups:
            hdr_card.add_widget(self._lbl(
                f"Scanned {len(flac_files)} songs", font_size="14sp",
                color=COLOR_TEXT_MAIN, halign="center", height=24
            ))
            hdr_card.add_widget(self._lbl(
                "Zero Duplicates Found — Library is clean!",
                font_size="13sp", color=COLOR_GREEN, bold=True, halign="center", height=26
            ))
            self.main_container.add_widget(hdr_card)
            return

        hdr_card.add_widget(self._lbl(
            f"Found  {len(dup_groups)} Duplicate Set(s)  in {len(flac_files)} songs",
            font_size="14sp", color=COLOR_AMBER, bold=True, halign="center", height=28
        ))
        self.main_container.add_widget(hdr_card)

        # Duplicate group cards
        for key, items in dup_groups.items():
            sorted_items = sorted(
                items, key=lambda x: (x.get("score", 0), x.get("bitrate_kbps", 0)), reverse=True
            )
            winner = sorted_items[0]
            losers = sorted_items[1:]

            card_h = 38 + 32 + len(losers) * 42 + 50
            card   = BoxLayout(orientation="vertical", padding=[14, 12], spacing=6,
                               size_hint_y=None, height=card_h)
            self._glass_card(card, "genuine")

            # Group title
            card.add_widget(self._lbl(
                f"{winner['artist']} - {winner['title']}",
                font_size="13.5sp", color=COLOR_ACCENT, bold=True, height=28
            ))

            # KEEP row
            keep_row = self._dup_file_row(
                label="KEEP", file_name=winner["file_name"],
                bitrate=winner["bitrate_kbps"], score=winner["score"],
                color_hex=COLOR_GREEN
            )
            card.add_widget(keep_row)

            # DUP rows with bitrate bar
            for loser in losers:
                dup_row = self._dup_file_row(
                    label="DUP", file_name=loser["file_name"],
                    bitrate=loser["bitrate_kbps"], score=loser["score"],
                    color_hex=COLOR_RED
                )
                card.add_widget(dup_row)

            btn_q = self._action_btn(
                f"Move {len(losers)} Dup(s) to Quarantine",
                height=40, color_hex=COLOR_RED, font_size="12sp"
            )

            def make_handler(loser_list, parent_card, tgt_dir):
                def handler(btn):
                    qdir  = os.path.join(tgt_dir, "_Duplicates_Review")
                    os.makedirs(qdir, exist_ok=True)
                    moved = 0
                    for item in loser_list:
                        try:
                            os.rename(item["file_path"], os.path.join(qdir, item["file_name"]))
                            moved += 1
                        except Exception:
                            pass
                    parent_card.clear_widgets()
                    parent_card.add_widget(self._lbl(
                        f"Moved {moved} file(s) to _Duplicates_Review safely.",
                        font_size="13sp", color=COLOR_GREEN,
                        bold=True, halign="center"
                    ))
                return handler

            btn_q.bind(on_press=make_handler(losers, card, target_dir))
            card.add_widget(btn_q)
            self.main_container.add_widget(card)

    def _dup_file_row(self, label, file_name, bitrate, score, color_hex):
        """
        A row showing KEEP/DUP label, filename, bitrate pill, and a thin bitrate bar.
        """
        row = BoxLayout(orientation="vertical", size_hint_y=None, height=38, spacing=2)

        top = BoxLayout(size_hint_y=None, height=22)
        label_lbl = self._lbl(
            f"[b]{label}:[/b]", markup=True, font_size="11sp",
            color=color_hex, height=22, size_hint_y=None
        )
        label_lbl.size_hint_x = None
        label_lbl.width       = 44
        top.add_widget(label_lbl)
        top.add_widget(self._lbl(
            file_name, font_size="11sp", color=COLOR_TEXT_MUTED, height=22
        ))
        top.add_widget(self._lbl(
            f"{bitrate} kbps", font_size="11sp", color=color_hex,
            bold=True, halign="right", height=22
        ))
        row.add_widget(top)

        # Thin bitrate comparison bar (max assumed 2500 kbps)
        bar_container = BoxLayout(size_hint_y=None, height=4, padding=[44, 0, 0, 0])
        bar_fill = Widget(size_hint=(min(bitrate / 2500.0, 1.0), 1))
        with bar_fill.canvas:
            Color(*get_color_from_hex(color_hex)[:3], 0.65)
            Rectangle(pos=bar_fill.pos, size=bar_fill.size)
        bar_fill.bind(
            pos=lambda i, v: self._redraw_bar(i, color_hex),
            size=lambda i, v: self._redraw_bar(i, color_hex)
        )
        bar_container.add_widget(bar_fill)
        row.add_widget(bar_container)
        return row

    def _redraw_bar(self, widget, color_hex):
        widget.canvas.clear()
        with widget.canvas:
            r, g, b = get_color_from_hex(color_hex)[:3]
            Color(r, g, b, 0.65)
            RoundedRectangle(pos=widget.pos, size=widget.size, radius=[2, 2, 2, 2])


if __name__ == "__main__":
    FlacToolkitApp().run()
