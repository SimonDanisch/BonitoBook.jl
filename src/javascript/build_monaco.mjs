// Rebuild the pinned vendor with: node build_monaco.mjs /path/to/esbuild
// Normal Bonito development uses the committed vendor and deno bundle as usual.
import {readFileSync, writeFileSync, mkdtempSync, mkdirSync, rmSync, readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const version = readFileSync(join(here, 'Monaco.js'), 'utf8').match(/const MONACO_VERSION = "([^"]+)"/)[1];
const integrity = 'sha512-jz4x+TJNFHwHtwuV9vA9rMujcZRb0CEilTEwG2rRSpe/A7Jdkuj8xPKttCgOh+v/lkHy7HsZ64oj+q3xoAFl9A==';
if (version !== '0.55.1') throw new Error('Update the pinned npm integrity when changing Monaco versions');
const esbuild = process.argv[2] || 'esbuild';
const temp = mkdtempSync(join(tmpdir(), 'bonitobook-monaco-'));
try {
    const response = await fetch(`https://registry.npmjs.org/monaco-editor/-/monaco-editor-${version}.tgz`);
    if (!response.ok) throw new Error(`Monaco download: HTTP ${response.status}`);
    const archive = Buffer.from(await response.arrayBuffer());
    const actual = 'sha512-' + createHash('sha512').update(archive).digest('base64');
    if (actual !== integrity) throw new Error('Monaco archive integrity mismatch');
    const archivePath = join(temp, 'monaco.tgz');
    writeFileSync(archivePath, archive);
    execFileSync('tar', ['-xzf', archivePath, '-C', temp]);
    const editor = join(temp, 'package/esm/vs/editor');
    const all = join(editor, 'editor.all.js');
    const main = readFileSync(join(editor, 'editor.main.js'), 'utf8');
    const features = new Set([...(readFileSync(all, 'utf8') + '\n' + main).matchAll(/^import '([^']+)';$/gm)]
        .filter(m => !m[1].includes('/basic-languages/'))
        .map(m => resolve(editor, m[1])));
    // Some 0.55.1 language definitions also bootstrap the browser editor.
    // Exclude those side effects from the worker's copy of the sources.
    function deferFeatures(dir) {
        for (const entry of readdirSync(dir, {withFileTypes:true})) {
            const path = join(dir, entry.name);
            if (entry.isDirectory()) deferFeatures(path);
            else if (entry.name.endsWith('.js')) {
                const source = readFileSync(path, 'utf8');
                const deferred = source.replace(/^import '([^']+)';$/gm,
                    (line, target) => features.has(resolve(dir, target)) || target.endsWith('.css') ? '' : line)
                    // Definitions use this namespace only for IndentAction;
                    // import the same enum without bootstrapping editor.api.
                    .replace(/^import \{ languages \} from '([^']*)editor\.api2\.js';$/gm,
                        "import * as languages from '$1common/standalone/standaloneEnums.js';");
                if (source !== deferred) writeFileSync(path, deferred);
            }
        }
    }
    const output = join(temp, 'monaco.js');
    execFileSync(esbuild, [join(editor, 'editor.main.js'),
        '--bundle', '--format=esm', '--platform=browser', '--target=es2022',
        '--minify', '--legal-comments=inline', '--loader:.ttf=dataurl',
        '--loader:.svg=dataurl', '--loader:.png=dataurl', `--outfile=${output}`], {stdio:'inherit'});
    const css = readFileSync(join(temp, 'monaco.css'), 'utf8');
    const js = readFileSync(output, 'utf8');
    const vendor = join(here, 'vendor');
    mkdirSync(vendor, {recursive:true});
    // One stylesheet, in esbuild's dependency order. Fonts are data URLs, so
    // Bonito's hashed asset paths need no special CSS/font URL rewriting.
    const prefix = `/*! monaco-editor ${version}, MIT; see monaco-LICENSE.txt and monaco-ThirdPartyNotices.txt. */\n` +
        `const monacoStyle=document.createElement('style');\n` +
        `monacoStyle.textContent=${JSON.stringify(css)};\n` +
        `document.head.appendChild(monacoStyle);\n`;
    writeFileSync(join(vendor, 'monaco.js'), prefix + js);
    for (const dir of ['basic-languages', 'language', 'common'])
        deferFeatures(join(temp, 'package/esm/vs', dir));
    const vs = join(temp, 'package/esm/vs');
    writeFileSync(join(vs, 'basic-languages/_.contribution.js'),
        "export {registerLanguage} from '../bonito-tokenizer-service.js';\n");
    writeFileSync(join(vs, 'bonito-tokenizer-service.js'), readFileSync(join(here, 'CodeTokenizer.worker.js')));
    const definitions = [...main.matchAll(/^import '(\.\.\/basic-languages\/[^']+)';$/gm)]
        .map(m => `import '${m[1].replace('../', './')}';`).join('\n');
    const workerEntry = join(vs, 'bonito-tokenizer.entry.js');
    writeFileSync(workerEntry, `import {start} from './bonito-tokenizer-service.js';\n${definitions}\nstart();\n`);
    const workerOutput = join(temp, 'code_tokenizer.worker.js');
    execFileSync(esbuild, [workerEntry, '--bundle', '--format=esm', '--platform=browser',
        '--target=es2022', '--minify', '--legal-comments=inline',
        `--metafile=${join(temp, 'worker-meta.json')}`, `--outfile=${workerOutput}`], {stdio:'inherit'});
    const inputs = Object.keys(JSON.parse(readFileSync(join(temp, 'worker-meta.json'))).inputs);
    const browserInputs = inputs.filter(path => /\/(base|editor)\/browser\//.test(path));
    if (browserInputs.length) throw new Error(`Tokenizer imports browser code: ${browserInputs.slice(0, 5).join(', ')}`);
    // Embed the self-contained worker to preserve Bonito's hashed asset URLs.
    // Creating it from a Blob requires no special route or external scripts.
    writeFileSync(join(vendor, 'code_tokenizer.js'),
        prefix.split('\n')[0] + '\nexport const workerSource=' + JSON.stringify(readFileSync(workerOutput, 'utf8')) + ';\n');
    for (const name of ['LICENSE', 'ThirdPartyNotices.txt']) {
        writeFileSync(join(vendor, name === 'LICENSE' ? 'monaco-LICENSE.txt' : `monaco-${name}`),
            readFileSync(join(temp, 'package', name)));
    }
    console.log(`Built Monaco ${version}: ${Buffer.byteLength(prefix + js)} bytes`);
} finally {
    rmSync(temp, {recursive:true, force:true});
}
