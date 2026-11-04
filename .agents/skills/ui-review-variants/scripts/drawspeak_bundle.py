#!/usr/bin/env python3
"""Emit a Drawspeak reply bundle. Run with python3 -I; stdout is paste-ready.

Default: an inline bundle (manifest + HTML fences) for small replies.
--out DIR: write DIR/review-manifest.json next to the files and print a
`drawspeak-bundle` pointer; Drawspeak downloads the files from the workspace.
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
import tempfile


def safe(path):
    return bool(path) and not path.startswith('/') and '\\' not in path and all(p not in ('', '.', '..') for p in path.split('/'))


def parse(text):
    """Port of the fenced text layer: 3+ ticks/tildes, tolerant info/attributes.

    Body bytes exclude exactly the separator newline before the closing fence.
    """
    lines = text.split('\n')
    blocks = []
    i = 0
    while i < len(lines):
        opening = re.fullmatch(r'\s*(`{3,}|~{3,})(.*?)\s*', lines[i])
        if not opening:
            i += 1
            continue
        fence, info = opening.groups()
        end = i + 1
        while end < len(lines) and not re.fullmatch(r'\s*' + re.escape(fence[0]) + '{' + str(len(fence)) + r',}\s*', lines[end]):
            end += 1
        if end == len(lines):
            break
        blocks.append((info, '\n'.join(lines[i + 1:end]).encode('utf-8')))
        i = end + 1
    manifest = None
    files = {}
    for info, body in blocks:
        words = info.lower().split()
        if 'drawspeak-manifest' in words:
            manifest = json.loads(body)
        elif 'drawspeak-file' in words:
            attr = re.search(r'''(?i)(?:^|\s)path\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''', info)
            path = next((g for g in attr.groups() if g is not None), None) if attr else None
            if path and safe(path):
                files[path] = body
    return manifest, files


def bundle(manifest, files):
    output = ['````drawspeak-manifest\n' + json.dumps(manifest, separators=(',', ':'), ensure_ascii=False) + '\n````']
    for path, data in files.items():
        if not safe(path):
            raise ValueError('unsafe bundle path: ' + path)
        text = data.decode('utf-8')
        if re.search(r'(?m)^\s*`{4,}\s*$', text):
            raise ValueError('HTML contains a closing four-backtick fence: ' + path)
        if len(data) > 2 * 1024 * 1024:
            raise ValueError('HTML exceeds 2 MiB: ' + path)
        output.append('````drawspeak-file path=' + json.dumps(path) + '\n' + text + '\n````')
    reply = '\n'.join(output) + '\n'
    decoded, received = parse(reply)
    if decoded != manifest or received != files:
        raise ValueError('bundle round-trip failed')
    return reply


def write_out(manifest, files, base):
    """Write base/review-manifest.json (paths relative to base) and return the pointer block."""
    for path, data in files.items():
        if not safe(path) or (base / path).read_bytes() != data:
            raise ValueError('file is not inside --out or changed: ' + path)
    for row in manifest['snapshots']:
        if row.get('htmlPath') is None and row.get('artifactKind') != 'image':
            row['htmlPath'] = next(iter(files))
        image = row.get('imagePath')
        if image:
            if not safe(image) or not (base / image).is_file():
                raise ValueError('image is not inside --out: ' + image)
            row['sha256'] = hashlib.sha256((base / image).read_bytes()).hexdigest()
    target = base / 'review-manifest.json'
    target.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    # Absolute, so it resolves the same whatever the agent's working directory.
    return '```drawspeak-bundle path=' + json.dumps(str(target.resolve())) + '\n```\n'


def self_test():
    for data in [b'<!doctype html>\n<html>hello</html>', b'<html>\n</html>\n', '<html>Zażółć 🖊</html>\r\n'.encode()]:
        manifest = {'schemaVersion': 1, 'snapshots': [{'htmlPath': 'a.html', 'htmlSha256': hashlib.sha256(data).hexdigest()}]}
        decoded, files = parse(bundle(manifest, {'a.html': data}))
        assert decoded['snapshots'][0]['htmlSha256'] == hashlib.sha256(files['a.html']).hexdigest()
    m, files = parse("~~~JSON DRAWSPEAK-MANIFEST\n{}\n~~~\n```DRAWSPEAK-FILE path='a.html'\n<html></html>\n```\n```drawspeak-file path=../x\nno\n```")
    assert m == {} and files == {'a.html': b'<html></html>'}
    with tempfile.TemporaryDirectory() as tmp:
        base = pathlib.Path(tmp)
        (base / 'p' / 'a').mkdir(parents=True)
        (base / 'p' / 'a' / 'x.html').write_bytes(b'<html></html>')
        manifest = {'schemaVersion': 1, 'snapshots': [{'screenId': 's'}]}
        line = write_out(manifest, {'p/a/x.html': b'<html></html>'}, base)
        written = json.loads((base / 'review-manifest.json').read_bytes())
        assert written['snapshots'][0]['htmlPath'] == 'p/a/x.html' and line.startswith('```drawspeak-bundle path="')
    print('Drawspeak bundle self-test passed', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--manifest', type=pathlib.Path)
    parser.add_argument('--screen-id', default='from-thread')
    parser.add_argument('--screen-title', default='From Thread')
    parser.add_argument('--proposal', default='a')
    parser.add_argument('--iteration', type=int, default=1)
    parser.add_argument('--parent')
    parser.add_argument('--summary')
    parser.add_argument('--addresses', nargs='*', default=[])
    parser.add_argument('--viewport', default='390x844@2')
    parser.add_argument('--out', type=pathlib.Path, help='bundle directory in the workspace; write review-manifest.json and print a pointer')
    parser.add_argument('files', nargs='*', type=pathlib.Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.files:
        parser.error('provide one or more HTML file paths (put files before --addresses)')
    if len(args.files) > (40 if args.out else 12):
        parser.error('at most 12 HTML files inline, or 40 with --out')
    base = args.out.resolve() if args.out else None
    match = re.fullmatch(r'(\d+)x(\d+)@([0-9.]+)x?', args.viewport)
    if not match:
        parser.error('--viewport must be WIDTHxHEIGHT@SCALE, e.g. 390x844@2')
    w, h, scale = int(match[1]), int(match[2]), float(match[3])
    if not (1 <= w <= 4096 and 1 <= h <= 4096 and .5 <= scale <= 4 and w * h * scale * scale <= 40000000):
        parser.error('viewport outside capture limits')
    if args.iteration < 1:
        parser.error('proposal iteration must be positive')
    manifest = json.loads(args.manifest.read_bytes()) if args.manifest else {'schemaVersion': 1, 'reviewId': 'thread-review', 'status': 'ready_for_review', 'snapshots': []}
    if manifest.get('schemaVersion') != 1:
        parser.error('unsupported schemaVersion')
    rows = manifest['snapshots']
    if args.manifest and len(rows) != len(args.files):
        parser.error('manifest snapshots and supplied HTML files must have equal counts (in the same order)')
    files = {}
    for i, source in enumerate(args.files):
        data = source.read_bytes()
        if base:
            try:
                path = source.resolve().relative_to(base).as_posix()
            except ValueError:
                parser.error('HTML file is outside --out: ' + str(source))
        if args.manifest:
            row = rows[i]
            path = path if base else row.get('htmlPath') or row.get('prototypePath') or source.name
        else:
            if not base:
                path = source.as_posix() if not source.is_absolute() and safe(source.as_posix()) else source.name
            row = {'screenId': args.screen_id, 'screenTitle': args.screen_title, 'proposalId': args.proposal,
                   'role': 'proposal', 'iteration': args.iteration + i, 'parentSnapshotId': args.parent,
                   'viewport': {'width': w, 'height': h, 'deviceScaleFactor': scale},
                   'widthPx': int(w * scale), 'heightPx': int(h * scale), 'renderPolicy': 'static-no-script',
                   'changeSummary': args.summary, 'addressedNoteIds': args.addresses}
            rows.append(row)
        if path in files:
            parser.error('duplicate HTML path: ' + path)
        row.update(artifactKind='html', htmlPath=path, htmlSha256=hashlib.sha256(data).hexdigest())
        row.setdefault('snapshotId', f"{row.get('screenId', args.screen_id)}-{row.get('proposalId', args.proposal)}-{row['htmlSha256'][:10]}")
        if not base:
            row.pop('imagePath', None)
            row.pop('sha256', None)
        files[path] = data
    if base:
        sys.stdout.write(write_out(manifest, files, base))
    else:
        sys.stdout.buffer.write(bundle(manifest, files).encode('utf-8'))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        sys.exit(str(error))
