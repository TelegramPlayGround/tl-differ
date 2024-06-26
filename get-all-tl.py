import os
import re
import json
import functools
import datetime
import itertools

from pathlib import Path
from subprocess import run, PIPE

# Layers which don't specify themselves in the common place
KNOWN_LAYERS = {
    1401439999: b'15',
    1404472374: b'16',
    1414003143: b'19',
}

tl = {}  # date: file contents

tdesktop = Path('tdesktop').resolve()
schemes = Path('schemes').resolve()

# we start not knowing in which branch we are
in_dev_branch = False

if not schemes.is_dir():
    schemes.mkdir(parents=True)

def in_dir(which):
    def wrapper(function):
        @functools.wraps(function)
        def wrapped(*args, **kwargs):
            previous = Path('.').resolve()
            try:
                if not which.is_dir():
                    which.mkdir(parents=True)

                os.chdir(which)
                function(*args, **kwargs)
            finally:
                os.chdir(previous)
        return wrapped
    return wrapper


class Field:
    def __init__(self, field):
        if ':' in field:
            self.name, self.type = field.split(':')
        else:
            self.name, self.type = None, field

    def to_dict(self):
        return {'name': self.name, 'type': self.type}

    def __eq__(self, other):
        return self.name == other.name and self.type == other.type

    def __repr__(self):
        return f'{self.name}:{self.type}'

class Definition:
    def __init__(self, line, *, function):
        self.function = function

        left, right = line.split(maxsplit=1)
        if '#' in left:
            self.name, self.id, *_ = left.split('#')  # there's a mess up with multiple #ids, hence the glob
            self.id = int(self.id, 16)
        else:
            self.name, self.id = left, None

        left, right = right.split('=')
        left.strip()
        self.fields = [Field(x) for x in left.split()] if left else []

        self.type = right.strip().rstrip(';').rstrip()

    def to_dict(self):
        return {
            'name': self.name,
            'id': self.id,
            'fields': [x.to_dict() for x in self.fields],
            'type': self.type
        }

    def __eq__(self, other):
        return (
            self.id == other.id
            and self.function == other.function
            and self.name == other.name
            and self.type == other.type
            and self.fields == other.fields
        )

    def __repr__(self):
        id_part = f'#{self.id:x}' if self.id is not None else ''
        field_part = (' '.join(map(repr, self.fields)) + ' ') if self.fields else ''
        return f"{self.name}{id_part} {field_part}= {self.type};"

class Scheme:
    def __init__(self, contents='// LAYER 0'):
        self.layer = None
        self.definitions = {}

        function = False
        for line in filter(bool, map(str.strip, contents.splitlines())):
            if line == '---functions---':
                function = True
            elif line == '---types---':
                function = False
            elif not line.startswith('//') and not line.startswith('#'):
                definition = Definition(line, function=function)
                self.definitions[definition.name] = definition
            elif line.startswith('// LAYER'):
                self.layer = int(line[8:])

    def to_dict(self):
        return {
            'layer': self.layer,
            'definitions': [x.to_dict() for x in sorted(self.definitions.items(), key=lambda t: t[0])]
        }

    def __repr__(self):
        return '\n'.join(map(repr, self.definitions.values()))

def ensure_dev_branch():
    global in_dev_branch
    if not in_dev_branch:
        run(('git', 'checkout', 'dev', '--force'))
        in_dev_branch = True

@in_dir(tdesktop)
def pull():
    if not (tdesktop / '.git').is_dir():
        run(('git', 'clone', 'git@github.com:telegramdesktop/tdesktop.git', '.'))

    ensure_dev_branch()
    run(('git', 'reset', '--hard', 'HEAD'))
    run(('git', 'pull'))


@in_dir(tdesktop)
def extract():
    global in_dev_branch
    tl_paths = list(map(Path, (
        'Telegram/SourceFiles/mtproto/scheme/api.tl',
        'Telegram/Resources/tl/api.tl',
        'Telegram/Resources/scheme.tl',
        'Telegram/SourceFiles/mtproto/scheme.tl'
    )))

    git_log = ['git', 'log', '--format=format:%H %ct', '--']
    layer_file = Path('Telegram/SourceFiles/mtproto/mtpCoreTypes.h')
    layer_re = re.compile(rb'static const mtpPrime mtpCurrentLayer = (\d+);')

    for tl_path in tl_paths:
        ensure_dev_branch()
        layer_tl_path = tl_path.with_name('layer.tl')

        for line in run(git_log + [tl_path], stdout=PIPE).stdout.decode().split('\n'):
            commit, date = line.split()
            date = int(date)
            out_path = schemes / f'{date}.tl'
            if out_path.is_file():
                continue  # we already have this scheme cached

            run(('git', 'checkout', commit, '--force'))
            in_dev_branch = False
            if not tl_path.is_file():
                continue  # last commit when this file was renamed

            layer = KNOWN_LAYERS.get(date)
            if layer is None and layer_file.is_file():
                with layer_file.open('rb') as fd:
                    match = layer_re.search(fd.read())
                    if match:
                        layer = match.group(1)

            with tl_path.open('rb') as fin:
                data = fin.read()

                if layer is not None:
                    data += b'\n// LAYER ' + layer + b'\n'
                elif b'// LAYER' not in data:
                    try:
                        with layer_tl_path.open('rb') as lfin:
                            data += b'\n' + lfin.read().strip() + b'\n'
                    except FileNotFoundError:
                        pass

            tl[date] = Scheme(data.decode('utf-8'))

            with out_path.open('wb') as fout:
                fout.write(data)

def load_tl():
    for tl_path in schemes.glob('*.tl'):
        with tl_path.open(encoding='utf-8') as fd:
            tl[int(tl_path.stem)] = Scheme(fd.read())

def gen_index():
    deltas = []
    previous = Scheme()
    for date, current in sorted(tl.items(), key=lambda t: t[0]):
        added = ([], [])
        removed = ([], [])
        changed = ([], [])

        old = set(previous.definitions)
        new = set(current.definitions)

        for item in (new - old):
            item = current.definitions[item]
            added[item.function].append(item.to_dict())

        for item in (old - new):
            item = previous.definitions[item]
            removed[item.function].append(item.to_dict())

        for item in (old & new):
            before = previous.definitions[item]
            after = current.definitions[item]
            if before != after:
                assert before.function == after.function
                changed[after.function].append({
                    'before': before.to_dict(),
                    'after': after.to_dict()
                })

        for li in itertools.chain(added, removed):
            li.sort(key=lambda x: x['name'])

        for li in changed:
            li.sort(key=lambda x: (x['before']['name'], x['after']['name']))

        deltas.append({
            'date': date,
            'layer': current.layer,
            'added': {'types': added[0], 'functions': added[1]},
            'removed': {'types': removed[0], 'functions': removed[1]},
            'changed': {'types': changed[0], 'functions': changed[1]}
        })
        previous = current

    return deltas

def gen_rss(deltas):
    last = None
    rev = 1
    for delta in sorted(deltas, key=lambda d: d['date']):
        date = datetime.datetime.fromtimestamp(delta['date'], datetime.timezone.utc).isoformat()
        if delta['layer'] == last:
            rev += 1
            revision = f' Revision {rev}'
        else:
            rev = 1
            last = delta['layer']
            revision = ''

        added = len(delta['added']['types']) + len(delta['added']['functions'])
        removed = len(delta['removed']['types']) + len(delta['removed']['functions'])
        changed = len(delta['changed']['types']) + len(delta['changed']['functions'])

        yield f'''<entry xml:lang="en">
        <title>Layer {delta['layer'] or '???'}{revision}</title>
        <published>{date}</published>
        <updated>{date}</updated>
        <link href="https://diff.telethon.dev/" type="text/html"/>
        <id>https://diff.telethon.dev/{delta['date']}</id>
        <content type="html">&lt;p&gt;{added} added, {removed} removed, {changed} changed&lt;/p&gt;</content>
        <author><name>TL Differ Team</name></author>
    </entry>
'''

def main():
    pull()
    extract()
    load_tl()
    deltas = gen_index()
    with open('diff.js', 'w') as fd:
        fd.write('DIFF=JSON.parse(')
        fd.write(repr(json.dumps(deltas, separators=(',', ':'), sort_keys=True)))
        fd.write(');\n')

    now = datetime.datetime.now(datetime.timezone.utc)
    with open('atom.xml', 'w') as fd:
        fd.write(f'''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
	<title>Type Language Differ</title>
	<link href="https://diff.telethon.dev/atom.xml" rel="self" type="application/atom+xml"/>
    <link href="https://diff.telethon.dev/"/>
    <updated>{now.isoformat()}</updated>
    <id>https://diff.telethon.dev/atom.xml</id>''')
        for entry in gen_rss(deltas):
            fd.write(entry)
        fd.write('</feed>')

if __name__ == '__main__':
    main()
