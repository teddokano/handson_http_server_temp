#!/usr/bin/env python3
"""docs/article_draft.md を，NXPコミュニティ（Tech Blog）に貼り付けるHTMLに変換する．

docs/html_format_sample/sample.html の書き方に合わせる:
  - 章（##）は <div id="idxN" class="pt1"><h1><a target="_blank" name="idxN"></a>…</h1></div>
  - 節（###）は同じ形の <h2>．name 属性は "idx2.1" のようにドット区切り
  - 見出しの前後に <p>&nbsp;</p>，章の終わりに「▲ 目次に戻る」
  - ページ内リンクは <a class="smoothScroll" href="#idx…" target="_self">
  - 外部リンクは target="_blank" rel="noopener"
  - コードブロックは <li-code lang="markup">
  - 表は style="background: #F7F5F1;" border="1" width="100%"，見出し行は #EBE7DD
  - 囲み（> で始まる行）は <blockquote>
  - 図は <p class="lia-align-center">画像<br /><em>図2.1-1：説明</em></p>

画像（<li-image>）は，ブログのエディタでアップロードしたときに id が決まるので，
このスクリプトでは「【画像を挿入：img/…】」という目印を出す．エディタで目印の位置に画像を入れること．
--preview を付けると，画像を <img> で表示する確認用のHTMLも作る（ブラウザで見た目を確かめる用）．

ブログの本文は100,000文字までなので，2つの記事に分ける:
  - 本編   … 0〜6章と付録A（docs/blog/article_blog_main.html）
  - 付録編 … 付録B〜G（docs/blog/article_blog_appendix.html）
記事の元のファイルは1つのまま（会場ではこのMarkdownをVS Codeで読む）．
もう一方の記事へのリンクは，その記事のURLが決まるまで「【本編のURL】」「【付録編のURL】」という目印になる．
URLが決まったら --main-url と --appendix-url で指定して作り直す．

使い方:
  python3 tools/md2nxp_html.py --preview
  python3 tools/md2nxp_html.py --main-url https://… --appendix-url https://…
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'docs' / 'article_draft.md'
OUTDIR = ROOT / 'docs' / 'blog'

FOOTER = '''<p>変更履歴：【公開日】：初版</p>
<p>=========================</p>
<p>本投稿の「Comment」欄にコメントをいただいても、現在返信に対応しておりません。お手数をおかけしますが、お問い合わせの際には「NXPへの技術質問 - 問い合わせ方法 (日本語ブログ)」をご参照ください。（既に弊社NXP代理店、もしくはNXPとお付き合いのある方は、直接担当者へご質問いただいてもかまいません。）</p>'''

BLANK = '<p>&nbsp;</p>'


def idx(anchor: str) -> str:
    """記事の <a id> を sample.html の idx 形式にする．"""
    m = re.fullmatch(r'chapter(\d+)', anchor)
    if m:
        return 'idx' + m.group(1)
    m = re.fullmatch(r'appendix([A-Z])', anchor)
    if m:
        return 'idx' + m.group(1)
    return 'idx' + anchor


SPLIT_AT = 'appendixB'   # この章から後ろを付録編にする
POST_NAME = {'main': '本編', 'appx': '付録編'}


class Conv:
    def __init__(self, preview: bool, urls: dict):
        self.preview = preview
        self.urls = urls          # {'main': URL, 'appx': URL}
        self.anchor_post = {}     # 記事の <a id> → 'main' / 'appx'
        self.cur_post = 'main'

    def href(self, anchor: str):
        """ページ内リンクの <a ...> の開始タグ．もう一方の記事なら，その記事のURLへのリンクにする．"""
        post = self.anchor_post.get(anchor, self.cur_post)
        if post == self.cur_post:
            return f'<a class="smoothScroll" href="#{idx(anchor)}" target="_self">'
        return f'<a href="{html.escape(self.urls[post])}#{idx(anchor)}" target="_blank" rel="noopener">'

    # ------------------------------------------------------------ inline
    def inline(self, text: str) -> str:
        stash = []

        def keep(s):
            stash.append(s)
            return f'\x00{len(stash) - 1}\x00'

        # 表のセルの中で \| と書いた縦棒は，HTMLでは | に戻す（コードの中も同じ）
        text = text.replace('\\|', '|')
        # インラインコード（先に退避して，中身はエスケープだけ）
        text = re.sub(r'`([^`]+)`', lambda m: keep('<code>' + html.escape(m.group(1), quote=False) + '</code>'), text)
        text = html.escape(text, quote=False)

        def link(m):
            label, url = m.group(1), m.group(2)
            if url.startswith('#'):
                return keep(self.href(url[1:])) + label + keep('</a>')
            return keep(f'<a href="{html.escape(url)}" target="_blank" rel="noopener">') + label + keep('</a>')

        text = re.sub(r'\[((?:[^\[\]]|\[[^\]]*\])+)\]\(([^)\s]+)\)', link, text)
        text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
        while '\x00' in text:
            text = re.sub(r'\x00(\d+)\x00', lambda m: stash[int(m.group(1))], text)
        return text

    # ------------------------------------------------------------ blocks
    def image(self, alt, src, caption):
        if self.preview:
            img = f'<img src="../{html.escape(src)}" alt="{html.escape(alt)}" style="max-width:100%;" />'
        else:
            img = f'【画像を挿入：{html.escape(src)}】'
        cap = ''
        if caption:
            num, rest = caption
            cap = f'<br /><em>{html.escape(num)}：{self.inline(rest)}</em>'
        return f'<p class="lia-align-center">{img}{cap}</p>'

    def table(self, rows):
        def cells(line):
            line = line.strip()
            if line.startswith('|'):
                line = line[1:]
            if line.endswith('|') and not line.endswith('\\|'):
                line = line[:-1]
            parts, cur, i = [], '', 0
            in_code = False
            while i < len(line):
                c = line[i]
                if c == '`':
                    in_code = not in_code
                if c == '\\' and i + 1 < len(line) and line[i + 1] == '|':
                    cur += '\\|'
                    i += 2
                    continue
                if c == '|' and not in_code:
                    parts.append(cur.strip())
                    cur = ''
                else:
                    cur += c
                i += 1
            parts.append(cur.strip())
            return parts

        body = [r for r in rows if not re.fullmatch(r'\s*\|?\s*:?-{3,}.*', r)]
        out = ['<table style="background: #F7F5F1;" border="1" width="100%">', '<tbody>']
        for n, r in enumerate(body):
            tr = '<tr style="background: #EBE7DD;">' if n == 0 else '<tr>'
            out.append(tr)
            for c in cells(r):
                out.append(f'<td height="25px">{self.inline(c)}</td>')
            out.append('</tr>')
        out += ['</tbody>', '</table>']
        return '\n'.join(out)

    def code(self, lines):
        return '<li-code lang="markup">' + html.escape('\n'.join(lines), quote=False) + '</li-code>'

    def para(self, lines):
        # 太字だけの行（「**✔ ここまでできればOK**」「**コラム: …**」など）は，sample.html と同じく独立した段落にする
        paras, cur = [], ''
        for l in lines:
            l = l.strip()
            if re.fullmatch(r'\*\*.+\*\*', l):
                if cur:
                    paras.append(cur)
                    cur = ''
                paras.append(self.inline(l))
            else:
                cur += self.inline(l)
        if cur:
            paras.append(cur)
        return '\n'.join(f'<p>{x}</p>' for x in paras)

    def lists(self, lines):
        """インデントで入れ子になったリスト．続きの行（インデントだけ）は <br /> でつなぐ．"""
        items = []  # (indent, ordered, start, text_lines, code_blocks)
        i = 0
        while i < len(lines):
            m = re.match(r'^(\s*)([-*]|\d+\.)\s+(.*)$', lines[i])
            if m:
                ordered = m.group(2)[0].isdigit()
                items.append([len(m.group(1)), ordered, int(m.group(2)[:-1]) if ordered else 1, [m.group(3)], []])
                i += 1
                continue
            l = lines[i]
            if l.strip().startswith('```') and items:
                ind = len(l) - len(l.lstrip())
                j = i + 1
                code = []
                while j < len(lines) and not lines[j].strip().startswith('```'):
                    code.append(lines[j][ind:] if len(lines[j]) >= ind else lines[j].strip())
                    j += 1
                items[-1][4].append(('code', code))
                i = j + 1
                continue
            if items and l.strip():
                if items[-1][4]:
                    items[-1][4].append(('text', [l.strip()]))
                else:
                    items[-1][3].append(l.strip())
            i += 1

        out = []
        stack = []  # (indent, tag)

        def item_html(it):
            text = [t.strip() for t in it[3]]
            s = '<br />'.join(self.inline(t) for t in text)
            for kind, payload in it[4]:
                if kind == 'code':
                    s += '\n' + self.code(payload) + '\n'
                else:
                    s += '<br />'.join(self.inline(x) for x in payload)
            return s

        for it in items:
            indent, ordered = it[0], it[1]
            while stack and indent < stack[-1][0]:
                out.append(f'</{stack.pop()[1]}>')
            if not stack or indent > stack[-1][0]:
                tag = 'ol' if ordered else 'ul'
                start = f' start="{it[2]}"' if ordered and it[2] != 1 else ''
                out.append(f'<{tag}{start}>')
                stack.append((indent, tag))
            out.append(f'<li>{item_html(it)}</li>')
        while stack:
            out.append(f'</{stack.pop()[1]}>')
        return '\n'.join(out)

    def blocks(self, lines):
        out = []
        i = 0
        n = len(lines)
        while i < n:
            l = lines[i]
            s = l.strip()
            if not s or s == '---':
                i += 1
                continue
            if s.startswith('```'):
                j = i + 1
                code = []
                while j < n and not lines[j].strip().startswith('```'):
                    code.append(lines[j])
                    j += 1
                out.append(self.code(code))
                i = j + 1
                continue
            if s.startswith('>'):
                j = i
                inner = []
                while j < n and lines[j].strip().startswith('>'):
                    t = lines[j].strip()[1:]
                    inner.append(t[1:] if t.startswith(' ') else t)
                    j += 1
                out.append('<blockquote>\n' + self.blocks(inner) + '\n</blockquote>')
                i = j
                continue
            if s.startswith('|'):
                j = i
                rows = []
                while j < n and lines[j].strip().startswith('|'):
                    rows.append(lines[j])
                    j += 1
                out.append(self.table(rows))
                i = j
                continue
            m = re.fullmatch(r'!\[([^\]]*)\]\(([^)]+)\)', s)
            if m:
                caption = None
                j = i + 1
                while j < n and not lines[j].strip():
                    j += 1
                if j < n:
                    c = re.fullmatch(r'\*\*(図[0-9A-Z.]+-[0-9]+)\*\*\s*(.+)', lines[j].strip())
                    if c:
                        caption = (c.group(1), c.group(2))
                        i = j
                out.append(self.image(m.group(1), m.group(2), caption))
                i += 1
                continue
            if re.match(r'^\s*([-*]|\d+\.)\s+', l):
                j = i
                block = []
                while j < n:
                    t = lines[j]
                    if not t.strip():
                        # 空行の次がリストの続き（インデントあり）なら続ける
                        k = j + 1
                        if k < n and (re.match(r'^\s+\S', lines[k]) or re.match(r'^\s*([-*]|\d+\.)\s+', lines[k])):
                            j += 1
                            continue
                        break
                    if (re.match(r'^\s*([-*]|\d+\.)\s+', t) or t.startswith((' ', '\t'))):
                        block.append(t)
                        j += 1
                        continue
                    break
                out.append(self.lists(block))
                i = j
                continue
            if s.startswith('####'):
                out.append(f'<p><strong>{self.inline(s.lstrip("#").strip())}</strong></p>')
                i += 1
                continue
            j = i
            para = []
            while j < n:
                t = lines[j].strip()
                if (not t or t.startswith(('```', '>', '|', '#', '!['))
                        or re.match(r'^([-*]|\d+\.)\s+', t) or t == '---'):
                    break
                para.append(lines[j])
                j += 1
            out.append(self.para(para))
            i = j
        return '\n'.join(out)

    # ------------------------------------------------------------ document
    def convert(self, md: str) -> dict:
        md = re.sub(r'<!--.*?-->', '', md, flags=re.S)
        lines = md.split('\n')

        # 先頭のタイトル（# …）はブログのタイトル欄に入れるので本文から外す．目次（## 目次）は作り直す
        sections = []  # (level, anchor, title, body_lines)
        pre = []
        cur = None
        pending = None
        skip_toc = False
        in_fence = False
        for l in lines:
            # コードブロックの中の「# コマンド例…」を見出しと取り違えないようにする
            if l.strip().lstrip('>').strip().startswith('```'):
                in_fence = not in_fence
                if not skip_toc:
                    (cur[3] if cur else pre).append(l)
                continue
            if in_fence:
                if not skip_toc:
                    (cur[3] if cur else pre).append(l)
                continue
            m = re.fullmatch(r'<a id="([^"]+)"></a>', l.strip())
            if m:
                pending = m.group(1)
                continue
            h = re.match(r'^(#{1,3}) (.+)$', l)
            if h:
                level = len(h.group(1))
                title = h.group(2).strip()
                if level == 1:
                    continue
                if level == 2 and title == '目次':
                    skip_toc = True
                    cur = None
                    continue
                skip_toc = False
                cur = [level, pending, title, []]
                sections.append(cur)
                pending = None
                continue
            if skip_toc:
                continue
            (cur[3] if cur else pre).append(l)

        # 本編と付録編に分ける
        post = 'main'
        for sec in sections:
            if sec[0] == 2 and sec[1] == SPLIT_AT:
                post = 'appx'
            sec.append(post)
            if sec[1]:
                self.anchor_post[sec[1]] = post
        return {p: self.render(p, pre if p == 'main' else [], [x for x in sections if x[4] == p], sections)
                for p in ('main', 'appx')}

    def toc_html(self, items):
        toc = ['<ul>']
        open_sub = False
        for level, anchor, title, _, _ in items:
            if not anchor:
                continue
            link = f'{self.href(anchor)}{self.inline(title)}</a>'
            if level == 2:
                if open_sub:
                    toc.append('</ul>')
                    open_sub = False
                toc.append(f'<li>{link}</li>')
            else:
                if not open_sub:
                    toc.append('<ul>')
                    open_sub = True
                toc.append(f'<li>{link}</li>')
        if open_sub:
            toc.append('</ul>')
        toc.append('</ul>')
        return '\n'.join(toc)

    def render(self, post, pre, sections, all_sections):
        self.cur_post = post
        other = 'appx' if post == 'main' else 'main'
        other_url = html.escape(self.urls[other])
        out = []
        if pre:
            out.append(self.blocks(pre))

        # 2つの記事に分けていることの案内
        if post == 'main':
            out.append(f'<p>この記事は，本編（0〜6章と付録A）と<a href="{other_url}" target="_blank" rel="noopener">付録編（付録B〜G）</a>の2つに分けて掲載しています．付録編には，コマンド例の一覧（PowerShell／bash・zsh），早く終わった方向けの課題，他のFRDMボードで試す方法，用語集，よくある質問などがあります．</p>')
        else:
            out.append(f'<p>この記事は，「Zephyrデビュー会 〜FRDM-MCXN947でつまずかず動かす90分〜」の<strong>付録編</strong>です．手順の本文（0〜6章）と，うまくいかないときの対処（付録A）は，<a href="{other_url}" target="_blank" rel="noopener">本編</a>にあります．</p>')

        # 目次（もう一方の記事の章も，その記事へのリンクとして載せる）
        out += [BLANK, '<div id="idxtoc" class="pt1">',
                '<h1><a target="_blank" name="idxtoc"></a>目次</h1>', '</div>', BLANK]
        out.append(self.toc_html(sections))
        others = [x for x in all_sections if x[4] != post and x[0] == 2]
        if others:
            out.append(f'<p>{POST_NAME[other]}（別の記事）:</p>')
            out.append(self.toc_html(others))

        back = '<p class="lia-align-right"><a class="smoothScroll" href="#idxtoc" target="_self">▲ 目次に戻る</a></p>'
        for n, (level, anchor, title, body, _) in enumerate(sections):
            tag = 'h1' if level == 2 else 'h2'
            if level == 2 and n > 0:
                out.append(back)
            if anchor:
                a = idx(anchor)
                name = a.replace('-', '.') if level == 3 else a
                head = f'<div id="{a}" class="pt1">\n<{tag}><a target="_blank" name="{name}"></a>{self.inline(title)}</{tag}>\n</div>'
            else:
                head = f'<{tag}>{self.inline(title)}</{tag}>'
            out += [BLANK, head, BLANK]
            out.append(self.blocks(body))
        out.append(back)
        out.append(FOOTER)
        return '\n'.join(x for x in out if x) + '\n'


PREVIEW_HEAD = '''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><title>プレビュー</title>
<style>
body{max-width:960px;margin:24px auto;padding:0 16px;font-family:"Hiragino Sans","Noto Sans JP",sans-serif;line-height:1.7;color:#222}
li-code{display:block;white-space:pre;font-family:Menlo,monospace;background:#f4f4f4;border:1px solid #ddd;padding:8px 12px;margin:8px 0;overflow-x:auto}
blockquote{border-left:4px solid #ccc;margin:12px 0;padding:4px 16px;background:#fafafa}
.lia-align-center{text-align:center}.lia-align-right{text-align:right}
code{background:#f0f0f0;padding:0 3px}
</style></head><body>
'''


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def main():
    preview = '--preview' in sys.argv
    urls = {'main': arg('--main-url', '【本編のURL】'), 'appx': arg('--appendix-url', '【付録編のURL】')}
    md = SRC.read_text(encoding='utf-8')
    OUTDIR.mkdir(exist_ok=True)
    names = {'main': 'article_blog_main', 'appx': 'article_blog_appendix'}
    for p, body in Conv(preview=False, urls=urls).convert(md).items():
        f = OUTDIR / f'{names[p]}.html'
        f.write_text(body, encoding='utf-8')
        print(f'wrote {f}  ({len(body):,} 文字)')
    if preview:
        for p, body in Conv(preview=True, urls=urls).convert(md).items():
            f = OUTDIR / f'{names[p]}_preview.html'
            f.write_text(PREVIEW_HEAD + body + '</body></html>\n', encoding='utf-8')
            print('wrote', f)


if __name__ == '__main__':
    main()
