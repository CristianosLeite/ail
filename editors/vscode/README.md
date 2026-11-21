# AIL for VS Code

Support for AIL sources (`.aw`): syntax highlighting, folding of the
blocks (`fn`, `while`, `if` in every form, `else`) and Format Document,
which runs `build/tools/indent` and so gives the indentation that
`docs/language.md` describes under "Source style". A tab is shown two
columns wide.

The extension is plain JavaScript and has nothing to build or install
besides itself. From the top of the repository:

```
make tools                                            # builds build/tools/indent
ln -s "$PWD/editors/vscode" ~/.vscode/extensions/ail.ail-0.1.0
```

Restart VS Code after that. To try it without installing:

```
code --extensionDevelopmentPath="$PWD/editors/vscode" .
```

Format Document looks for the formatter at `build/tools/indent` in the
workspace folder of the file; the setting `ail.indentPath` names another
place. Folding and highlighting need no tool.

The rules of a line (which word opens a block, when a line is inside a
string) are those of `tools/lib/dent.aw`, written again in `extension.js`
for the folding; a new block statement of the language is added in both,
in the grammar and in `language-configuration.json`.
