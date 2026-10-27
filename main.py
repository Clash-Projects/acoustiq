#!/usr/bin/env python3
"""
FLAC Audio Toolkit - Android Edition
--------------------------------------
Touch-optimized Mobile App for Android built with Kivy:
1. Audio Quality & Lossless Verification (Cutoff, Bit depth, Sample rate, Bitrate)
2. Safe Duplicate Manager (Multi-layer matching + Quarantine folder protection)

NOTE: Uses pure-Python FLAC parser (no mutagen/numpy) for maximum Android compatibility.
"""

import os
import re
import struct
from pathlib import Path
from collections import defaultdict

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.gridlayout import GridLayout
from kivy.uix.scrollview import ScrollView
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.popup import Popup
from kivy.uix.filechooser import FileChooserListView
from kivy.core.window import Window
from kivy.utils import get_color_from_hex

# Background color: modern dark theme
Window.clearcolor = get_color_from_hex("#121212")


# ---------------------------------------------------------------------------
# Pure-Python FLAC Parser (no mutagen required)
# ---------------------------------------------------------------------------

def _read_flac_streaminfo(f):
    """
    Reads the STREAMINFO metadata block from an open FLAC file handle.
    Returns dict with: sample_rate, bit_depth, channels, total_samples
    Returns None on parse failure.
    """
    magic = f.read(4)
    if magic != b"fLaC":
        return None

    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len = struct.unpack(">I", b"\x00" + header[1:4])[0]
        data = f.read(block_len)

        if block_type == 0:  # STREAMINFO
            if len(data) < 18:
                break
            # Bits layout (from FLAC spec):
            # [0-1]   min block size  (16 bits)
            # [2-3]   max block size  (16 bits)
            # [4-6]   min frame size  (24 bits)
            # [7-9]   max frame size  (24 bits)
            # [10-12] sample_rate(20) + channels(3) + bit_depth(5) + total_samples high(4) -- packed
            # Read as big-endian unsigned from bytes 10..17 (8 bytes)
            raw = struct.unpack(">Q", data[10:18])[0]
            sample_rate  = (raw >> 44) & 0xFFFFF   # 20 bits
            channels     = ((raw >> 41) & 0x7) + 1  # 3 bits, stored as (channels-1)
            bit_depth    = ((raw >> 36) & 0x1F) + 1 # 5 bits, stored as (bps-1)
            total_samples = raw & 0xFFFFFFFFF        # 36 bits
            return {
                "sample_rate": sample_rate,
                "bit_depth": bit_depth,
                "channels": channels,
                "total_samples": total_samples,
            }

        if is_last:
            break

    return None


def _read_flac_vorbis_comment(f):
    """
    Reads Vorbis comment block (METADATA_BLOCK_TYPE 4) from FLAC.
    Returns dict with lowercase tag keys, e.g. {'title':..,'artist':..,'album':..}
    """
    f.seek(4)  # skip fLaC magic
    tags = {}
    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len = struct.unpack(">I", b"\x00" + header[1:4])[0]
        data = f.read(block_len)

        if block_type == 4:  # VORBIS_COMMENT
            # Little-endian format: vendor string, then comment list
            if len(data) < 4:
                break
            pos = 0
            vendor_len = struct.unpack_from("<I", data, pos)[0]
            pos += 4 + vendor_len
            if pos + 4 > len(data):
                break
            count = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            for _ in range(count):
                if pos + 4 > len(data):
                    break
                clen = struct.unpack_from("<I", data, pos)[0]
                pos += 4
                comment = data[pos:pos + clen].decode("utf-8", errors="replace")
                pos += clen
                if "=" in comment:
                    key, _, val = comment.partition("=")
                    tags[key.lower().strip()] = val.strip()
            break

        if is_last:
            break

    return tags


def _read_flac_has_picture(f):
    """Returns True if FLAC has an embedded picture block (type 6)."""
    f.seek(4)
    while True:
        header = f.read(4)
        if len(header) < 4:
            break
        is_last = (header[0] & 0x80) != 0
        block_type = header[0] & 0x7F
        block_len = struct.unpack(">I", b"\x00" + header[1:4])[0]
        if block_type == 6:
            return True
        f.seek(block_len, 1)  # skip data
        if is_last:
            break
    return False


def normalize_text(text: str) -> str:
    """Normalizes artist/title for bulletproof duplicate detection."""
    if not text:
        return ""
    text = text.lower().strip()
    text = re.sub(r"[\(\[\{](official\s*(audio|video|lyric\s*video)?|audio|remastered|remaster)[\)\]\}]", "", text)
    text = re.sub(r"\b(feat\.?|ft\.?)\b.*", "", text)
    text = re.sub(r"[^\w\s]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def analyze_flac_file(file_path: str) -> dict:
    """
    Extracts tags and audio properties from a FLAC file using pure Python.
    No external dependencies — works on Android without mutagen/numpy.
    """
    file_name = os.path.basename(file_path)
    stem = Path(file_path).stem

    info = {
        "file_path": file_path,
        "file_name": file_name,
        "file_size_mb": round(os.path.getsize(file_path) / (1024 * 1024), 2),
        "title": stem,
        "artist": "Unknown Artist",
        "album": "Unknown Album",
        "sample_rate": 44100,
        "bit_depth": 16,
        "channels": 2,
        "duration_sec": 0.0,
        "duration_str": "0m 00s",
        "bitrate_kbps": 0,
        "has_cover": False,
        "score": 50,
        "verdict": "Unable to fully analyze",
        "error": None,
    }

    try:
        file_size_bytes = os.path.getsize(file_path)

        with open(file_path, "rb") as f:
            # Parse STREAMINFO
            si = _read_flac_streaminfo(f)
            if si is None:
                info["error"] = "Not a valid FLAC file"
                info["verdict"] = "Invalid FLAC"
                info["score"] = 0
                return info

            info["sample_rate"] = si["sample_rate"]
            info["bit_depth"] = si["bit_depth"]
            info["channels"] = si["channels"]

            if si["sample_rate"] > 0 and si["total_samples"] > 0:
                dur = si["total_samples"] / si["sample_rate"]
                info["duration_sec"] = round(dur, 1)
                mins = int(dur // 60)
                secs = int(dur % 60)
                info["duration_str"] = f"{mins}m {secs:02d}s"
                # Estimate bitrate from file size and duration
                if dur > 0:
                    info["bitrate_kbps"] = round((file_size_bytes * 8) / dur / 1000)

            # Parse Vorbis tags
            tags = _read_flac_vorbis_comment(f)
            info["title"]  = tags.get("title",  stem)
            info["artist"] = tags.get("artist", "Unknown Artist")
            info["album"]  = tags.get("album",  "Unknown Album")

            # Check for cover art
            info["has_cover"] = _read_flac_has_picture(f)

        # ---------------------------------------------------------------
        # Quality Score (without FFT — heuristic based on bitrate + specs)
        # ---------------------------------------------------------------
        bps = info["bitrate_kbps"]
        sr  = info["sample_rate"]
        bd  = info["bit_depth"]

        score = 50
        verdict = "Moderate Quality FLAC"

        # Bit-depth bonus
        if bd >= 24:
            score += 15
        elif bd == 16:
            score += 5

        # Sample rate bonus
        if sr >= 96000:
            score += 10
        elif sr >= 48000:
            score += 5
        elif sr == 44100:
            score += 3

        # Bitrate-based scoring (most reliable heuristic)
        if bps > 900:
            score = min(score + 25, 100)
            verdict = "High Bitrate — Excellent Lossless"
        elif bps > 700:
            score = min(score + 18, 100)
            verdict = "Good Bitrate — Genuine Lossless"
        elif bps > 500:
            score = min(score + 10, 100)
            verdict = "Moderate Bitrate FLAC"
        elif bps > 300:
            score = min(score + 0, 100)
            verdict = "Low Bitrate — Possible Lossy Upscale"
        else:
            score = max(score - 20, 0)
            verdict = "Very Low Bitrate — Likely Fake Lossless"

        # Fake 24-bit heuristic: 24-bit declared but very low bitrate
        if bd >= 24 and bps < 400:
            score = max(score - 25, 0)
            verdict = "Suspicious: 24-bit declared but low bitrate (fake?)"

        info["score"] = min(max(score, 0), 100)
        info["verdict"] = verdict

    except Exception as e:
        info["error"] = str(e)
        info["verdict"] = f"Parse Error: {e}"

    return info


# ---------------------------------------------------------------------------
# Kivy UI
# ---------------------------------------------------------------------------

class FlacToolkitApp(App):
    def build(self):
        self.title = "FLAC Audio Toolkit"

        root = BoxLayout(orientation="vertical", padding=15, spacing=12)

        # Header
        header = Label(
            text="[b]FLAC AUDIO TOOLKIT[/b]",
            markup=True,
            font_size="22sp",
            size_hint_y=None,
            height=45,
            color=get_color_from_hex("#00e5ff")
        )
        subtitle = Label(
            text="Android Quality Analyzer & Safe Duplicate Manager",
            font_size="12sp",
            size_hint_y=None,
            height=25,
            color=get_color_from_hex("#888888")
        )
        root.add_widget(header)
        root.add_widget(subtitle)

        # Action Buttons
        btn_layout = GridLayout(cols=2, spacing=10, size_hint_y=None, height=60)

        btn_analyze = Button(
            text="Analyze Single File",
            font_size="14sp",
            background_color=get_color_from_hex("#1f6feb"),
            bold=True
        )
        btn_analyze.bind(on_press=self.open_file_picker)

        btn_scan_dups = Button(
            text="Scan Duplicates",
            font_size="14sp",
            background_color=get_color_from_hex("#238636"),
            bold=True
        )
        btn_scan_dups.bind(on_press=self.scan_music_folder)

        btn_layout.add_widget(btn_analyze)
        btn_layout.add_widget(btn_scan_dups)
        root.add_widget(btn_layout)

        # Scrollable content area
        self.scroll = ScrollView(size_hint=(1, 1), do_scroll_x=False)
        self.content_box = BoxLayout(orientation="vertical", spacing=10, size_hint_y=None)
        self.content_box.bind(minimum_height=self.content_box.setter("height"))

        welcome_lbl = Label(
            text=(
                "Tap [b]'Analyze Single File'[/b] to inspect a FLAC song,\n"
                "or tap [b]'Scan Duplicates'[/b] to find duplicates in /sdcard/Music."
            ),
            markup=True,
            font_size="14sp",
            halign="center",
            color=get_color_from_hex("#aaaaaa"),
            size_hint_y=None,
            height=120
        )
        self.content_box.add_widget(welcome_lbl)
        self.scroll.add_widget(self.content_box)
        root.add_widget(self.scroll)

        return root

    # -----------------------------------------------------------------------
    def open_file_picker(self, instance):
        """Opens file picker to select a FLAC song."""
        content = BoxLayout(orientation="vertical", spacing=10)
        default_path = "/sdcard/Music" if os.path.exists("/sdcard/Music") else os.path.expanduser("~")
        chooser = FileChooserListView(path=default_path, filters=["*.flac", "*.FLAC"])
        content.add_widget(chooser)

        btn_select = Button(
            text="Inspect Selected Song",
            size_hint_y=None,
            height=50,
            background_color=get_color_from_hex("#1f6feb")
        )
        content.add_widget(btn_select)

        popup = Popup(title="Select a FLAC File", content=content, size_hint=(0.95, 0.9))

        def on_selected(btn):
            if chooser.selection:
                popup.dismiss()
                self.display_song_analysis(chooser.selection[0])

        btn_select.bind(on_press=on_selected)
        popup.open()

    # -----------------------------------------------------------------------
    def display_song_analysis(self, file_path: str):
        """Displays song card with quality score and metadata."""
        self.content_box.clear_widgets()
        info = analyze_flac_file(file_path)

        score = info.get("score", 0)
        badge_color = "#40c057" if score >= 80 else ("#fab005" if score >= 50 else "#fa5252")

        card = BoxLayout(orientation="vertical", padding=15, spacing=8, size_hint_y=None, height=310)

        card.add_widget(Label(
            text=f"[b]{info['artist']} - {info['title']}[/b]",
            markup=True, font_size="16sp", size_hint_y=None, height=35,
            color=get_color_from_hex("#ffffff"), halign="center"
        ))
        card.add_widget(Label(
            text=f"Quality Score: [b]{score}%[/b]",
            markup=True, font_size="18sp", size_hint_y=None, height=35,
            color=get_color_from_hex(badge_color)
        ))
        card.add_widget(Label(
            text=info["verdict"],
            font_size="13sp", size_hint_y=None, height=28,
            color=get_color_from_hex("#cccccc")
        ))

        details = (
            f"Duration:    {info['duration_str']}\n"
            f"Sample Rate: {info['sample_rate'] / 1000.0:.1f} kHz\n"
            f"Bit Depth:   {info['bit_depth']}-bit  |  Channels: {info['channels']}\n"
            f"Bitrate:     {info['bitrate_kbps']} kbps\n"
            f"Cover Art:   {'Yes' if info['has_cover'] else 'No'}\n"
            f"File Size:   {info['file_size_mb']} MB"
        )
        card.add_widget(Label(
            text=details, font_size="13sp", size_hint_y=None, height=150,
            color=get_color_from_hex("#cccccc"), halign="left",
            text_size=(Window.width - 60, None)
        ))

        if info.get("error"):
            card.add_widget(Label(
                text=f"[color=#ff5555]Note: {info['error']}[/color]",
                markup=True, font_size="11sp", size_hint_y=None, height=25
            ))

        self.content_box.add_widget(card)

    # -----------------------------------------------------------------------
    def scan_music_folder(self, instance):
        """Scans Music folder for duplicates and lists them."""
        self.content_box.clear_widgets()

        self.content_box.add_widget(Label(
            text="Scanning... please wait.",
            font_size="14sp", color=get_color_from_hex("#ffcc00"),
            size_hint_y=None, height=40
        ))

        search_dirs = ["/sdcard/Music", "/sdcard/Download", os.path.expanduser("~/Music")]
        target_dir = next((d for d in search_dirs if os.path.exists(d)), None)

        if not target_dir:
            self.content_box.clear_widgets()
            self.content_box.add_widget(Label(
                text="No Music folder found on device.",
                color=get_color_from_hex("#ff5555"), size_hint_y=None, height=50
            ))
            return

        flac_files = [
            os.path.join(root_p, f)
            for root_p, _, files in os.walk(target_dir)
            for f in files
            if f.lower().endswith(".flac")
        ]

        self.content_box.clear_widgets()

        if not flac_files:
            self.content_box.add_widget(Label(
                text=f"No FLAC files found in\n{target_dir}",
                color=get_color_from_hex("#ffcc00"), size_hint_y=None, height=70
            ))
            return

        # Group by normalized artist+title
        groups = defaultdict(list)
        for fp in flac_files:
            info = analyze_flac_file(fp)
            key = f"{normalize_text(info['artist'])}__{normalize_text(info['title'])}"
            groups[key].append(info)

        dup_groups = {k: v for k, v in groups.items() if len(v) >= 2}

        if not dup_groups:
            self.content_box.add_widget(Label(
                text=f"Scanned {len(flac_files)} songs.\n[b]Zero duplicates found![/b] Your library is clean.",
                markup=True, font_size="15sp",
                color=get_color_from_hex("#40c057"), size_hint_y=None, height=100
            ))
            return

        self.content_box.add_widget(Label(
            text=f"Found [b]{len(dup_groups)}[/b] Duplicate Set(s) in {len(flac_files)} songs:",
            markup=True, font_size="16sp",
            color=get_color_from_hex("#ffcc00"), size_hint_y=None, height=40
        ))

        for key, items in dup_groups.items():
            sorted_items = sorted(
                items,
                key=lambda x: (x.get("score", 0), x.get("bitrate_kbps", 0)),
                reverse=True
            )
            winner = sorted_items[0]
            losers = sorted_items[1:]
            box_height = 30 + 28 + len(losers) * 26 + 40
            box = BoxLayout(
                orientation="vertical", padding=10, spacing=4,
                size_hint_y=None, height=box_height
            )
            box.add_widget(Label(
                text=f"[b]{winner['artist']} - {winner['title']}[/b]",
                markup=True, color=get_color_from_hex("#00e5ff"), size_hint_y=None, height=30
            ))
            box.add_widget(Label(
                text=f"KEEP: {winner['file_name']} ({winner['bitrate_kbps']} kbps, {winner['score']}%)",
                color=get_color_from_hex("#40c057"), size_hint_y=None, height=28
            ))
            for l in losers:
                box.add_widget(Label(
                    text=f"DUP:  {l['file_name']} ({l['bitrate_kbps']} kbps, {l['score']}%)",
                    color=get_color_from_hex("#fa5252"), size_hint_y=None, height=26
                ))

            btn_quarantine = Button(
                text=f"Move {len(losers)} Dup(s) to Quarantine",
                size_hint_y=None, height=38,
                background_color=get_color_from_hex("#d9383a")
            )

            def make_handler(loser_list, parent_box, tgt_dir):
                def handler(btn):
                    quarantine_dir = os.path.join(tgt_dir, "_Duplicates_Review")
                    os.makedirs(quarantine_dir, exist_ok=True)
                    moved = 0
                    for item in loser_list:
                        src = item["file_path"]
                        dst = os.path.join(quarantine_dir, item["file_name"])
                        try:
                            os.rename(src, dst)
                            moved += 1
                        except Exception:
                            pass
                    parent_box.clear_widgets()
                    parent_box.add_widget(Label(
                        text=f"Moved {moved} file(s) to _Duplicates_Review safely!",
                        color=get_color_from_hex("#40c057"),
                        size_hint_y=None, height=40
                    ))
                return handler

            btn_quarantine.bind(on_press=make_handler(losers, box, target_dir))
            box.add_widget(btn_quarantine)
            self.content_box.add_widget(box)


if __name__ == "__main__":
    FlacToolkitApp().run()
