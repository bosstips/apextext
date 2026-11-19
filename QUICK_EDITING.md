# ApexText quick editing

Reference: Lark Docs quick editing. Keep local Markdown files portable; do not claim full Lark feature parity.

## Input

- Type three backticks, optionally followed by a language, then Space or Enter. Works with bash, python, javascript, typescript, swift, java, json, yaml, sql, c++, c#, objective-c, dockerfile, and other language identifiers. An omitted language remains plain text. Language labels are preserved; syntax highlighting and language inference from pasted code are not implemented.
- Type `[]` then Space for a task list; saved as `- [ ] `.
- Enter continues unordered, ordered, task lists and quotes. Enter on an empty item exits it.
- Tab indents; Shift-Tab removes indentation. Code content is not converted into lists.
- Use `# ` through `###### ` for headings. Bold, italic, code and strikethrough use standard Markdown delimiters. The edited block renders when you leave it or press Command-Enter.
- In preview, type `/` at the start or after whitespace, filter commands and press Enter. Existing paragraph text is retained when converting to a code block or heading.
- Click the blank area at the document end to add text. There is no Add block button.

## macOS shortcuts

| Action | Shortcut |
| --- | --- |
| Heading 1–3 | Command-Option-1 / 2 / 3 |
| Body text | Command-Option-0 |
| Code block | Command-Option-C |
| Bold / Italic / Underline | Command-B / I / U |
| Strikethrough | Command-Shift-X |
| Inline code | Control-Command-C |
| Link | Command-K |
| Bulleted / numbered list | Command-Shift-8 / 7 |
| Quote | Command-Shift-> |
| Task list | Command-Option-T |
| Divider | Command-Option-S |

Right-click (or the configured trackpad secondary click) a selection for headings and the document font panel. Arbitrary per-selection font families are not written into Markdown. Underline uses safe inline `<u>` markup.

## Boundaries

This remains a local Markdown editor with focused blocks edited as Markdown, not a full Lark rich-text clone. Standard Markdown has H1–H6; Lark-specific H7–H9, live formula rendering, automatic conversion of `~text~` to underline, colors/alignment, mentions, synchronized blocks, cloud tasks and collaboration are not implemented. Existing Markdown tables and Setext headings remain supported even where Lark input rules differ. Ordinary source editing retains literal Markdown.

## Official references

- https://www.larksuite.com/hc/en-US/articles/754973300077-use-keyboard-shortcuts-in-docs
- https://www.feishu.cn/hc/en-US/articles/118804574721-use-markdown-in-docs
- https://www.feishu.cn/hc/zh-CN/articles/603012886054-在文档中插入代码块
