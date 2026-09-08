#!/usr/bin/env python3
"""Opt-in live regression: disposable Kitty windows on empty workspaces 9/90."""
import json
import os
from pathlib import Path
import subprocess
import time


SCRIPTS = Path.home() / '.config/archmeros/scripts'
SPECIAL = 'special:archmeros-scratchpad'
PREFIX = f'archmeros-scratchpad-test-{os.getpid()}-'
processes = []


def query(name):
    return json.loads(subprocess.check_output(['hyprctl', name, '-j'], text=True))


def dispatch(*args):
    subprocess.run([str(SCRIPTS / 'archmeros-hyprctl-dispatch.sh'), *args], check=True, stdout=subprocess.DEVNULL)


def action(script, *args):
    result = subprocess.run([str(SCRIPTS / script), *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)


def toggle():
    action('archmeros-scratchpad.sh')


def client(address):
    return next(w for w in query('clients') if w['address'] == address)


def visible():
    return any(m['specialWorkspace']['name'] == SPECIAL for m in query('monitors'))


def launch(name):
    cls = PREFIX + name
    processes.append(subprocess.Popen(
        ['kitty', '--class', cls, '-o', 'background_opacity=1', '-o', 'confirm_os_window_close=0', 'sleep', '120'],
        env={**os.environ, 'ARCHMEROS_SKIP_HISTORY': '1'},
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ))
    for _ in range(100):
        found = next((w for w in query('clients') if w['class'] == cls), None)
        if found:
            time.sleep(.15)
            return found['address']
        time.sleep(.04)
    raise RuntimeError('test window did not open')


def check(condition, label):
    assert condition, label
    print('PASS ' + label, flush=True)


def main():
    monitors = query('monitors')
    original = query('activewindow').get('address')
    original_monitor = next(m for m in monitors if m['focused'])
    assert not any(w['workspace']['name'] == SPECIAL for w in query('clients')), 'release your real scratchpad before this test'
    assert not any(w['id'] in (9, 90) and w['windows'] for w in query('workspaces')), 'workspaces 9 and 90 must be empty'
    assert not any(m['specialWorkspace']['id'] for m in monitors), 'close other special workspaces before this test'
    try:
        dispatch('workspace', '9')
        first = launch('first')
        dispatch('setfloating', 'address:' + first)
        dispatch('focuswindow', 'address:' + first)
        dispatch('resizeactive', 'exact', '900', '650')
        dispatch('centerwindow', '1')
        toggle()
        check(client(first)['workspace']['name'] == SPECIAL and not visible(), 'adopt and hide')
        toggle()
        check(visible() and query('activewindow')['address'] == first, 'show and focus')
        check(client(first)['size'] == [900, 650], 'preserve original size')
        spawned = launch('while-scratchpad-shown')
        check(client(spawned)['workspace']['name'] != SPECIAL, 'new applications do not join the scratchpad slot')
        dispatch('closewindow', 'address:' + spawned)
        dispatch('focuswindow', 'address:' + first)
        action('archmeros-window-pop.sh', 'shrink')
        check(client(first)['workspace']['name'] == SPECIAL and client(first)['floating'], 'existing size-cycle command keeps scratchpad assignment')
        dispatch('resizeactive', 'exact', '1000', '680')
        toggle()
        toggle()
        check(client(first)['size'] == [1000, 680], 'preserve manual sizing across toggles')
        toggle()
        subprocess.run(['hyprctl', 'reload'], check=True, stdout=subprocess.DEVNULL)
        toggle()
        check(query('activewindow')['address'] == first, 'recover slot across reload')

        side = next((m for m in monitors if m['id'] != original_monitor['id']), None)
        if side:
            dispatch('focusmonitor', side['name'])
            dispatch('workspace', '90')
            second = launch('second')
            dispatch('focuswindow', 'address:' + second)
            toggle()
            time.sleep(.1)
            current = client(first)
            check(current['monitor'] == side['id'] and query('activewindow')['address'] == first, 'summon on another monitor above another window')
            check(next(m for m in query('monitors') if m['id'] == side['id'])['activeWorkspace']['id'] == 90, 'normal workspace unchanged underneath')
            check(current['size'] == [1000, 680], 'preserve size on another monitor')
            action('archmeros-cycle-window.sh', 'all', 'next')
            check(client(first)['workspace']['id'] == 90 and client(first)['floating'] and not visible(), 'Super+Tab releases to cards')
            check(client(first)['size'] == [1000, 680], 'card release preserves size')
            toggle()
            toggle()
            action('archmeros-tile-window.sh')
            check(client(first)['workspace']['id'] == 90 and not client(first)['floating'] and not visible(), 'Super+Shift+V releases to tiling')
            dispatch('focuswindow', 'address:' + second)
            toggle()
            check(client(second)['workspace']['name'] == SPECIAL, 'released slot accepts another app')
            dispatch('closewindow', 'address:' + second)
            for _ in range(100):
                if not any(w['address'] == second for w in query('clients')):
                    break
                time.sleep(.02)
        else:
            action('archmeros-tile-window.sh')

        dispatch('focuswindow', 'address:' + first)
        toggle()
        check(client(first)['workspace']['name'] == SPECIAL, 'closing scratchpad frees slot')
        toggle()
        dispatch('resizeactive', 'exact', '1800', '950')
        toggle()
        smallest = min(monitors, key=lambda m: m['width'] * m['height'])
        dispatch('focusmonitor', smallest['name'])
        toggle()
        current = client(first)
        check(current['size'][0] < smallest['width'] and current['size'][1] <= smallest['height'] - sum(smallest['reserved'][1::2]), 'oversized scratchpad fits smaller screen')
        check(query('activewindow')['address'] == first, 'scratchpad stays focused')
        errors = subprocess.check_output(['hyprctl', 'configerrors'], text=True).strip()
        check(not errors, 'no compositor config errors')
    finally:
        for window in query('clients'):
            if window['class'].startswith(PREFIX):
                dispatch('closewindow', 'address:' + window['address'])
        for proc in processes:
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=3)
        for monitor in monitors:
            dispatch('focusmonitor', monitor['name'])
            dispatch('workspace', str(monitor['activeWorkspace']['id']))
        dispatch('focusmonitor', original_monitor['name'])
        if original:
            dispatch('focuswindow', 'address:' + original)


if __name__ == '__main__':
    main()
