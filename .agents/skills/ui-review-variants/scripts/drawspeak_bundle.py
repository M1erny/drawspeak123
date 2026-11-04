#!/usr/bin/env python3
"""Emit a Drawspeak reply bundle. Run with python3 -I; stdout is paste-ready.

Default: an inline bundle (manifest + HTML fences) for small replies.
--out DIR: write DIR/review-manifest.json next to the files and print a
`drawspeak-bundle` pointer; Drawspeak downloads the files from the workspace.
--scan DIR: build the manifest from the folder layout, one file per screen:
  DIR/baseline/<screen>.png|html    -> the Now column of row <screen>
  DIR/prototypes/<id>/<screen>.html -> proposal <id> in the same row
Rows follow file names (prefix them 01-, 02-, ... for flow order).
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
import tempfile


# A Drawspeak row is one screen at device size. Taller files are boards of many
# mockups, unreadable on the canvas, so they are refused unless --allow-tall.
MAX_ASPECT = 3.0
MAX_HEIGHT_PX = 6000
ALLOW_TALL = False


def png_size(data):
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        return None
    return int.from_bytes(data[16:20], 'big'), int.from_bytes(data[20:24], 'big')


def check_tall(name, width, height, allow_tall):
    if allow_tall or not width or not height:
        return
    if height > MAX_ASPECT * width or height > MAX_HEIGHT_PX:
        raise ValueError(f'{name} is {width}x{height} px: export one screen per file at its device viewport '
                         '(a Drawspeak row holds Now, A and B of one screen), or pass --allow-tall')


def warn_board(name, text):
    sections = len(re.findall(r'(?i)<section\b', text))
    if sections > 4:
        print(f'warning: {name} has {sections} <section> elements; if it shows several screens, '
              'split it into one file per screen', file=sys.stderr)


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-') or 'screen'


def title_of(stem):
    words = re.sub(r'^\d+[-_ ]+', '', stem).replace('_', ' ').replace('-', ' ').strip()
    return words[:1].upper() + words[1:] if words else stem


def meta(name, text):
    tag = re.search(r'(?is)<meta\b[^>]*name\s*=\s*["\']' + re.escape(name) + r'["\'][^>]*>', text)
    if not tag:
        return None
    content = re.search(r'(?is)content\s*=\s*(?:"([^"]*)"|\'([^\']*)\')', tag.group(0))
    return next((g for g in content.groups() if g is not None), None) if content else None


def html_viewport(text, default):
    hint = re.search(r'(?i)data-review-viewport\s*=\s*["\']?(\d+)[x×](\d+)(?:@([0-9.]+)x?)?', text)
    if hint:
        return int(hint[1]), int(hint[2]), float(hint[3] or default[2])
    content = meta('viewport', text) or ''
    width = re.search(r'(?i)width\s*=\s*(\d+)', content)
    height = re.search(r'(?i)height\s*=\s*(\d+)', content)
    if width:
        return int(width[1]), int(height[1]) if height else default[1], default[2]
    return default


def scan(base, default_viewport, iteration, previous, titles, allow_tall):
    """Rows from DIR/baseline/* and DIR/prototypes/<id>/*, one screen per file."""
    sources = []
    if (base / 'baseline').is_dir():
        sources += [(None, p) for p in sorted((base / 'baseline').iterdir()) if p.suffix.lower() in ('.png', '.html')]
    if (base / 'prototypes').is_dir():
        for folder in sorted(p for p in (base / 'prototypes').iterdir() if p.is_dir()):
            sources += [(folder.name, p) for p in sorted(folder.iterdir()) if p.suffix.lower() in ('.png', '.html')]
    if not sources:
        raise ValueError(f'no files in {base}/baseline or {base}/prototypes/<id>')
    if len(sources) > 40:
        raise ValueError(f'{len(sources)} files; Drawspeak pulls at most 40 per reply: split the review into batches')
    # Latest prior iteration per (screen, proposal), so a new export continues the chain.
    last = {}
    for row in (previous or {}).get('snapshots', []):
        key = (row.get('screenId'), row.get('proposalId'))
        if row.get('role') == 'proposal' and row.get('iteration', 0) >= last.get(key, {}).get('iteration', 0):
            last[key] = row
    order = sorted({p.stem for _, p in sources})
    rows, files = [], {}
    for proposal, path in sorted(sources, key=lambda s: (order.index(s[1].stem), s[0] or '')):
        screen = slug(path.stem)
        relative = path.relative_to(base).as_posix()
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        row = {'snapshotId': f"{screen}-{proposal or 'baseline'}-{digest[:10]}",
               'screenId': screen, 'screenTitle': titles.get(screen) or title_of(path.stem),
               'role': 'baseline' if proposal is None else 'proposal', 'proposalId': proposal}
        if proposal is None:
            row.update(iteration=0, parentSnapshotId=None)
        else:
            prior = last.get((screen, proposal))
            row.update(iteration=prior['iteration'] + 1 if prior else iteration,
                       parentSnapshotId=prior['snapshotId'] if prior else None)
        if path.suffix.lower() == '.png':
            size = png_size(data)
            if not size:
                raise ValueError('not a PNG: ' + relative)
            check_tall(relative, *size, allow_tall)
            row.update(artifactKind='image', imagePath=relative, sha256=digest, widthPx=size[0], heightPx=size[1],
                       viewport={'width': size[0], 'height': size[1], 'deviceScaleFactor': 1})
        else:
            text = data.decode('utf-8')
            w, h, scale = html_viewport(text, default_viewport)
            check_tall(relative, w, h, allow_tall)
            warn_board(relative, text)
            row.update(artifactKind='html', htmlPath=relative, htmlSha256=digest, renderPolicy='static-no-script',
                       viewport={'width': w, 'height': h, 'deviceScaleFactor': scale},
                       widthPx=int(w * scale), heightPx=int(h * scale),
                       changeSummary=meta('review-summary', text),
                       addressedNoteIds=(meta('review-addresses', text) or '').split())
            files[relative] = data
        rows.append(row)
    return {'schemaVersion': 1, 'reviewId': slug(base.name), 'status': 'ready_for_review', 'snapshots': rows}, files


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
            data = (base / image).read_bytes()
            row['sha256'] = hashlib.sha256(data).hexdigest()
            size = png_size(data)
            if size:
                check_tall(image, *size, ALLOW_TALL)
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
    def png(width, height):
        return b'\x89PNG\r\n\x1a\n\0\0\0\rIHDR' + width.to_bytes(4, 'big') + height.to_bytes(4, 'big') + b'\0' * 8
    with tempfile.TemporaryDirectory() as tmp:
        base = pathlib.Path(tmp)
        for folder in ('baseline', 'prototypes/a', 'prototypes/b'):
            (base / folder).mkdir(parents=True)
        (base / 'baseline' / '01-launch.png').write_bytes(png(780, 1688))
        page = '<html data-review-viewport="390x844@2"><meta name="review-summary" content="Retry first"><body></body></html>'
        for p in ('a', 'b'):
            (base / 'prototypes' / p / '01-launch.html').write_text(page)
            (base / 'prototypes' / p / '02-first-run.html').write_text(page)
        manifest, files = scan(base, (390, 844, 2.0), 1, None, {}, False)
        rows = manifest['snapshots']
        assert [(r['screenId'], r['proposalId']) for r in rows] == [
            ('01-launch', None), ('01-launch', 'a'), ('01-launch', 'b'), ('02-first-run', 'a'), ('02-first-run', 'b')]
        assert rows[0]['screenTitle'] == 'Launch' and rows[1]['changeSummary'] == 'Retry first' and len(files) == 4
        assert rows[1]['viewport'] == {'width': 390, 'height': 844, 'deviceScaleFactor': 2.0}
        again, _ = scan(base, (390, 844, 2.0), 1, manifest, {}, False)
        assert again['snapshots'][1]['iteration'] == 2 and again['snapshots'][1]['parentSnapshotId'] == rows[1]['snapshotId']
        (base / 'baseline' / '01-launch.png').write_bytes(png(1440, 15096))
        try:
            scan(base, (390, 844, 2.0), 1, None, {}, False)
            raise AssertionError('tall board accepted')
        except ValueError:
            pass
        assert scan(base, (390, 844, 2.0), 1, None, {}, True)[0]['snapshots'][0]['heightPx'] == 15096
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
    parser.add_argument('--scan', type=pathlib.Path, help='review dir with baseline/ and prototypes/<id>/, one file per screen')
    parser.add_argument('--previous', type=pathlib.Path, help='with --scan: the prior review-manifest.json, to continue iterations')
    parser.add_argument('--title', action='append', default=[], metavar='SCREEN=TITLE', help='with --scan: a row title')
    parser.add_argument('--allow-tall', action='store_true', help='accept screens taller than 3x their width')
    parser.add_argument('files', nargs='*', type=pathlib.Path)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    global ALLOW_TALL
    ALLOW_TALL = args.allow_tall
    if args.scan:
        match = re.fullmatch(r'(\d+)x(\d+)@([0-9.]+)x?', args.viewport)
        if not match:
            parser.error('--viewport must be WIDTHxHEIGHT@SCALE, e.g. 390x844@2')
        titles = dict(t.split('=', 1) for t in args.title if '=' in t)
        previous = json.loads(args.previous.read_bytes()) if args.previous else None
        base = args.scan.resolve()
        manifest, files = scan(base, (int(match[1]), int(match[2]), float(match[3])), args.iteration, previous, titles, args.allow_tall)
        sys.stdout.write(write_out(manifest, files, base))
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
