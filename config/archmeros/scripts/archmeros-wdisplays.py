#!/usr/bin/env python3
"""Keep the active GTK theme, without oversized CSD margins in wdisplays."""
import configparser
import json
import os
from pathlib import Path
import tempfile


def main():
    home = Path.home()
    config_home = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
    data_home = Path(os.environ.get('XDG_DATA_HOME', home / '.local/share'))
    settings = configparser.ConfigParser(interpolation=None)
    settings.read(config_home / 'gtk-3.0/settings.ini')
    theme = settings.get('Settings', 'gtk-theme-name', fallback='Adwaita')
    roots = [home / '.themes', data_home / 'themes']
    roots += [Path(root) / 'themes' for root in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')]
    base = next((root / theme / 'gtk-3.0/gtk.css' for root in roots if (root / theme / 'gtk-3.0/gtk.css').is_file()), None)
    source = base.as_uri() if base else 'resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css'
    css = '@import url(' + json.dumps(source) + ');\n' + '''
window.csd decoration, window.csd decoration:backdrop {
    box-shadow: none;
    margin: 0;
    padding: 0;
    border-width: 0;
}
'''
    directory = data_home / 'themes/ArchMerOS-Wdisplays/gtk-3.0'
    directory.mkdir(parents=True, exist_ok=True)
    # Atomic replacement also covers two launch requests arriving together.
    for name in ('gtk.css', 'gtk-dark.css'):
        target = directory / name
        if target.exists() and target.read_text() == css:
            continue
        with tempfile.NamedTemporaryFile(mode='w', dir=directory, delete=False) as temp:
            temp.write(css)
        os.replace(temp.name, target)
    os.environ['GTK_THEME'] = 'ArchMerOS-Wdisplays'
    os.execvp('wdisplays', ['wdisplays'])


if __name__ == '__main__':
    main()
