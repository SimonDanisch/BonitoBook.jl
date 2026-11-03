import test from 'node:test';
import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {workerSource} from '../src/javascript/vendor/code_tokenizer.js';

// The same self-contained worker, with Node's message port adapting Web Worker
// events. No editor, window or DOM is supplied to the tokenizer.
const adapter = `
import {parentPort} from 'node:worker_threads';
const events = new EventTarget();
globalThis.self = globalThis;
globalThis.addEventListener = events.addEventListener.bind(events);
globalThis.removeEventListener = events.removeEventListener.bind(events);
globalThis.postMessage = value => parentPort.postMessage(value);
parentPort.on('message', data => globalThis.onmessage({data}));
await import('./tokenizer.mjs');
`;

test('Monaco tokenizers run in a worker without any browser editor code', {timeout:10000}, async t => {
    const dir = mkdtempSync(join(tmpdir(), 'tokenizer-test-'));
    writeFileSync(join(dir, 'worker.mjs'), adapter);
    writeFileSync(join(dir, 'tokenizer.mjs'), workerSource);
    const worker = new Worker(join(dir, 'worker.mjs'));
    t.after(async () => { await worker.terminate(); rmSync(dir, {recursive:true}); });
    const queued = [], waiting = [];
    worker.on('message', value => waiting.length ? waiting.shift()(value) : queued.push(value));
    const receive = () => queued.length ? Promise.resolve(queued.shift()) : new Promise(resolve => waiting.push(resolve));
    const ready = await receive();
    assert.equal(ready.ready, true);
    assert(ready.languages.some(l => l.id === 'julia' && l.extensions.includes('.jl')));
    assert(ready.css.includes('.bt-code .mtk'));
    let nextId = 0;
    async function tokenize(language, text) {
        const id = ++nextId, rows = [];
        worker.postMessage({type:'start', id, language, text});
        while (true) {
            const message = await receive();
            assert.equal(message.id, id);
            assert.equal(message.error?.split('\n')[0], undefined);
            assert(message.rows.length <= 64);
            rows.push(...message.rows);
            if (message.done) return rows.map(([, html]) => html);
            worker.postMessage({type:'next', id});
        }
    }
    for (const [language, text] of [
        ['julia', '# comment\nx = "hello"'],
        ['javascript', '/* comment */\nconst x = "hello";'],
        ['python', '# comment\nx = "hello"'],
        ['json', '{"name": "hello", "count": 42}'],
        ['shell', '# comment\necho "hello"'],
    ]) {
        const rows = await tokenize(language, text);
        assert.equal(rows.length, text.split('\n').length);
        assert(new Set(rows.join('').match(/class="[^"]+"/g)).size > 1, language);
    }
    const script = (await tokenize('javascript', 'const value = 42;'))[0];
    const html = await tokenize('html', '<script>\nconst value = 42;\n</script>\n<style>.x { color:red; }</style>');
    assert.equal(html[1], script, 'HTML embeds the real JavaScript tokenizer');
    const comment = '#=\n' + 'inside comment\n'.repeat(150) + '=#\nx = "done"';
    const rows = await tokenize('julia', comment);
    assert.equal(rows[1], rows[149], 'multiline state survives batch boundaries');
    assert(rows.at(-1).includes('done'));
    const special = (await tokenize('julia', '\tx = "< & 😀>"'))[0];
    assert(special.includes('&lt;') && special.includes('&amp;') && special.includes('😀'));
    assert(!special.includes('< &'));
    assert(special.includes('&nbsp;&nbsp;&nbsp;&nbsp;'));
    for (const language of ready.languages) {
        if (language.id === 'plaintext') continue;
        assert.equal((await tokenize(language.id, 'value = 42')).length, 1, language.id);
    }
    // A cancelled unfinished stream must release its state and stay silent.
    const cancelled = ++nextId;
    worker.postMessage({type:'start', id:cancelled, language:'julia', text:'x = 42\n'.repeat(1000)});
    assert.equal((await receive()).done, false);
    worker.postMessage({type:'cancel', id:cancelled});
    worker.postMessage({type:'next', id:cancelled});
    await tokenize('julia', 'after_cancel = 42');
});
