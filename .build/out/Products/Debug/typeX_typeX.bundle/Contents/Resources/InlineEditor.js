(() => {
  let source = '', blocks = [], active = null, undo = [], redo = [], composing = false;
  const notify = () => window.webkit?.messageHandlers.editMarkdown.postMessage({source});
  function write(value) {
    if (!active) return;
    const b = blocks[active.index];
    if (b.end < source.length && value && !value.endsWith('\n')) value += '\n';
    const delta = value.length - (b.end - b.start);
    source = source.slice(0, b.start) + value + source.slice(b.end);
    b.end = b.start + value.length;
    for (let i = active.index + 1; i < blocks.length; i++) { blocks[i].start += delta; blocks[i].end += delta; }
    document.querySelectorAll('[data-edit-block]').forEach(el => {
      const range = blocks[+el.dataset.editBlock];
      if (range) {
        el.dataset.sourceStart = source.slice(0, range.start).split('\n').length - 1;
        el.dataset.sourceEnd = +el.dataset.sourceStart + source.slice(range.start, range.end).replace(/\n$/, '').split('\n').length - 1;
      }
    });
    notify();
  }
  function resize() { if (active) { active.area.style.height = 'auto'; active.area.style.height = Math.max(90, active.area.scrollHeight) + 'px'; } }
  function insert(value, cursor) {
    if (!active) return;
    const a = active.area;
    a.value = value;
    write(value); resize(); a.focus();
    a.setSelectionRange(cursor ?? value.length, cursor ?? value.length);
    active.menu.hidden = true;
  }
  function heading(level) {
    if (!active) return;
    let value = active.area.value.replace(/^ {0,3}#{1,6}[ \t]+/, '').replace(/\n[=-]+\s*$/, '');
    insert((level ? '#'.repeat(level) + ' ' : '') + value);
  }
  function code(language) {
    if (!active) return;
    const value = active.area.value.replace(/^\/[\w-]*\s*$/, '');
    const match = value.match(/^(`{3,}|~{3,})[^\n]*\n([\s\S]*?)\n\1\s*$/);
    const body = match ? match[2] : value.replace(/\n$/, '');
    const max = Math.max(2, ...[...body.matchAll(/`+/g)].map(m => m[0].length));
    const fence = '`'.repeat(max + 1), prefix = fence + language + '\n';
    insert(prefix + body + '\n' + fence + '\n', prefix.length);
  }
  function stripSlash() {
    if (!active) return;
    const a = active.area, before = a.value.slice(0,a.selectionStart);
    const match = before.match(/(^|\s)\/([^\s/]*)$/);
    if (match) {const start=match.index+match[1].length; insert(a.value.slice(0,start)+a.value.slice(a.selectionStart),start);}
  }
  function prefixBlock(prefix) {
    if (!active) return;
    const a=active.area;
    insert(a.value.split('\n').map((line,i) => !line && i ? line : prefix+line.replace(/^(?:[-*+] |\d+\. |> |- \[ \] )/, '')).join('\n'));
  }
  function wrapSelection(left, right=left) {
    if (!active || composing) return;
    const a=active.area,start=a.selectionStart,end=a.selectionEnd,value=a.value;
    const text=value.slice(start,end);
    if(value.slice(Math.max(0,start-left.length),start)===left && value.slice(end,end+right.length)===right) {
      insert(value.slice(0,start-left.length)+text+value.slice(end+right.length),start-left.length);
      a.setSelectionRange(start-left.length,end-left.length);
    } else {
      insert(value.slice(0,start)+left+text+right+value.slice(end),start+left.length);
      a.setSelectionRange(start+left.length,end+left.length);
    }
  }
  const commands = [
    ['Heading 1', () => heading(1)], ['Heading 2', () => heading(2)],
    ['Heading 3', () => heading(3)], ['Code Block', () => code('')],
    ['Bullet List', () => prefixBlock('- ')], ['Numbered List', () => prefixBlock('1. ')],
    ['Task List', () => prefixBlock('- [ ] ')], ['Quote', () => prefixBlock('> ')],
    ['Table', () => insert('| Column 1 | Column 2 |\n| --- | --- |\n|  |  |\n\n'+active.area.value)],
    ['Divider', () => insert('---\n\n'+active.area.value)]
  ];
  function handleInputKey(e) {
    if (!active || composing || e.isComposing) return false;
    const a=active.area,start=a.selectionStart,end=a.selectionEnd,value=a.value;
    const lineStart=value.lastIndexOf('\n',start-1)+1, before=value.slice(lineStart,start);
    const preceding=value.slice(0,lineStart);
    const fenced=(preceding.match(/^ {0,3}(?:`{3,}|~{3,})/gm)||[]).length%2===1;
    const fence=before.match(/^ {0,3}(`{3,})([A-Za-z0-9_+#.\-]*)$/);
    if (!fenced && start===end && fence && (e.key==='Enter'||e.key===' ')) {
      e.preventDefault();
      const prefix=fence[1]+fence[2]+'\n';
      insert(value.slice(0,lineStart)+prefix+'\n'+fence[1]+value.slice(end),lineStart+prefix.length);return true;
    }
    if (!fenced && e.key===' ' && /^\[\s?\]$/.test(before)) {
      e.preventDefault();insert(value.slice(0,lineStart)+'- [ ] '+value.slice(end),lineStart+6);return true;
    }
    if (!fenced && e.key==='Enter' && !e.shiftKey && start===end) {
      const list=before.match(/^(\s*)([-*+] |\d+\. |> )((?:\[[ xX]\] )?)(.*)$/);
      if(list) {
        e.preventDefault();
        if (!list[4].trim()) {insert(value.slice(0,lineStart)+value.slice(end),lineStart);return true;}
        const marker=/^\d/.test(list[2]) ? (parseInt(list[2])+1)+'. ' : list[2];
        const next='\n'+list[1]+marker+(list[3] ? '[ ] ' : '');
        insert(value.slice(0,start)+next+value.slice(end),start+next.length);return true;
      }
    }
    if(e.key==='Tab') {
      e.preventDefault();
      if(e.shiftKey) {
        const remove=value.slice(lineStart).match(/^(?: {1,2}|\t)/)?.[0].length||0;
        insert(value.slice(0,lineStart)+value.slice(lineStart+remove),Math.max(lineStart,start-remove));
      } else if(fenced) insert(value.slice(0,start)+'  '+value.slice(end),start+2);
      else insert(value.slice(0,lineStart)+'  '+value.slice(lineStart),start+2);
      return true;
    }
    return false;
  }
  function activate(index) {
    if (active?.index === index) return;
    if (active) { commit(index); return; }
    const el = document.querySelector(`[data-edit-block="${index}"]`), b = blocks[index];
    if (!el || !b) return;
    const original = source;
    const content = source.slice(b.start, b.end);
    const area = document.createElement('textarea'); area.className = 'block-input'; area.value = content;
    area.setAttribute('aria-label', 'Edit Markdown block'); area.spellcheck = true;
    const menu = document.createElement('div'); menu.className = 'slash-menu'; menu.hidden = true;
    commands.forEach(([label, action]) => { const button = document.createElement('button'); button.textContent = label; button.onmousedown = e => e.preventDefault(); button.onclick = () => {stripSlash();action();}; menu.append(button); });
    el.replaceChildren(area, menu); el.classList.add('editing');
    active = {index, area, menu, original}; resize(); area.focus();
    area.addEventListener('compositionstart', () => { composing = true; });
    area.addEventListener('compositionend', () => { composing = false; write(area.value); resize(); });
    area.oninput = event => {
      if (!composing && !event.isComposing) write(area.value);
      resize();
      const slash=area.value.slice(0,area.selectionStart).match(/(^|\s)\/([^\s/]*)$/);
      menu.hidden = !slash;
      const query = (slash?.[2] || '').toLowerCase();
      [...menu.children].forEach(b => { b.hidden = !b.textContent.toLowerCase().includes(query); });
    };
    area.onkeydown = e => {
      if (e.isComposing || composing) return;
      if (e.key === 'Escape') { e.preventDefault(); commit(); return; }
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') { e.preventDefault(); commit(); return; }
      if (e.key === 'Enter' && !menu.hidden) { const first = [...menu.children].find(b => !b.hidden); if(first) {e.preventDefault();first.click();return;} }
      handleInputKey(e);
    };
  }
  function commit(nextBlock = null) {
    if (typeof nextBlock !== "number") nextBlock = null;
    if (!active || composing) return;
    write(active.area.value);
    if (source !== active.original) { undo.push(active.original); redo = []; }
    active = null;
    window.webkit?.messageHandlers.commitMarkdown.postMessage({source, scroll: window.scrollY, nextBlock});
  }
  window.typeXInline = {
    setup(value, ranges) {
      source = value; blocks = ranges;
      document.querySelectorAll('[data-edit-block]').forEach(el => {
        el.tabIndex = 0; el.setAttribute('aria-label','Editable Markdown block');
        el.onclick = e => { if(!window.getSelection()?.toString() && !e.target.closest('a,input,button,select,textarea')) activate(+el.dataset.editBlock); };
        el.onkeydown = e => { if(e.target===el && e.key==='Enter') {e.preventDefault();activate(+el.dataset.editBlock);} };
      });
      const empty = document.createElement('section');
      empty.className = 'empty-block'; empty.tabIndex = 0;
      empty.setAttribute('aria-label', 'New paragraph');
      const begin = () => {
        if(active) {commit();return;}
        const gap=source.length && !source.endsWith('\n\n') ? (source.endsWith('\n')?'\n':'\n\n') : '';
        source += gap; const index=blocks.length; blocks.push({start:source.length,end:source.length});
        empty.dataset.editBlock=index;empty.onclick=null;activate(index);
      };
      empty.onclick = begin;
      empty.onkeydown = e => {if(e.target===empty && e.key==='Enter'){e.preventDefault();begin();}};
      document.querySelector('main').append(empty);
      document.querySelector('main').dataset.editorReady='true';
    }, commit, activate,
    format(action) {
      if(!active || composing) return;
      const wrappers={bold:['**','**'],italic:['*','*'],underline:['<u>','</u>'],strike:['~~','~~'],inlineCode:['`','`']};
      if(wrappers[action]) {wrapSelection(...wrappers[action]);return;}
      if(action==='bullet') prefixBlock('- ');
      if(action==='numbered') prefixBlock('1. ');
      if(action==='task') prefixBlock('- [ ] ');
      if(action==='quote') prefixBlock('> ');
      if(action==='divider') insert('---\n\n'+active.area.value);
      if(action==='link') {
        const a=active.area,start=a.selectionStart,end=a.selectionEnd;
        insert(a.value.slice(0,start)+'['+a.value.slice(start,end)+'](https://)'+a.value.slice(end),end+3);
        a.setSelectionRange(end+3,end+11);
      }
    },
    applyCurrentHeading(level) {
      const selected = window.getSelection()?.anchorNode;
      const element = selected?.nodeType === Node.ELEMENT_NODE ? selected : selected?.parentElement;
      const block = element?.closest('[data-edit-block]') || document.activeElement?.closest('[data-edit-block]');
      const index = active?.index ?? (block ? +block.dataset.editBlock : null);
      if (index !== null) this.applyHeading(level, index);
    },
    insertCode() {
      if(composing) return;
      if(!active) {
        const selected = window.getSelection()?.anchorNode;
        const element = selected?.nodeType === Node.ELEMENT_NODE ? selected : selected?.parentElement;
        const block = element?.closest('[data-edit-block]') || document.activeElement?.closest('[data-edit-block]');
        if(block) activate(+block.dataset.editBlock);
      }
      if(active) code('');
    },
    applyHeading(level, index) {
      if (composing) return;
      if (!active) activate(index);
      if (active && !/^\s*(```|~~~)/.test(active.area.value)) heading(level);
    },
    getSource: () => source,
    flush: () => {if(active && !composing) write(active.area.value);return source;}
  };
  document.addEventListener('mousedown', e => {if(e.button !== 0 || e.ctrlKey) return; if(active && !e.target.closest('.editing')) {const block=e.target.closest('[data-edit-block]');commit(block ? +block.dataset.editBlock : null);}});
  document.addEventListener('contextmenu', e => {
    if (composing) return;
    const block=e.target.closest('[data-edit-block]');
    const selected = active && e.target === active.area
      ? active.area.value.slice(active.area.selectionStart, active.area.selectionEnd)
      : window.getSelection()?.toString();
    if (!block || !selected) return;
    e.preventDefault();
    window.webkit?.messageHandlers.selectionMenu.postMessage({x:e.clientX,y:e.clientY,index:+block.dataset.editBlock});
  });
  document.addEventListener('keydown', e => {
    if (!e.isComposing && !composing && e.metaKey && e.altKey && !e.shiftKey && !e.ctrlKey) {
      if (/^[0-3]$/.test(e.key)) {e.preventDefault();window.typeXInline.applyCurrentHeading(+e.key);return;}
      if (e.key.toLowerCase()==='c') {e.preventDefault();window.typeXInline.insertCode();return;}
      const block={t:'task',s:'divider'}[e.key.toLowerCase()];if(block){e.preventDefault();window.typeXInline.format(block);return;}
    }
    if (!e.isComposing && !composing && e.metaKey && !e.altKey) {
      let action = e.ctrlKey && e.key.toLowerCase()==='c' ? 'inlineCode' : null;
      if(!e.ctrlKey) action = e.shiftKey ? ({x:'strike','8':'bullet','*':'bullet','7':'numbered','&':'numbered','>':'quote'}[e.key.toLowerCase()]) : ({b:'bold',i:'italic',u:'underline',k:'link'}[e.key.toLowerCase()]);
      if(action){e.preventDefault();window.typeXInline.format(action);return;}
    }
    if (!e.isComposing && !composing && (e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'z') {
      e.preventDefault(); window.webkit?.messageHandlers.historyMarkdown.postMessage({redo:e.shiftKey});
    }
  });
})();
