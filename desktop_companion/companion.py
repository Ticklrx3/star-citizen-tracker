from __future__ import annotations

import json
import queue
import sys
import threading
from pathlib import Path
from urllib.parse import urlencode

import webview
from pynput import keyboard


APP_NAME = "SC Tracker Companion"
DEFAULT_CONFIG = {
    "app_url": "https://sc-tracker-tool.streamlit.app/",
    "quick_hotkey": "<ctrl>+<shift>+t",
    "full_hotkey": "<ctrl>+<shift>+f",
    "overlay_width": 470,
    "overlay_height": 780,
    "full_width": 1440,
    "full_height": 920,
}


def app_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def load_config() -> dict:
    path = app_dir() / "companion_config.json"
    config = dict(DEFAULT_CONFIG)
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                config.update({k: v for k, v in loaded.items() if v is not None})
        except Exception:
            pass
    return config


def build_url(base: str, *, quick: bool = False) -> str:
    base = base.strip() or DEFAULT_CONFIG["app_url"]
    if not base.startswith(("http://", "https://")):
        base = "https://" + base
    base = base.rstrip("/") + "/"
    if quick:
        return base + "?" + urlencode({"companion": "quick"})
    return base


class CompanionController:
    def __init__(self, full_window: webview.Window, quick_window: webview.Window):
        self.full_window = full_window
        self.quick_window = quick_window
        self.commands: queue.Queue[str] = queue.Queue()
        self.quick_visible = False
        self.full_visible = True

    def enqueue(self, command: str) -> None:
        # pynput callbacks should remain short; actual GUI work happens elsewhere.
        self.commands.put(command)

    def dispatch_loop(self) -> None:
        while True:
            command = self.commands.get()
            try:
                if command == "toggle_quick":
                    if self.quick_visible:
                        self.quick_window.hide()
                        self.quick_visible = False
                    else:
                        self.quick_window.show()
                        self.quick_visible = True
                elif command == "toggle_full":
                    if self.full_visible:
                        self.full_window.hide()
                        self.full_visible = False
                    else:
                        self.full_window.show()
                        self.full_visible = True
                elif command == "show_full":
                    self.full_window.show()
                    self.full_visible = True
            except Exception:
                # Keep hotkeys alive even if the native webview is temporarily busy.
                pass


def start_hotkeys(controller: CompanionController, config: dict) -> None:
    hotkeys = keyboard.GlobalHotKeys(
        {
            str(config["quick_hotkey"]): lambda: controller.enqueue("toggle_quick"),
            str(config["full_hotkey"]): lambda: controller.enqueue("toggle_full"),
        }
    )
    hotkeys.daemon = True
    hotkeys.start()

    dispatcher = threading.Thread(target=controller.dispatch_loop, daemon=True)
    dispatcher.start()


def main() -> None:
    config = load_config()
    app_url = build_url(str(config["app_url"]))
    quick_url = build_url(str(config["app_url"]), quick=True)

    # Downloads remain disabled; links to outside tools open in the normal browser.
    webview.settings["ALLOW_DOWNLOADS"] = False
    webview.settings["OPEN_EXTERNAL_LINKS_IN_BROWSER"] = True

    full = webview.create_window(
        APP_NAME,
        app_url,
        width=int(config["full_width"]),
        height=int(config["full_height"]),
        min_size=(900, 650),
        resizable=True,
        confirm_close=False,
        background_color="#06111f",
    )

    quick = webview.create_window(
        "SC Tracker Quick Entry",
        quick_url,
        width=int(config["overlay_width"]),
        height=int(config["overlay_height"]),
        min_size=(390, 580),
        resizable=True,
        hidden=True,
        frameless=True,
        easy_drag=True,
        shadow=True,
        on_top=True,
        background_color="#06111f",
    )

    controller = CompanionController(full, quick)

    storage = app_dir() / ".companion_webview"
    storage.mkdir(exist_ok=True)

    webview.start(
        start_hotkeys,
        args=(controller, config),
        private_mode=False,
        storage_path=str(storage),
        debug=False,
    )


if __name__ == "__main__":
    main()
