#!/usr/bin/env python3
"""Exercise all size transitions in a disposable special workspace."""
import json
import os
from pathlib import Path
import subprocess
import time

scripts = Path.home() / '.config/archmeros/scripts'
name = 'archmeros-sizing-test'
cls = f'{name}-{os.getpid()}'


def query(command):
    return json.loads(subprocess.check_output(['hyprctl', command, '-j'], text=True))


def dispatch(*args):
    subprocess.run([str(scripts / 'archmeros-hyprctl-dispatch.sh'), *args], check=True, stdout=subprocess.DEVNULL)


def main():
    monitors = query('monitors')
    original = query('activewindow').get('address')
    focused = next(m for m in monitors if m['focused'])
    monitor = next(m for m in monitors if not m['specialWorkspace']['id'])
    assert not any(w['workspace']['name'] == 'special:' + name for w in query('clients'))
    assert not any(w['id'] == 90 and w['windows'] for w in query('workspaces'))
    proc = None
    try:
        dispatch('focusmonitor', monitor['name'])
        dispatch('workspace', '90')
        proc = subprocess.Popen(['kitty', '--class', cls, '-o', 'confirm_os_window_close=0', 'sleep', '60'],
                                env={**os.environ, 'ARCHMEROS_SKIP_HISTORY':'1'}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            window = next((w for w in query('clients') if w['class'] == cls), None)
            if window: break
            time.sleep(.03)
        assert window
        address = window['address']
        dispatch('focuswindow', 'address:' + address)
        dispatch('setfloating')
        dispatch('movetoworkspacesilent', 'special:' + name + ',address:' + address)
        subprocess.run(['hyprctl', 'eval', f'hl.dispatch(hl.dsp.workspace.toggle_special("{name}"))'], check=True, stdout=subprocess.DEVNULL)
        sizes = []
        for mode in ('small', 'full', 'full', 'full', 'full', 'shrink', 'shrink', 'shrink', 'shrink'):
            subprocess.run([str(scripts / 'archmeros-window-pop.sh'), mode], check=True)
            current = next(w for w in query('clients') if w['address'] == address)
            assert current['workspace']['name'] == 'special:' + name, f'{mode} ejected the window'
            assert current['floating']
            sizes.append(current['size'])
        assert len({tuple(s) for s in sizes}) == 4, sizes
        assert sizes[0] == sizes[-1] and sizes[3] == sizes[4], sizes
        print(f'PASS all four sizes retain assignment; repeated endpoints stable: {sizes}')
    finally:
        if proc:
            proc.terminate()
            proc.wait(timeout=5)
        dispatch('focusmonitor', monitor['name'])
        dispatch('workspace', str(monitor['activeWorkspace']['id']))
        dispatch('focusmonitor', focused['name'])
        if original: dispatch('focuswindow', 'address:' + original)


if __name__ == '__main__':
    main()
