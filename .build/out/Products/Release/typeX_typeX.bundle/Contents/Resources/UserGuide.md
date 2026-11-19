# ApexText User Guide

**ApexText** is a local Markdown editor for macOS. **Author: ApexVoid.**

This guide is included with the application and works offline. Use Search topics to find a section, then click its title. External reference links open your browser.

## Getting started

1. Launch ApexText. Documents open in Preview with the sidebar visible.
2. Use the top-left menu to choose Open File or Open Folder.
3. Click a paragraph to edit it in place, or click the three-line button at the top right to edit the entire Markdown source.
4. Press Command-S to save. For a new document, choose a filename ending in .md and a destination.

The app uses English controls. The status bar shows the character count and source line count, not a word count. Light and dark appearance follow macOS.

## Open files and folders

The top-left menu contains Outline, Folder, Open File, Open Folder, Hide Sidebar / Show Sidebar, and Quit ApexText.

- **Open File** opens a UTF-8 text or Markdown document in the current document window. The menu label is File. Selecting Folder shows that file's parent directory.
- **Open Folder** selects a local folder to browse. The menu label becomes Open Folder. It does not replace the current document until you click a file.
- Click a folder row to expand or collapse it. Click a Markdown or text file to open it in the current window. A folder opened explicitly remains the browsing root when you open its files.
- The browser lists folders and .md, .markdown, .mdown and .txt files. Hidden items and symbolic links are omitted.
- New documents are available from the macOS File menu. The same-window behavior applies to Open File in the left menu and file clicks in the sidebar; macOS File-menu and Finder opening may create a document window.

If a file cannot be read, ApexText shows an error. Non-UTF-8 files must be converted to UTF-8 before opening.

## Save, close and quit

Use **File → Save** or **Command-S** to save explicitly. New files require a destination. The document uses macOS document saving; do not rely on a preview refresh as proof that a file was saved.

Before replacing a document, ApexText asks the native document system to resolve unsaved changes. Follow any Save, Discard or Cancel prompt. Cancel keeps the current document. Native autosave behavior may resolve changes without presenting that prompt.

Close a document with Command-W. Quit using **Quit ApexText** in the left menu or **ApexText → Quit ApexText** in the macOS menu bar. Quit uses the native termination flow. The app does not upload your documents to a cloud service.

## Outline and sidebar

Choose **Outline** for the current document's headings. Click a heading to jump to its location in Preview or source editing. Headings inside code blocks do not appear in the outline.

Choose **Folder** to browse the current file's directory or the folder you opened explicitly. Drag the divider to resize the sidebar.

Choose **Hide Sidebar** to give the document more room. The top-left menu remains accessible; choose **Show Sidebar**, Outline or Folder to show it again. **Command-Backslash** toggles visibility. Sidebar controls do not change the window size or enter macOS full-screen mode.

## Preview and source editing

The top-right button stays in one position:

- In Preview, the three-line icon switches to source editing.
- In source editing, the eye icon returns to Preview.
- **Command-Shift-P** switches modes.

ApexText maps the visible content to source lines when switching. Position is approximate where rendered blocks and source lines have different heights. It does not intentionally jump back to the last outline selection.

## Edit directly in Preview

Click a rendered paragraph, heading, list or code block to edit that block. Only the active block exposes Markdown text; other blocks keep their rendered appearance. This is focused block editing, not a full rich-text canvas.

Changes update the document while you type. Click outside the block or press **Command-Enter** to return it to rendered appearance. **Escape also finishes editing; it does not discard changes.** Use Undo to reverse changes.

Click the blank area at the end of the document to start a new paragraph. There is no Add block button or always-visible formatting toolbar.

Select text without clicking again if you want the selection menu. Right-click, Control-click, or use the secondary-click gesture configured in macOS Trackpad settings, usually a two-finger click. The menu offers Paragraph, Heading 1–6 and Font.

## Headings

Type # followed by a space for Heading 1, ## and a space for Heading 2, through six # characters for Heading 6. In Preview's block editor, the Markdown is rendered when you finish editing the block.

```markdown
# Heading 1
## Heading 2
### Heading 3
```

Use **Command-Option-1**, **2** or **3** for Heading 1, 2 or 3. **Command-Option-0** restores body text. Heading 4–6 are available from the selection context menu. These are Lark-style shortcuts; Command-F1 is not assigned.

You can also write a Setext heading: a text line followed by a line of equals signs (Heading 1) or hyphens (Heading 2). Standard Markdown supports six heading levels; Lark's levels 7–9 are not implemented.

## Code blocks and languages

At the beginning of a line, type three backticks, optionally followed immediately by a language identifier, then press **Space or Enter**. ApexText inserts the closing fence and places the caret inside.

Examples of opening lines: three backticks followed by bash, python, javascript, typescript, swift, java, json, yaml, sql, c++, c#, objective-c or dockerfile. Other identifiers are preserved too. Without a language, the block is plain text.

The saved result is normal fenced Markdown:

````markdown
```python
print("Hello")
```
````

**Command-Option-C** creates a code block. In source mode it wraps the selected text. In Preview's block editor it converts the active block. To change the language, edit the identifier on the opening fence. Paste code into the body. Tab inserts two spaces; Shift-Tab removes leading indentation.

The language label appears in rendered code blocks. Syntax coloring and automatic language inference from pasted code are not implemented. Long rendered code lines scroll horizontally.

## Lists, tasks, quotes and indentation

- Start a bullet with - and a space, or * and a space.
- Start a numbered list with 1. and a space.
- Type [] then Space for a task. ApexText writes the portable Markdown form - [ ].
- Start a quote with > and a space.
- Enter continues a list or quote. Numbered lists increment; a new task is unchecked. Enter on an empty item exits it.
- Tab adds indentation; Shift-Tab removes it. These transforms are not applied to list-like text inside a fenced code block.

For a completed task, edit [ ] to [x]. Rendered task checkboxes currently display state and are not clickable.

Shortcuts: **Command-Shift-8** for bullets, **Command-Shift-7** for numbering, **Command-Option-T** for tasks, and **Command-Shift->** for quotes. Block-level commands apply to the active block in Preview and affected source lines in source editing.

## Slash commands

While editing a Preview block, type / at the start or after whitespace. Type a filter such as /code, then press Enter to choose the first matching item, or click the item.

Available commands are Heading 1, Heading 2, Heading 3, Code Block, Bullet List, Numbered List, Task List, Quote, Table and Divider. Converting an existing paragraph to a heading or code block preserves its text. The menu is shown only while entering a slash command; it is not a permanent block toolbar.

Slash-command suggestions are a Preview editing feature. In source editing, type the corresponding Markdown or use a keyboard shortcut.

## Text formatting and links

Select text in the active block or source editor, then use a shortcut:

| Format | Shortcut | Saved Markdown |
| --- | --- | --- |
| Bold | Command-B | **text** delimiters |
| Italic | Command-I | *text* delimiters |
| Underline | Command-U | inline u tags |
| Strikethrough | Command-Shift-X | double tilde delimiters |
| Inline code | Control-Command-C | backtick delimiters |
| Link | Command-K | bracketed text and URL |

Bold, italic, underline, strikethrough and inline-code shortcuts can remove their matching delimiters when the enclosed text is selected again. For a link, replace the selected https:// placeholder with the destination. HTTP, HTTPS and mailto links in Preview open through macOS.

Underline is saved with safe inline HTML u tags. The Lark input form using single tildes is not converted automatically. Arbitrary HTML is displayed as text rather than executed.

## Tables, dividers and images

Use /table in a Preview block to insert a Markdown table template, then edit its headers and cells in Markdown. Existing pipe tables render in Preview, including horizontal scrolling for wide tables.

Use /divider, **Command-Option-S**, or a standalone line of three hyphens or asterisks for a divider.

Markdown images with HTTPS URLs render when the network is available. Local and relative image paths are not loaded by this version. Opening a document with remote images may request those images from their hosts. There is no image upload service.

## Fonts and appearance

Choose **View → Font…** in the macOS menu bar, or select text and choose Font from its context menu. The native font panel exposes fonts installed on your Mac and lets you choose size and typeface.

Font settings apply to document display across windows and are remembered on this Mac. They do not write a font family or size into the selected Markdown text. Code blocks keep their monospace styling. Use heading levels for portable structural size changes.

## Find, undo and redo

For text search, switch to source editing, click inside the editor, and use **Command-F** or the Find and Replace menu entry. The native find bar provides search controls and its replacement option. Find-and-replace is not implemented for Preview's web editor.

Use **Command-Z** to undo and **Command-Shift-Z** to redo. Preview editing groups changes by the block-edit session; source mode uses native text undo. Undo histories are not unified across modes and are not retained after reopening a document. Save important work explicitly before making large changes.

## Keyboard shortcut reference

Command = ⌘, Option = ⌥, Shift = ⇧, Control = ⌃. Formatting shortcuts require focus in the document editor and are not applied during Chinese or other IME composition.

| Action | macOS shortcut |
| --- | --- |
| Save | Command-S |
| Close document | Command-W |
| Quit | Command-Q |
| Toggle Preview / source | Command-Shift-P |
| Hide / show sidebar | Command-Backslash |
| Find in source | Command-F |
| Finish Preview block | Command-Enter or Escape |
| Undo / redo | Command-Z / Command-Shift-Z |
| Heading 1–3 | Command-Option-1 / 2 / 3 |
| Body text | Command-Option-0 |
| Code block | Command-Option-C |
| Bold / italic / underline | Command-B / I / U |
| Strikethrough | Command-Shift-X |
| Inline code | Control-Command-C |
| Insert link | Command-K |
| Bullet / numbered list | Command-Shift-8 / 7 |
| Quote | Command-Shift-> |
| Task list | Command-Option-T |
| Divider | Command-Option-S |
| Indent / outdent | Tab / Shift-Tab |

## Troubleshooting and current limits

- If typing does not appear, click the paragraph in Preview or switch to source editing.
- If a shortcut does not apply, focus the document and finish any input-method composition first. Headings should be applied to text, not to code content.
- If a file fails to open, check read permissions and UTF-8 encoding. Failed reads leave the current document intact.
- If a directory's contents change outside ApexText, its visible listing may not refresh automatically. Reopen the app if needed.
- Preview is not a pixel-identical copy of the source view. Position mapping can shift within complex tables, code blocks or long wrapped paragraphs.
- Live mathematical typesetting, Mermaid rendering, code syntax coloring, local images, cloud collaboration, comments, mentions, synchronized blocks, text colors/alignment and Lark headings 7–9 are not implemented.
- Large-file performance, conflict resolution for external edits and crash recovery have not been comprehensively validated. There is no dedicated export-to-PDF or export-to-Word feature.

## About and references

**ApexText** — local Markdown editing for macOS. **Author: ApexVoid.**

The application is independently implemented. It is not affiliated with Typora or Lark. Its common quick-editing shortcuts follow Lark's documented macOS conventions where compatible with local Markdown. Existing Markdown tables and Setext headings remain available even when Lark input rules differ.

Parsing uses Swift Markdown and cmark. Third-party license notices are included in the application bundle. This guide describes the current implementation, not a promise of full Lark compatibility.

Official references (internet required):

- [Lark Docs keyboard shortcuts](https://www.larksuite.com/hc/en-US/articles/754973300077-use-keyboard-shortcuts-in-docs)
- [Markdown in Docs](https://www.feishu.cn/hc/en-US/articles/118804574721-use-markdown-in-docs)
- [Code blocks in Docs](https://www.feishu.cn/hc/zh-CN/articles/603012886054-在文档中插入代码块)
